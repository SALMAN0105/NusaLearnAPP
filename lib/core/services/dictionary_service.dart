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
  // DOWNLOAD (PATCHED: MEMORY-SAFE & ANTI-CORRUPTION)
  // ─────────────────────────────────────────
  Future<bool> downloadDictionary(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/dictionary_$languageCode.json';
      final file = File(savePath);

      // 1. DEFENSIVE CHECK: Validasi integritas jika file sudah ada
      if (await file.exists()) {
        bool isValid = await loadDictionary(languageCode);
        if (isValid) return true;

        // Jika file berisi HTML 404 / korup, musnahkan dari disk
        debugPrint("⚠️ File kamus korup terdeteksi. Menghapus cache lama...");
        await file.delete();
      }

      String serverPath = 'dictionaries/kamus_$languageCode.json';
      final baseUrl = ApiClient.baseUrl.replaceAll('api/', 'storage');
      final fullUrl = '$baseUrl/$serverPath';

      debugPrint("📥 Memulai unduhan kamus dari: $fullUrl");

      // 2. EKSEKUSI UNDUHAN
      await _dio.download(fullUrl, savePath);

      // 3. VALIDASI PASCA-UNDUH
      if (await file.exists()) {
        bool isLoaded = await loadDictionary(languageCode);
        if (!isLoaded) {
          debugPrint(
            "❌ File berhasil diunduh namun gagal di-parse. Menghapus artefak...",
          );
          await file.delete(); // Pembersihan memori
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint(
        "❌ Terjadi kegagalan I/O atau Jaringan saat mengunduh kamus: $e",
      );

      // Bersihkan artefak jika Dio terlanjur membuat file kosong/HTML
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$languageCode.json');
      if (await file.exists()) await file.delete();

      return false;
    }
  }

  Future<bool> isDictionaryDownloaded(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return await File('${dir.path}/dictionary_$languageCode.json').exists();
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // LOAD: Migrasi JSON → SQLite + isi hot cache
  // ─────────────────────────────────────────
  Future<bool> loadDictionary(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$languageCode.json');

      if (!await file.exists()) {
        isLoaded = false;
        return false;
      }

      final db = await DatabaseHelper.instance.database;

      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM dictionary WHERE language_code = ?',
        [languageCode],
      );
      int count = countResult.first['cnt'] as int? ?? 0;

      String content = await file.readAsString();
      dynamic jsonData = jsonDecode(content);

      if (count == 0 && jsonData is Map<String, dynamic>) {
        await db.transaction((txn) async {
          final batch = txn.batch();
          jsonData.forEach((localWord, indoWord) {
            batch.insert('dictionary', {
              'word_indo': indoWord.toString().toLowerCase().trim(),
              'word_tolaki': localWord.toString().toLowerCase().trim(),
              'language_code': languageCode,
            });
          });
          await batch.commit(noResult: true);
        });
      }

      // ✅ Isi hot cache (word_indo → word_tolaki) — max 2000 entri
      // Ambil entri paling umum saja agar RAM aman di low-end device
      _syncCache.clear();
      if (jsonData is Map<String, dynamic>) {
        int loaded = 0;
        for (final entry in jsonData.entries) {
          if (loaded >= _kMaxCacheEntries) break;
          final local = entry.key.toString().toLowerCase().trim();
          final indo = entry.value.toString().toLowerCase().trim();
          if (indo.isNotEmpty && local.isNotEmpty) {
            _syncCache[indo] = local; // indo → local (untuk translateToLocal)
          }
          loaded++;
        }
      }

      _activeLang = languageCode;
      isLoaded = true;
      return true;
    } catch (e) {
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
      'WHERE word_tolaki IN ($placeholders) AND language_code = ?',
      queryArgs,
    );

    final translationMap = <String, String>{
      for (var row in maps)
        row['word_tolaki'].toString(): row['word_indo'].toString(),
    };

    return words
        .map((word) {
          final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
          return translationMap[clean] ?? word;
        })
        .join(' ');
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
      'WHERE word_indo IN ($placeholders) AND language_code = ?',
      queryArgs,
    );

    final translationMap = <String, String>{
      for (var row in maps)
        row['word_indo'].toString(): row['word_tolaki'].toString(),
    };

    return words
        .map((word) {
          final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
          return translationMap[clean] ?? word;
        })
        .join(' ');
  }

  // ✅ SYNC translate — untuk UI layer (widget build, non-async context)
  // Menggunakan hot cache O(1). Tidak memanggil DB sama sekali.
  // Aman dipanggil dari build() dan method sync manapun.
  String translateSync(String text) {
    if (!isLoaded || _activeLang == 'id' || _syncCache.isEmpty) return text;

    final words = text.split(RegExp(r'\s+'));
    return words
        .map((word) {
          final clean = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
          return _syncCache[clean] ?? word;
        })
        .join(' ');
  }

  // Alias async (tetap ada untuk kompatibilitas AI pipeline)
  Future<String> translate(String text) async => await translateToLocal(text);
}
