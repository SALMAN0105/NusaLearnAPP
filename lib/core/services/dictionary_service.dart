import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class DictionaryService {
  static final DictionaryService instance = DictionaryService._internal();
  factory DictionaryService() => instance;
  DictionaryService._internal();

  final Dio _dio = ApiClient.getDefensiveClient();
  bool isLoaded = false;
  String _activeLang = 'id';

  // ✅ HOT CACHE: Terbatas hanya untuk translate() sync (UI layer)
  // Diisi saat loadDictionary() selesai — O(1) lookup, batas 2000 entri
  // sesuai constraint RAM low-end blueprint Nusa-Edge 0.5B
  static const int _kMaxCacheEntries = 2000;
  final Map<String, String> _syncCache = {};

  // ─────────────────────────────────────────
  // DOWNLOAD
  // ─────────────────────────────────────────
  // ─────────────────────────────────────────
  // DOWNLOAD (PATCHED: ROBUST URL & ERROR HANDLING)
  // ─────────────────────────────────────────
  Future<bool> downloadDictionary(String kodeBahasa) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/dictionary_$kodeBahasa.json';
      final file = File(savePath);

      // 1. Validasi jika file sudah ada
      if (await file.exists()) {
        bool isValid = await loadDictionary(kodeBahasa);
        if (isValid) return true;

        debugPrint("⚠️ File kamus korup terdeteksi. Menghapus cache lama...");
        await file.delete();
      }

      // 2. Konstruksi URL yang lebih robust (Sesuai pola SyncService)
      final baseUrl = ApiClient.baseUrl.contains('/api')
          ? ApiClient.baseUrl.substring(0, ApiClient.baseUrl.indexOf('/api'))
          : ApiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
      
      final fullUrl = '$baseUrl/storage/dictionaries/kamus_$kodeBahasa.json';

      debugPrint("📥 Memulai unduhan kamus dari: $fullUrl");

      // 3. Eksekusi Unduhan
      await _dio.download(fullUrl, savePath);

      // 4. Validasi Pasca-Unduh
      if (await file.exists()) {
        bool loaded = await loadDictionary(kodeBahasa);
        if (!loaded) {
          debugPrint("❌ File berhasil diunduh namun gagal di-parse. Menghapus...");
          await file.delete();
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Gagal mengunduh kamus ($kodeBahasa): $e");
      return false;
    }
  }

  Future<bool> isDictionaryDownloaded(String kodeBahasa) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$kodeBahasa.json');
      return await file.exists() && await file.length() > 0;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // LOAD: Support Map & List + Atomic DB Update
  // ─────────────────────────────────────────
  Future<bool> loadDictionary(String kodeBahasa) async {
    if (kodeBahasa == 'id') {
      _activeLang = 'id';
      _syncCache.clear();
      isLoaded = true;
      return true;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$kodeBahasa.json');

      if (!await file.exists()) {
        isLoaded = false;
        return false;
      }

      final content = await file.readAsString();
      if (content.isEmpty) return false;

      final dynamic jsonData = jsonDecode(content);
      final db = await DatabaseHelper.instance.database;

      // ✅ 1. Atomic DB Update
      await db.transaction((txn) async {
        await txn.delete(
          'dictionary',
          where: 'kode_bahasa = ?',
          whereArgs: [kodeBahasa],
        );

        final batch = txn.batch();
        int count = 0;
        _syncCache.clear();

        void addEntry(dynamic k, dynamic v) {
          if (k == null || v == null) return;
          final s1 = k.toString().toLowerCase().trim();
          final s2 = v.toString().toLowerCase().trim();
          if (s1.isEmpty || s2.isEmpty) return;

          // INTELLIGENT HEURISTIC: Tentukan mana yang Indonesia
          final commonIndo = {'home', 'materi', 'profil', 'kuis', 'beranda', 'belajar', 'numerasi', 'literasi', 'hapus', 'batal'};
          
          String indo, local;
          if (commonIndo.contains(s1)) {
            indo = s1; local = s2;
          } else if (commonIndo.contains(s2)) {
            indo = s2; local = s1;
          } else {
            // Default: local=key, indo=value. Tapi isi cache bi-directional agar aman
            local = s1; indo = s2;
          }

          batch.insert('dictionary', {
            'word_indo': indo,
            'word_tolaki': local,
            'kode_bahasa': kodeBahasa,
          });

          // Isi cache (Keduanya dimasukkan untuk menjamin lookup translateSync berhasil)
          if (_syncCache.length < _kMaxCacheEntries) {
            _syncCache[indo] = local;
            if (_syncCache.length < _kMaxCacheEntries) {
              _syncCache[local] = indo; 
            }
          }
          count++;
        }

        if (jsonData is Map<String, dynamic>) {
          jsonData.forEach((k, v) => addEntry(k, v));
        } else if (jsonData is List) {
          for (var item in jsonData) {
            if (item is Map) {
              final k = item['word_tolaki'] ?? item['local'] ?? item.keys.first;
              final v = item['word_indo'] ?? item['indo'] ?? item.values.last;
              addEntry(k, v);
            }
          }
        }

        if (count > 0) {
          await batch.commit(noResult: true);
        }
      });

      _activeLang = kodeBahasa;
      isLoaded = true;
      debugPrint("✅ Kamus $kodeBahasa dimuat: ${_syncCache.length} entri di cache (Bi-directional).");
      return true;
    } catch (e) {
      debugPrint("❌ Gagal memuat kamus: $e");
      isLoaded = false;
      return false;
    }
  }

  // ─────────────────────────────────────────
  // ASYNC TRANSLATE (untuk AI pipeline — akurat, full DB)
  // ─────────────────────────────────────────
  Future<String> translateToIndo(String text) async {
    if (!isLoaded || _activeLang == 'id') return text;

    final db = await DatabaseHelper.instance.database;
    List<String> words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return text;

    Set<String> uniqueWords = words
        .map((w) => w.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase())
        .where((w) => w.isNotEmpty)
        .toSet();
    if (uniqueWords.isEmpty) return text;

    final placeholders = List.filled(uniqueWords.length, '?').join(',');
    final queryArgs = [...uniqueWords.toList(), _activeLang];

    final maps = await db.rawQuery(
      'SELECT word_tolaki, word_indo FROM dictionary '
      'WHERE (word_tolaki IN ($placeholders) OR word_indo IN ($placeholders)) AND kode_bahasa = ?',
      [...queryArgs, _activeLang],
    );

    final translationMap = <String, String>{};
    for (var row in maps) {
      translationMap[row['word_tolaki'].toString().toLowerCase()] = row['word_indo'].toString();
    }

    return words.map((word) {
      final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
      return translationMap[clean] ?? word;
    }).join(' ');
  }

  Future<String> translateToLocal(String text) async {
    if (!isLoaded || _activeLang == 'id') return text;

    final db = await DatabaseHelper.instance.database;
    List<String> words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return text;

    Set<String> uniqueWords = words
        .map((w) => w.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase())
        .where((w) => w.isNotEmpty)
        .toSet();
    if (uniqueWords.isEmpty) return text;

    final placeholders = List.filled(uniqueWords.length, '?').join(',');
    final queryArgs = [...uniqueWords.toList(), _activeLang];

    final maps = await db.rawQuery(
      'SELECT word_indo, word_tolaki FROM dictionary '
      'WHERE (word_indo IN ($placeholders) OR word_tolaki IN ($placeholders)) AND kode_bahasa = ?',
      [...queryArgs, _activeLang],
    );

    final translationMap = <String, String>{};
    for (var row in maps) {
      translationMap[row['word_indo'].toString().toLowerCase()] = row['word_tolaki'].toString();
    }

    return words.map((word) {
      final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
      return translationMap[clean] ?? word;
    }).join(' ');
  }

  // ✅ SYNC translate — untuk UI layer (PATCHED: PRESERVE PUNCTUATION & CASE)
  String translateSync(String text) {
    if (!isLoaded || _activeLang == 'id' || _syncCache.isEmpty) return text;

    try {
      final regex = RegExp(r"(\w+)|([^\w]+)");
      final matches = regex.allMatches(text);
      
      if (matches.isEmpty) return text;

      final result = StringBuffer();
      for (final match in matches) {
        final part = match.group(0)!;
        
        if (RegExp(r"^\w+$").hasMatch(part)) {
          final clean = part.toLowerCase();
          final translated = _syncCache[clean];
          
          if (translated != null) {
            // Preservasi Capitalization sederhana
            if (part.length > 0 && part[0] == part[0].toUpperCase()) {
              if (translated.length > 1) {
                result.write(translated[0].toUpperCase() + translated.substring(1));
              } else {
                result.write(translated.toUpperCase());
              }
            } else {
              result.write(translated);
            }
          } else {
            result.write(part);
          }
        } else {
          result.write(part);
        }
      }

      return result.toString();
    } catch (e) {
      return text;
    }
  }

  // Alias async (tetap ada untuk kompatibilitas AI pipeline)
  Future<String> translate(String text) async => await translateToLocal(text);
}
