import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/sync_service.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:sqflite/sqflite.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? detectedDistrict;
  String? detectedLanguage;
  String? get getDetectedDistrict => detectedDistrict;
  String? get getDetectedLanguage => detectedLanguage;

  String _activeLanguage = 'id';
  String? userLocalLanguage;

  String get activeLanguage => _activeLanguage;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  List<String> _schoolList = [];
  List<String> get schoolList => _schoolList;

  Future<void> fetchSchools() async {
    try {
      final response = await ApiClient.getClient().get('schools');
      if (response.data['status'] == 'success') {
        _schoolList = List<String>.from(response.data['data']);
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching schools: $e");
      _schoolList = [];
      notifyListeners();
    }
  }

  Future<bool> switchLanguage(bool useLocal) async {
    final prefs = await SharedPreferences.getInstance();

    if (useLocal) {
      // Jika userLocalLanguage null, baca ulang dari database
      if (userLocalLanguage == null || userLocalLanguage == 'id') {
        final db = await DatabaseHelper.instance.database;
        final userList = await db.query('pengguna', limit: 1);
        if (userList.isNotEmpty) {
          userLocalLanguage = userList.first['kode_bahasa'] as String?;
          print(
            '🔄 LANG: userLocalLanguage di-refresh dari DB: $userLocalLanguage',
          );
        }
      }

      if (userLocalLanguage != null && userLocalLanguage != 'id') {
        String targetLang = userLocalLanguage!;

        bool exists = await DictionaryService().isDictionaryDownloaded(
          targetLang,
        );

        if (!exists) {
          print("🌐 LANG: Kamus belum ada, download dulu...");
          try {
            bool downloaded = await DictionaryService().downloadDictionary(
              targetLang,
            );
            if (!downloaded) {
              print("❌ LANG: Gagal download kamus");
              return false;
            }
          } catch (e) {
            print("❌ LANG: Error download - $e");
            return false;
          }
        }

        bool loaded = await DictionaryService().loadDictionary(targetLang);
        if (loaded) {
          _activeLanguage = targetLang;
          // ✅ FIX: Gunakan commit() untuk memastikan data tersimpan
          // sebelum lanjut, terutama penting di mode release
          await prefs.setString('pref_language', _activeLanguage);
          await prefs.commit(); // ← TAMBAHAN: paksa flush ke disk
          print("✅ LANG: Bahasa aktif: $_activeLanguage");
          notifyListeners();
          return true;
        } else {
          print("❌ LANG: Gagal load kamus");
          return false;
        }
      } else {
        print("⚠️ LANG: User tidak memiliki kode_bahasa daerah yang valid");
        return false;
      }
    } else {
      // Ganti ke Bahasa Indonesia
      _activeLanguage = 'id';
      await DictionaryService().loadDictionary('id'); // ✅ RESET DICTIONARY
      await prefs.setString('pref_language', _activeLanguage);
      await prefs.commit(); 
      print("✅ LANG: Bahasa aktif: $_activeLanguage");
      notifyListeners();
      return true;
    }
  }

  Future<void> initUserLanguage() async {
    // ✅ FIX: Gunakan getInstance yang fresh agar tidak ada cache stale
    final prefs = await SharedPreferences.getInstance();

    // ✅ FIX: Reload prefs untuk mendapatkan nilai terbaru dari disk
    await prefs.reload();

    final db = await DatabaseHelper.instance.database;
    final userList = await db.query('pengguna', limit: 1);
    final user = userList.isNotEmpty ? userList.first : null;

    if (user != null) {
      userLocalLanguage = user['kode_bahasa'] as String?;
      print(
        '🔄 LANG: initUserLanguage → userLocalLanguage = $userLocalLanguage',
      );
    }

    String? savedPref = prefs.getString('pref_language');

    // ✅ FIX: Jika savedPref adalah bahasa daerah tapi userLocalLanguage adalah 'id'
    // atau null, validasi ulang. Ini mencegah state yang tidak konsisten.
    if (savedPref != null && savedPref != 'id') {
      // Validasi: pastikan user memang punya bahasa daerah ini
      if (userLocalLanguage == null || userLocalLanguage == 'id') {
        // Bahasa daerah di prefs tidak valid untuk user ini → reset ke 'id'
        print(
          '⚠️ LANG: savedPref "$savedPref" tidak valid untuk user ini, reset ke id',
        );
        savedPref = 'id';
        await prefs.setString('pref_language', 'id');
      }
    }

    _activeLanguage = savedPref ?? 'id';
    print(
      '🔄 LANG: initUserLanguage → _activeLanguage dari prefs = $_activeLanguage',
    );

    if (_activeLanguage != 'id') {
      // ✅ FIX: Pastikan kamus benar-benar berhasil di-load
      // Jika gagal, fallback ke 'id' agar tidak terjebak di state kosong
      bool loaded = await DictionaryService().loadDictionary(_activeLanguage);
      if (!loaded) {
        print('⚠️ LANG: Gagal load kamus $_activeLanguage, fallback ke id');
        _activeLanguage = 'id';
        await prefs.setString('pref_language', 'id');
      }
    } else {
      // ✅ TETAP LOAD 'id' agar state DictionaryService konsisten (isLoaded=true, cache clear)
      await DictionaryService().loadDictionary('id');
    }

    notifyListeners();
  }

  // ✅ PERUBAHAN 1: Kirim 'kode_pos' dengan underscore
  Future<bool> checkRegion(String kodePos) async {
    setLoading(true);
    try {
      final response = await ApiClient.getClient().post(
        'check-region',
        data: {'kode_pos': kodePos}, // ✅ UBAH: Tambah underscore
      );

      if (response.data['status'] == 'success') {
        detectedDistrict = response.data['data']['district'];
        detectedLanguage = response
            .data['data']['language_code']; // 🔥 UBAH: Sesuaikan dengan backend
        notifyListeners();
        return true;
      }
    } catch (e) {
      detectedDistrict = null;
      detectedLanguage = null;
      print("Error Check Region: $e");
    } finally {
      setLoading(false);
    }
    return false;
  }

  final StreamController<Map<String, dynamic>> loginProgressController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get loginProgressStream =>
      loginProgressController.stream;

  void _emitProgress(String step, String status, double progress) {
    loginProgressController.add({
      'step': step,
      'status': status, // 'loading' | 'success' | 'error'
      'progress': progress,
    });
  }

  @override
  void dispose() {
    loginProgressController.close();
    super.dispose();
  }

  Future<bool> login(String nama_pengguna, String kata_sandi) async {
    setLoading(true);

    try {
      final response = await ApiClient.getClient().post(
        'login',
        data: {'nama_pengguna': nama_pengguna, 'kata_sandi': kata_sandi},
      );

      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        final user = data['user'];
        final token = data['access_token'];
        final penggunaId = user['id'] ?? 0;

        if (token == null || token.isEmpty) {
          print('❌ TOKEN NULL atau KOSONG!');
          return false;
        }

        // ✅ FIX 1: SIMPAN TOKEN DULU KE SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'auth_token',
          token,
        ); // ✅ Key yang benar: 'auth_token'
        await prefs.setString('nama_pengguna', nama_pengguna);
        await prefs.setInt('userid', penggunaId);
        await prefs.setBool('is_logged_in', true);

        // ✅ Verifikasi token tersimpan
        String? savedToken = prefs.getString('auth_token');
        print('✅ Token tersimpan: ${savedToken != null}');

        if (user['url_gambar'] != null) {
          await prefs.setString('userimageurl', user['url_gambar']);
        }

        // ✅ FIX 2: Simpan user ke database lokal
        final db = await DatabaseHelper.instance.database;
        await db.delete('pengguna'); // Hapus user lama
        await db.insert('pengguna', {
          'id': penggunaId,
          'nama': user['nama'],
          'nama_pengguna': user['nama_pengguna'],
          'token': token,
          'kelas': user['kelas'],
          'asal_sekolah': user['asal_sekolah'],
          'kode_bahasa': user['kode_bahasa'],
          'kode_pos': user['kode_pos'],
          'last_sync': null,
        });

        String userLang = user['kode_bahasa'] ?? 'id';
        userLocalLanguage = userLang;

        print('📦 SYNC: Memulai download semua resources...');

        List<String> errors = [];
        int totalItems = 0;
        int successItems = 0;

        // 1. Download Kamus
        if (userLang != 'id') {
          totalItems++;
          _emitProgress('Mengunduh kamus $userLang...', 'loading', 0.1);
          try {
            bool success = await DictionaryService.instance.downloadDictionary(
              userLang,
            );
            if (success) {
              successItems++;
              _emitProgress('Kamus $userLang', 'success', 0.33);
            } else {
              errors.add('Kamus download failed');
              _emitProgress('Kamus $userLang', 'error', 0.33);
            }
          } catch (e) {
            errors.add('Kamus: $e');
            _emitProgress('Kamus $userLang', 'error', 0.33);
          }
        }

        // 2. Download Materi
        totalItems++;
        _emitProgress('Mengunduh materi pembelajaran...', 'loading', 0.4);
        try {
          await SyncService().syncMaterials(force: true);
          successItems++;
          _emitProgress('Materi pembelajaran', 'success', 0.66);
        } catch (e) {
          errors.add('Materi: $e');
          _emitProgress('Materi pembelajaran', 'error', 0.66);
        }

        // 3. Download Soal
        totalItems++;
        _emitProgress('Mengunduh soal latihan...', 'loading', 0.65);
        try {
          await SyncService().syncQuestions(force: true);
          successItems++;
          _emitProgress('Soal latihan', 'success', 0.85);
        } catch (e) {
          errors.add('Soal: $e');
          _emitProgress('Soal latihan', 'error', 0.85);
        }

        // 4. Download Progress
        totalItems++;
        _emitProgress('Mengunduh riwayat belajar...', 'loading', 0.90);
        try {
          await SyncService().syncDownProgress();
          successItems++;
          _emitProgress('Riwayat belajar', 'success', 1.0);
        } catch (e) {
          errors.add('Riwayat: $e');
          _emitProgress('Riwayat belajar', 'error', 1.0);
        }

        // ✅ FIX 3: Update last sync timestamp
        await db.update(
          'pengguna',
          {'last_sync': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [penggunaId],
        );

        // Print summary
        print('✅ SYNC: Download selesai! ($successItems/$totalItems items)');
        if (errors.isNotEmpty) {
          print('⚠️ Ada ${errors.length} error:');
          for (var e in errors) {
            print('   - $e');
          }
        }

        // ✅ FIX 4: Initialize user language setelah semua selesai
        await initUserLanguage();
        await DatabaseHelper.instance.printDatabaseStats();

        return true;
      }
    } catch (e) {
      print('❌ Login Error: $e');
    } finally {
      setLoading(false);
    }

    return false;
  }

  // ✅ PERUBAHAN 2: Transform data sebelum dikirim ke backend
  Future<bool> register(Map<String, dynamic> data) async {
    setLoading(true);
    try {
      // ✅ TRANSFORM: Ubah format data sesuai backend expectation
      final requestData = {
        'nama': data['nama'],
        'nama_pengguna': data['nama_pengguna'],
        'kata_sandi': data['kata_sandi'],
        'asal_sekolah': data['asal_sekolah'],
        'kode_pos': data['kode_pos'],
          'kelas': data['kelas'],
      };

      final response = await ApiClient.getClient().post(
        'register',
        data: requestData,
      );

      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        if (detectedDistrict != null) {
          await prefs.setString('userdistrict', detectedDistrict!);
        }
        await prefs.setString('userschool', data['asal_sekolah']);
        return true;
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 422) {
        final errorData = e.response?.data;
        print("Validasi Gagal: ${errorData['message']}");
      } else {
        print("Register Error: ${e.message}");
      }
    } catch (e) {
      print("Register Error: $e");
    } finally {
      setLoading(false);
    }
    return false;
  }
}
