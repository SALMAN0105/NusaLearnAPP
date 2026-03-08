import 'package:flutter/material.dart';
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
        final userList = await db.query('users', limit: 1);
        if (userList.isNotEmpty) {
          userLocalLanguage = userList.first['language_code'] as String?;
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
        print("⚠️ LANG: User tidak memiliki language_code daerah yang valid");
        return false;
      }
    } else {
      // Ganti ke Bahasa Indonesia
      _activeLanguage = 'id';
      await prefs.setString('pref_language', _activeLanguage);
      await prefs.commit(); // ← TAMBAHAN: paksa flush ke disk
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
    final userList = await db.query('users', limit: 1);
    final user = userList.isNotEmpty ? userList.first : null;

    if (user != null) {
      userLocalLanguage = user['language_code'] as String?;
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
    }

    notifyListeners();
  }

  // ✅ PERUBAHAN 1: Kirim 'postal_code' dengan underscore
  Future<bool> checkRegion(String postalCode) async {
    setLoading(true);
    try {
      final response = await ApiClient.getClient().post(
        'check-region',
        data: {'postal_code': postalCode}, // ✅ UBAH: Tambah underscore
      );

      if (response.data['status'] == 'success') {
        detectedDistrict = response.data['data']['district'];
        detectedLanguage = response
            .data['data']['language_name']; // ✅ UBAH: Sesuaikan dengan backend
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

  Future<bool> login(String username, String password) async {
    setLoading(true);

    try {
      final response = await ApiClient.getClient().post(
        'login',
        data: {'username': username, 'password': password},
      );

      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        final user = data['user'];
        final token = data['access_token'];
        final userId = user['id'] ?? 0;

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
        await prefs.setString('username', username);
        await prefs.setInt('userid', userId);

        // ✅ Verifikasi token tersimpan
        String? savedToken = prefs.getString('auth_token');
        print('✅ Token tersimpan: ${savedToken != null}');

        if (user['image_url'] != null) {
          await prefs.setString('userimageurl', user['image_url']);
        }

        // ✅ FIX 2: Simpan user ke database lokal
        final db = await DatabaseHelper.instance.database;
        await db.delete('users'); // Hapus user lama
        await db.insert('users', {
          'id': userId,
          'name': user['name'],
          'username': user['username'],
          'token': token,
          'school_origin': user['school_origin'],
          'language_code': user['language_code'],
          'postal_code': user['postal_code'],
          'last_sync': null,
        });

        String userLang = user['language_code'] ?? 'id';
        userLocalLanguage = userLang;

        print('📦 SYNC: Memulai download semua resources...');

        List<String> errors = [];
        int totalItems = 0;
        int successItems = 0;

        // 1. Download Kamus
        if (userLang != 'id') {
          totalItems++;
          print('📖 SYNC: Download kamus $userLang');
          try {
            bool success = await DictionaryService.instance.downloadDictionary(
              userLang,
            );

            if (success) {
              successItems++;
              print('✅ Kamus berhasil didownload');
            } else {
              errors.add('Kamus download failed');
            }
          } catch (e) {
            errors.add('Kamus: $e');
            print('❌ SYNC Error kamus - $e');
          }
        }

        // 2. Download Materi
        totalItems++;
        print('📚 SYNC: Download materi...');
        try {
          await SyncService().syncMaterials(force: true);
          successItems++;
          print('✅ Materi berhasil didownload');
        } catch (e) {
          errors.add('Materi: $e');
          print('❌ SYNC Error materi - $e');
        }

        // 3. Download Soal
        totalItems++;
        print('📝 SYNC: Download soal...');
        try {
          await SyncService().syncQuestions(force: true);
          successItems++;
          print('✅ Soal berhasil didownload');
        } catch (e) {
          errors.add('Soal: $e');
          print('❌ SYNC Error soal - $e');
        }

        // ✅ FIX 3: Update last sync timestamp
        await db.update(
          'users',
          {'last_sync': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [userId],
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
        'name': data['name'],
        'username': data['username'],
        'password': data['password'],
        'school_origin': data['school_origin'],
        'postal_code': data['postal_code'],
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
        await prefs.setString('userschool', data['school_origin']);
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
