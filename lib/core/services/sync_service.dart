import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class SyncService {
  final Dio _dio = ApiClient.getClient();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// --- MASTER SYNC: Upload dulu, baru Download ---
  Future<void> syncAll(String languageCode, {bool force = false}) async {
    print('🔄 MULAI FULL SYNC... (Force: $force)');

    // 1. Upload Data Siswa (Progress) ke Server
    await syncUpProgress();

    // 2. Download Data Baru dari Server
    bool dictSuccess = await DictionaryService.instance.downloadDictionary(
      languageCode,
    );
    if (!dictSuccess) {
      print('⚠️ SYNC: Gagal download kamus, lanjutkan sync lainnya');
    }

    await syncMaterials(force: force);
    await syncQuestions(force: force);

    print('✅ FULL SYNC SELESAI.');
  }

  /// --- BARU: SYNC UP (Upload Progress Belajar) ---
  Future<void> syncUpProgress() async {
    final db = await DatabaseHelper.instance.database;
    final unsyncedData = await db.query(
      'student_progress',
      where: 'is_synced = 0',
    );

    if (unsyncedData.isEmpty) {
      print('✅ Tidak ada data progress baru untuk di-upload.');
      return;
    }

    print('📤 Mengupload ${unsyncedData.length} data progress ke server...');

    try {
      List<Map<String, dynamic>> payload = unsyncedData
          .map(
            (e) => {
              'question_id': e['question_id'],
              'student_answer': e['student_answer'],
              'is_correct': e['is_correct'] == 1,
              'time_spent_seconds': e['time_spent_seconds'] ?? 0,
              'answered_at': e['answered_at'],
            },
          )
          .toList();

      print('📦 Payload to upload: ${jsonEncode({'progress': payload})}');

      final response = await _dio.post(
        'sync/progress',
        data: {'progress': payload},
      );

      if (response.data['status'] == 'success') {
        print('✅ Upload Berhasil! Menandai data lokal sebagai synced...');

        // Batch update
        Batch batch = db.batch();
        for (var item in unsyncedData) {
          batch.update(
            'student_progress',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
        await batch.commit(noResult: true);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print('❌ Server Error (422): Detail: ${e.response?.data}');
      } else {
        print('❌ Gagal Upload Progress: $e');
      }
    }
  }

  /// --- SYNC MATERI (Delta Sync dengan parameter force) ---
  /// --- SYNC MATERI (Delta Sync dengan parameter force) ---
  Future<void> syncMaterials({bool force = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userList = await db.query('users', limit: 1);
      final user = userList.isNotEmpty ? userList.first : null;

      // Ambil last_sync (snake_case)
      String? lastSync = force ? null : (user?['last_sync'] as String?);

      print('📚 Cek Materi Baru... Last Sync: ${lastSync ?? "FULL SYNC"}');

      final response = await _dio.get(
        'sync/materials',
        queryParameters: lastSync != null ? {'last_sync': lastSync} : {},
      );

      if (response.data['status'] == 'success') {
        List data = response.data['data'];

        // 🔥 PERBAIKAN 1: Gunakan 'server_time' (snake_case) sesuai API Laravel
        String newServerTime =
            response.data['server_time'] ?? DateTime.now().toIso8601String();

        if (data.isEmpty) {
          print('✅ Materi sudah up-to-date.');
          if (user != null) {
            await db.update(
              'users',
              {'last_sync': newServerTime}, // Update last_sync
              where: 'id = ?',
              whereArgs: [user['id']],
            );
          }
          return;
        }

        print('📥 Menemukan ${data.length} materi baru.');

        for (var item in data) {
          // Handle deleted materials
          if (item['status'] == 'deleted') {
            await db.delete(
              'materials',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            continue;
          }

          // 🔥 PERBAIKAN 2: Prioritaskan snake_case ('image_url')
          String? imageUrl = item['image_url'] ?? item['imageurl'];

          // 1. Download Cover Image
          String? localCoverPath;
          if (imageUrl != null) {
            localCoverPath = await _downloadFile(imageUrl);
          }

          // 2. Download Assets dalam Content JSON
          // Handle content_indo dari API
          var rawContent = item['content_indo'] ?? item['contentindo'] ?? [];
          List<dynamic> contentJson = (rawContent is String)
              ? jsonDecode(rawContent)
              : rawContent;

          List<String> failedAssets = [];
          await _scanAndDownloadAssets(contentJson, failedAssets);

          // 3. Simpan ke database (Gunakan struktur snake_case BARU)
          await db.insert('materials', {
            'id': item['id'],
            'title_indo':
                item['title_indo'] ?? item['titleindo'] ?? 'Tanpa Judul',
            'category': item['category'] ?? 'umum',
            'image_url': imageUrl,
            'local_image_path': localCoverPath, // ✅ Masuk ke kolom snake_case
            'level_difficulty':
                item['level_difficulty'] ?? item['leveldifficulty'] ?? 1,
            'language_code':
                item['language_code'] ?? item['languagecode'] ?? 'id',
            'content_json': jsonEncode(
              contentJson,
            ), // Simpan sebagai JSON String
            'updated_at':
                item['updated_at'] ??
                item['updatedat'] ??
                DateTime.now().toIso8601String(),
            'ai_embeddings': (item['ai_embeddings'] != null)
                ? jsonEncode(item['ai_embeddings'])
                : null,
            'ai_status': item['ai_status'] ?? 'pending',
            'is_deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Update last sync user
        if (user != null) {
          await db.update(
            'users',
            {'last_sync': newServerTime}, // ✅ last_sync
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
    } catch (e) {
      print('❌ Error Sync Materi: $e'); // Ini yang tadi nampilin error Null
    }
  }

  Future<void> syncAIModelAndData(int materialId) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelFile = File('${directory.path}/mobilebert.tflite');

    // 1. Cek & Download Model Utama (Hanya jika belum ada di Lokal)
    if (!await modelFile.exists()) {
      print("📥 Mengunduh model AI utama ke local storage...");
      final modelUrl =
          "${ApiClient.baseUrl.replaceAll('/api/', '/storage/uploads/ai/')}mobilebert.tflite";
      await _dio.download(modelUrl, modelFile.path);
    }

    // 2. Download Data Materi Spesifik (Hasil olahan Python Server)
    print("📥 Mengunduh data cerdas untuk materi ID: $materialId");
    final response = await _dio.get(
      'sync/materials',
      queryParameters: {'id': materialId},
    );

    if (response.statusCode == 200) {
      final materialData = response.data['data'];

      // Simpan data cerdas (ai_embeddings) ke SQLite lokal agar siap digunakan offline
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'materials',
        {
          'ai_embeddings': jsonEncode(materialData['ai_embeddings']),
          'ai_status': 'ready',
        },
        where: 'id = ?',
        whereArgs: [materialId],
      );
    }
  }

  /// --- SYNC QUESTIONS (Delta Sync dengan parameter force) ---
  Future<void> syncQuestions({bool force = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final user = (await db.query('users', limit: 1)).firstOrNull;

      String? lastSync = force ? null : (user?['last_sync'] as String?);

      print('📝 Cek Soal Baru... Last Sync: ${lastSync ?? "FULL SYNC"}');

      final response = await _dio.get(
        'sync/questions',
        queryParameters: lastSync != null ? {'last_sync': lastSync} : {},
      );

      if (response.data['status'] == 'success') {
        List data = response.data['data'];
        print('📥 Menemukan ${data.length} soal baru.');

        for (var item in data) {
          if (item['status'] == 'deleted') {
            await db.delete(
              'questions',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            continue;
          }

          // Parse options_json dengan aman
          var rawOptions = item['options_json'] ?? item['optionsjson'] ?? [];
          String optionsString = (rawOptions is String)
              ? rawOptions
              : jsonEncode(rawOptions);

          await db.insert('questions', {
            'id': item['id'],
            'material_id': item['material_id'] ?? item['materialid'],
            'question_text_indo':
                item['question_text_indo'] ??
                item['questiontextindo'] ??
                'Soal Kosong',
            'question_text_tolaki':
                item['question_text_tolaki'] ?? item['questiontexttolaki'],
            'options_json': optionsString,
            'correct_answer_key':
                item['correct_answer_key'] ?? item['correctanswerkey'] ?? 'a',
            'difficulty_weight':
                item['difficulty_weight'] ?? item['difficultyweight'] ?? 1,
            'updated_at': item['updated_at'] ?? item['updatedat'],
            'is_deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print('❌ Error Sync Soal: $e');
    }
  }

  /// --- LOGIC ASSETS ---
  Future<void> _scanAndDownloadAssets(
    List<dynamic> nodes,
    List<String> failedAssets,
  ) async {
    for (var node in nodes) {
      // Download gambar biasa
      if (node['type'] == 'image' && node['url'] != null) {
        String? result = await _downloadAssetImage(node['url']);
        if (result == null) {
          failedAssets.add(node['url']);
        }
      }

      // Download gambar dalam syllable exercise
      if (node['type'] == 'syllable_exercise' && node['items'] != null) {
        for (var item in node['items']) {
          if (item['image'] != null) {
            String? result = await _downloadAssetImage(item['image']);
            if (result == null) {
              failedAssets.add(item['image']);
            }
          }
        }
      }
    }
  }

  /// ✅ DOWNLOAD FILE (Cover Image)
  Future<String?> _downloadFile(String serverPath) async {
    try {
      final fileName = p.basename(serverPath);
      final dir = await _localPath;
      final savePath = '$dir/$fileName';

      // Cek apakah sudah ada
      if (await File(savePath).exists()) {
        print('✅ File sudah ada: $fileName');
        return savePath;
      }

      final baseUrl = ApiClient.baseUrl.replaceAll('/api/', '/storage/');
      final fullUrl = '$baseUrl/$serverPath';

      print('📥 Downloading: $fullUrl');
      await _dio.download(fullUrl, savePath);

      // VERIFIKASI FILE BERHASIL DISIMPAN
      if (await File(savePath).exists()) {
        final fileSize = await File(savePath).length();
        print('✅ Download sukses: $fileName ($fileSize bytes)');
        return savePath;
      } else {
        print('❌ File gagal disimpan: $fileName');
        return null;
      }
    } catch (e) {
      print('❌ Error download $serverPath: $e');
      return null;
    }
  }

  /// ✅ DOWNLOAD ASSET IMAGE dengan tracking database
  /// ✅ DOWNLOAD ASSET IMAGE dengan tracking database (FIXED)
  Future<String?> _downloadAssetImage(String fileName) async {
    try {
      final dir = await _localPath;
      final savePath = '$dir/$fileName';

      // Cek apakah sudah ada di database
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query(
        'downloaded_assets',
        where: 'filename = ?',
        whereArgs: [fileName],
      );

      // Jika file fisik ada & tercatat di db, skip download
      if (existing.isNotEmpty && await File(savePath).exists()) {
        print('✅ Asset sudah ada: $fileName');
        return savePath;
      }

      print('📥 Downloading Asset: $fileName');
      // Pastikan URL storage benar
      final baseUrl = ApiClient.baseUrl.replaceAll('/api/', '/storage/assets/');
      final fullUrl = '$baseUrl$fileName';

      await _dio.download(fullUrl, savePath);

      // VERIFIKASI file berhasil disimpan
      if (await File(savePath).exists()) {
        final fileSize = await File(savePath).length();

        // ✅ FIX: Gunakan snake_case (local_path, download_date, file_size)
        await db.insert('downloaded_assets', {
          'filename': fileName,
          'local_path': savePath, // <--- DULU: localpath
          'download_date': DateTime.now()
              .toIso8601String(), // <--- DULU: downloaddate
          'file_size': fileSize, // <--- DULU: filesize
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        print('✅ Asset downloaded: $fileName ($fileSize bytes)');
        return savePath;
      } else {
        print('❌ Asset gagal disimpan: $fileName');
        return null;
      }
    } catch (e) {
      print('❌ Error download asset $fileName: $e');
      return null;
    }
  }

  Future<void> performGlobalSync() async {
    print('📡 Mencoba sinkronisasi background...');

    // 1. Sinkronisasi Foto Profil
    await syncPendingProfile();

    // 2. Sinkronisasi Progress Belajar
    await syncUpProgress();

    print('✅ Sinkronisasi background selesai.');
  }

  Future<void> syncPendingProfile() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query('users', limit: 1);

    if (users.isEmpty || users.first['is_synced'] == 1) return;

    final user = users.first;
    final String? localPath = user['local_image_path'] as String?;

    if (localPath != null && await File(localPath).exists()) {
      try {
        FormData formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            localPath,
            filename: p.basename(localPath),
          ),
        });

        // Pastikan endpoint Laravel Anda sudah benar
        final response = await _dio.post('/update-profile', data: formData);

        if (response.data['status'] == 'success') {
          String serverUrl = response.data['data']['image_url'];

          await db.update(
            'users',
            {
              'image_url': serverUrl,
              'is_synced': 1, // BERHASIL: Tandai bersih
            },
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      } catch (e) {
        print(
          "☁️ Background Sync Profil: Koneksi lambat/offline. Akan dicoba lagi nanti.",
        );
      }
    }
  }
}
