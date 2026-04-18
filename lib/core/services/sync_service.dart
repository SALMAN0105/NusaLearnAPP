import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
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

    await _syncAllRequiredAssets();

    print('✅ FULL SYNC SELESAI.');
  }

  Future<void> _syncAllRequiredAssets() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Ambil semua assets_required dari questions
      final questions = await db.query(
        'questions',
        columns: ['assets_required'],
        where: 'assets_required IS NOT NULL AND is_deleted = 0',
      );

      // Kumpulkan semua filename unik
      final Set<String> allFilenames = {};
      for (final q in questions) {
        final raw = q['assets_required'] as String?;
        if (raw != null && raw.isNotEmpty) {
          try {
            final List decoded = jsonDecode(raw);
            allFilenames.addAll(decoded.map((e) => e.toString()));
          } catch (e) {
            print('⚠️ Gagal parse assets_required: $raw');
          }
        }
      }

      if (allFilenames.isEmpty) {
        print('✅ Tidak ada aset yang diperlukan soal.');
        return;
      }

      print('📦 Total aset unik dari semua soal: ${allFilenames.length}');
      await syncAssets(allFilenames.toList());
    } catch (e) {
      print('❌ Error _syncAllRequiredAssets: $e');
    }
  }

  /// --- BARU: SYNC UP (Upload Progress Belajar) ---
  // lib/core/services/sync_service.dart

  /// ✅ P7: Update syncUpProgress() support JSON answer
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
      List<Map<String, dynamic>> payload = unsyncedData.map((e) {
        final templateType = e['template_type'] as String? ?? 'multiple_choice';
        final rawAnswer = e['student_answer'] as String? ?? '';

        // ✅ P7: Decode JSON answer untuk template kompleks
        dynamic studentAnswer;
        switch (templateType) {
          case 'drag_and_drop':
          case 'matching_game':
          case 'image_quiz':
            // Coba decode sebagai JSON
            try {
              studentAnswer = jsonDecode(rawAnswer);
            } catch (_) {
              studentAnswer = rawAnswer; // fallback ke string
            }
            break;
          case 'multiple_choice':
          case 'fill_blank':
          default:
            studentAnswer = rawAnswer; // String biasa
            break;
        }

        return {
          'question_id': e['question_id'],
          'student_answer': studentAnswer,
          'is_correct': e['is_correct'] == 1,
          'time_spent_seconds': e['time_spent_seconds'] ?? 0,
          'answered_at': e['answered_at'],
          'template_type': templateType, // ✅ P7: Kirim template_type
        };
      }).toList();

      final response = await _dio.post(
        'sync/progress',
        data: {'progress': payload},
      );

      if (response.data['status'] == 'success') {
        print(
          '✅ Upload Berhasil! Menandai ${unsyncedData.length} data sebagai synced...',
        );

        // Batch update
        final batch = db.batch();
        for (var item in unsyncedData) {
          batch.update(
            'student_progress',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        }
        await batch.commit(noResult: true);

        // Log jika ada error parsial dari server
        final errors = response.data['errors'] as List? ?? [];
        if (errors.isNotEmpty) {
          print('⚠️ ${errors.length} item gagal di server:');
          for (final err in errors) {
            print('   Index ${err['index']}: ${err['message']}');
          }
        }
      }
    } on DioException catch (e) {
      if (e.response != null) {
        print(
          '❌ Server Error (${e.response?.statusCode}): ${e.response?.data}',
        );
      } else {
        print('❌ Gagal Upload Progress (offline?): ${e.message}');
      }
    }
  }

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
          dynamic parsedContent;

          if (rawContent is String) {
            try {
              parsedContent = jsonDecode(rawContent);
            } catch (e) {
              parsedContent = [];
            }
          } else {
            parsedContent = rawContent;
          }

          List<dynamic> nodesToScan = [];
          if (parsedContent is List) {
            nodesToScan = parsedContent; // Format Lama
          } else if (parsedContent is Map &&
              parsedContent.containsKey('content_structured')) {
            // Format Baru AI
            var sections = parsedContent['content_structured'];
            if (sections is List) {
              for (var sec in sections) {
                if (sec['chunks'] is List) {
                  nodesToScan.addAll(sec['chunks']);
                }
              }
            }
          }

          List<String> failedAssets = [];
          await _scanAndDownloadAssets(nodesToScan, failedAssets);

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
              parsedContent,
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

  // ── FASE 4: ENGINE MANAJEMEN DLC GGUF (MEMORY-SAFE) ──
  // ── FASE 4.1: ENGINE MANAJEMEN DLC GGUF (RESUMABLE & MEMORY-SAFE) ──
  Future<bool> syncAIModelAndData(
    int materialId, {
    Function(double)? onProgress,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
    final modelFile = File('${directory.path}/$modelFileName');
    final db = await DatabaseHelper.instance.database;

    // 1. Validasi Registry O(1)
    final registryCheck = await db.query(
      'ai_model_registry',
      where: 'model_name = ? AND is_ready = 1',
      whereArgs: [modelFileName],
    );

    if (registryCheck.isNotEmpty && await modelFile.exists()) {
      print("⚡ [DLC ENGINE] Model GGUF sudah siap (Registry Verified).");
      return true;
    }

    // 2. Logika RESUME: Cek fragmentasi file di disk
    int existingLength = 0;
    if (await modelFile.exists()) {
      existingLength = await modelFile.length();
      print("📂 [DLC ENGINE] Resume unduhan dari byte: $existingLength");
    }

    final baseUrl = ApiClient.baseUrl;
    final storageBase = baseUrl.contains('/api')
        ? baseUrl.substring(0, baseUrl.indexOf('/api'))
        : baseUrl.replaceAll(RegExp(r'/$'), '');
    final modelUrl = '$storageBase/storage/models/$modelFileName';

    try {
      // 3. Eksekusi Download dengan Header RANGE (Standard RFC 7233)
      await _dio.download(
        modelUrl,
        modelFile.path,
        options: Options(
          headers: {
            'range': 'bytes=$existingLength-', // Request hanya sisa data
          },
        ),
        deleteOnError:
            false, // ⚠️ CRITICAL: Jangan hapus file jika error agar bisa lanjut nanti
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Kalkulasi progres kumulatif (existing + current)
            final actualTotal = total + existingLength;
            final actualReceived = received + existingLength;
            final progress = actualReceived / actualTotal;

            if (onProgress != null) onProgress(progress);
            print(
              "⏳ [DLC ENGINE] Total Progress: ${(progress * 100).toStringAsFixed(1)}%",
            );
          }
        },
      );

      // 4. Finalisasi & Registrasi
      if (await modelFile.exists() && await modelFile.length() > 0) {
        await db.insert('ai_model_registry', {
          'id': 'qwen_05b_v1',
          'model_name': modelFileName,
          'absolute_path': modelFile.path,
          'is_ready': 1,
          'downloaded_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        print("✅ [DLC ENGINE] Model GGUF diamankan sepenuhnya.");
        return true;
      }
      return false;
    } catch (e) {
      print(
        "❌ [DLC ENGINE] Koneksi terputus. Data parsial tetap aman di disk.",
      );
      return false;
    }
  }

  // lib/core/services/sync_service.dart

  Future<void> syncQuestions({bool force = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final user = (await db.query('users', limit: 1)).isNotEmpty
          ? (await db.query('users', limit: 1)).first
          : null;

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

          // ✅ Parse options_json
          var rawOptions = item['options_json'] ?? [];
          String optionsString = (rawOptions is String)
              ? rawOptions
              : jsonEncode(rawOptions);

          // ✅ FIX #6: Parse question_data
          var rawQuestionData = item['question_data'];
          String? questionDataString;
          if (rawQuestionData != null) {
            questionDataString = (rawQuestionData is String)
                ? rawQuestionData
                : jsonEncode(rawQuestionData);
          }

          // ✅ FIX #6: Parse assets_required
          var rawAssetsRequired = item['assets_required'];
          String? assetsRequiredString;
          if (rawAssetsRequired != null) {
            // Server sudah guarantee array, tapi tetap defensive
            assetsRequiredString = (rawAssetsRequired is String)
                ? rawAssetsRequired
                : jsonEncode(rawAssetsRequired);
          }

          // ✅ FIX #6: Simpan SEMUA field termasuk yang baru
          await db.insert('questions', {
            'id': item['id'],
            'material_id': item['material_id'],
            'question_text_indo': item['question_text_indo'] ?? 'Soal Kosong',
            'question_text_tolaki': item['question_text_tolaki'],
            'options_json': optionsString,
            'correct_answer_key': item['correct_answer_key'] ?? 'a',
            'difficulty_weight': item['difficulty_weight'] ?? 1,
            // ✅ Field baru Fase 3
            'template_type': item['template_type'] ?? 'multiple_choice',
            'question_data': questionDataString,
            'assets_required': assetsRequiredString,
            'updated_at': item['updated_at'],
            'is_deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        print('✅ Sync Questions selesai: ${data.length} soal diperbarui.');
      }
    } catch (e) {
      print('❌ Error Sync Soal: $e');
    }
  }

  Future<SyncAssetsResult> syncAssets(List<String> filenames) async {
    if (filenames.isEmpty) {
      print('✅ Tidak ada aset yang perlu di-sync.');
      return SyncAssetsResult(downloaded: 0, failed: 0, skipped: 0);
    }

    print('📦 Memulai sync ${filenames.length} aset...');

    final db = await DatabaseHelper.instance.database;

    // 1. Batch check lokal: mana yang sudah ada
    final existing = await db.query(
      'downloaded_assets',
      where: 'filename IN (${filenames.map((_) => '?').join(',')})',
      whereArgs: filenames,
    );
    final existingFilenames = existing
        .map((e) => e['filename'] as String)
        .toSet();

    // 2. Filter: hanya yang belum ada
    final toDownload = filenames
        .where((f) => !existingFilenames.contains(f))
        .toList();
    final skipped = filenames.length - toDownload.length;

    print(
      '📊 Status: ${existingFilenames.length} sudah ada, ${toDownload.length} perlu download, $skipped dilewati',
    );

    if (toDownload.isEmpty) {
      return SyncAssetsResult(downloaded: 0, failed: 0, skipped: skipped);
    }

    // 3. Request URL dari server (batch)
    int downloaded = 0;
    int failed = 0;

    try {
      final response = await _dio.post(
        'sync/assets',
        data: {'filenames': toDownload},
      );

      if (response.data['status'] == 'success') {
        final List assetList = response.data['data'] ?? [];

        // FILTER DEFENSIVE: Mencegah I/O freeze akibat URL null
        final availableAssets = assetList
            .where(
              (a) =>
                  a['status'] == 'available' &&
                  a['url'] != null &&
                  a['url'].toString().isNotEmpty,
            )
            .toList();

        // 4. Download satu per satu dengan retry (Hanya untuk aset valid)
        for (final asset in availableAssets) {
          final String filename = asset['filename'];
          final String url = asset['url'];

          bool success = await _downloadAssetWithRetry(
            filename: filename,
            url: url,
            maxRetries: 3,
          );

          if (success) {
            downloaded++;
            debugPrint('✅ [$downloaded/${toDownload.length}] $filename');
          } else {
            failed++;
            debugPrint('❌ Gagal download: $filename');
          }
        }

        // Kalkulasikan sisa aset yang missing sebagai failed
        failed += (assetList.length - availableAssets.length);
      }
    } on DioException catch (e) {
      debugPrint('❌ Error sync assets: ${e.message}');
      failed = toDownload.length;
    }

    print(
      '📊 Sync Assets selesai: $downloaded berhasil, $failed gagal, $skipped dilewati',
    );
    return SyncAssetsResult(
      downloaded: downloaded,
      failed: failed,
      skipped: skipped,
    );
  }

  /// ✅ Helper: Download dengan retry logic
  Future<bool> _downloadAssetWithRetry({
    required String filename,
    required String url,
    int maxRetries = 3,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final dir = await _localPath;
        final savePath = '$dir/$filename';

        // Cek file fisik sudah ada
        if (await File(savePath).exists()) {
          final fileSize = await File(savePath).length();
          if (fileSize > 0) return true; // File valid, skip
        }

        await _dio.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final percent = (received / total * 100).toStringAsFixed(0);
              print('  ⬇️ $filename: $percent%');
            }
          },
        );

        if (await File(savePath).exists()) {
          final fileSize = await File(savePath).length();
          if (fileSize > 0) {
            // Simpan ke DB
            final db = await DatabaseHelper.instance.database;
            await db.insert('downloaded_assets', {
              'filename': filename,
              'local_path': savePath,
              'download_date': DateTime.now().toIso8601String(),
              'file_size': fileSize,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            return true;
          }
        }
      } on DioException catch (e) {
        print('  ⚠️ Attempt $attempt/$maxRetries gagal: ${e.message}');
        if (attempt < maxRetries) {
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: pow(2, attempt - 1).toInt()));
        }
      }
    }

    return false;
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
      final fullUrl = '$baseUrl$serverPath';

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

  Future<void> performGlobalSync({bool force = false}) async {
    print('📡 Mencoba sinkronisasi background...');

    await syncPendingProfile();
    await syncUpProgress();

    try {
      final db = await DatabaseHelper.instance.database;
      final userList = await db.query('users', limit: 1);

      // Default ke 'id' jika user belum ada atau bahasa kosong
      String langCode = 'id';
      if (userList.isNotEmpty && userList.first['language_code'] != null) {
        langCode = userList.first['language_code'] as String;
      }

      bool dictSuccess = await DictionaryService.instance.downloadDictionary(
        langCode,
      );
      if (!dictSuccess) {
        print(
          '⚠️ [SyncService] Gagal update kamus, lanjut sinkronisasi materi.',
        );
      } else {
        print('✅ [SyncService] Kamus berhasil diperbarui.');
      }
    } catch (e) {
      print('❌ [SyncService] Error saat memproses kamus: $e');
    }

    // Tambahkan sync materi & soal jika force = true
    if (force) {
      await syncMaterials(force: true);
      await syncQuestions(force: true);
    }

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

  /// ✅ P7: Helper terpusat untuk simpan progress ke SQLite
  /// Dipanggil dari semua QuizWidget setelah user menjawab
  Future<void> saveProgress({
    required int userId,
    required int questionId,
    required String templateType,
    required dynamic
    studentAnswer, // String atau Map/List untuk template kompleks
    required bool isCorrect,
    int? timeSpentSeconds,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    // Serialize answer ke String untuk SQLite
    String answerString;
    if (studentAnswer is String) {
      answerString = studentAnswer;
    } else {
      // Map atau List → encode ke JSON string
      answerString = jsonEncode(studentAnswer);
    }

    // Cek apakah sudah ada jawaban benar sebelumnya
    final existingCorrect = await db.query(
      'student_progress',
      where: 'user_id = ? AND question_id = ? AND is_correct = 1',
      whereArgs: [userId, questionId],
    );

    // Jika sudah benar sebelumnya, jangan overwrite
    if (existingCorrect.isNotEmpty) {
      print('ℹ️ Soal $questionId sudah pernah dijawab benar, skip.');
      return;
    }

    final existingAny = await db.query(
      'student_progress',
      where: 'user_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );

    if (existingAny.isEmpty) {
      // Insert baru
      await db.insert('student_progress', {
        'user_id': userId,
        'question_id': questionId,
        'student_answer': answerString,
        'is_correct': isCorrect ? 1 : 0,
        'time_spent_seconds': timeSpentSeconds ?? 0,
        'answered_at': now,
        'template_type': templateType,
        'is_synced': 0,
      });
    } else if (isCorrect) {
      // Update hanya jika jawaban sekarang benar
      await db.update(
        'student_progress',
        {
          'student_answer': answerString,
          'is_correct': 1,
          'time_spent_seconds': timeSpentSeconds ?? 0,
          'answered_at': now,
          'template_type': templateType,
          'is_synced': 0,
        },
        where: 'user_id = ? AND question_id = ?',
        whereArgs: [userId, questionId],
      );
    }

    print(
      '💾 Progress saved: Q$questionId | $templateType | ${isCorrect ? "✅" : "❌"}',
    );
  }
}

class SyncAssetsResult {
  final int downloaded;
  final int failed;
  final int skipped;

  const SyncAssetsResult({
    required this.downloaded,
    required this.failed,
    required this.skipped,
  });

  bool get hasFailures => failed > 0;
  int get total => downloaded + failed + skipped;

  @override
  String toString() =>
      'SyncAssetsResult(downloaded: $downloaded, failed: $failed, skipped: $skipped)';
}
