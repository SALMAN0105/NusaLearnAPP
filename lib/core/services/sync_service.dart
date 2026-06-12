import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
  Future<void> syncAll(String kodeBahasa, {bool force = false}) async {
    print('🔄 MULAI FULL SYNC... (Force: $force)');

    // 1. Upload Data Siswa (Progress) ke Server
    await syncUpProgress();

    // 2. Download Data Baru dari Server
    bool dictSuccess = await DictionaryService.instance.downloadDictionary(
      kodeBahasa,
    );

    if (!dictSuccess) {
      print('⚠️ SYNC: Gagal download kamus, lanjutkan sync lainnya');
    }

    String? newServerTime;

    String? timeMateri = await syncMaterials(force: force);
    String? timeSoal = await syncQuestions(force: force);

    // Ambil waktu dari salah satu (biasanya sama karena ditarik bersamaan)
    newServerTime = timeMateri ?? timeSoal;

    await _syncAllRequiredAssets();

    // Update last sync user SETELAH SEMUA BERHASIL
    if (newServerTime != null) {
      final db = await DatabaseHelper.instance.database;
      final user = (await db.query('pengguna', limit: 1)).isNotEmpty
          ? (await db.query('pengguna', limit: 1)).first
          : null;
      if (user != null) {
        await db.update(
          'pengguna',
          {'last_sync': newServerTime},
          where: 'id = ?',
          whereArgs: [user['id']],
        );
      }
    }

    print('✅ FULL SYNC SELESAI.');
  }

  Future<void> _syncAllRequiredAssets() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Ambil semua aset_diperlukan dari questions
      final questions = await db.query(
        'soal',
        columns: ['aset_diperlukan'],
        where: 'aset_diperlukan IS NOT NULL AND is_deleted = 0',
      );

      // Kumpulkan semua filename unik
      final Set<String> allFilenames = {};
      for (final q in questions) {
        final raw = q['aset_diperlukan'] as String?;
        if (raw != null && raw.isNotEmpty) {
          try {
            final List decoded = jsonDecode(raw);
            allFilenames.addAll(decoded.map((e) => e.toString()));
          } catch (e) {
            print('⚠️ Gagal parse aset_diperlukan: $raw');
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
      'progres_siswa',
      where: 'sinkron = 0',
    );

    if (unsyncedData.isEmpty) {
      print('✅ Tidak ada data progress baru untuk di-upload.');
      return;
    }

    print('📤 Mengupload ${unsyncedData.length} data progress ke server...');

    try {
      List<Map<String, dynamic>> payload = unsyncedData.map((e) {
        final tipeTemplate = e['tipe_template'] as String? ?? 'multiple_choice';
        final rawAnswer = e['jawaban_siswa'] as String? ?? '';

        // ✅ P7: Decode JSON answer untuk template kompleks
        dynamic jawabanSiswa;
        switch (tipeTemplate) {
          case 'drag_and_drop':
          case 'matching_game':
          case 'image_quiz':
            // Coba decode sebagai JSON
            try {
              jawabanSiswa = jsonDecode(rawAnswer);
            } catch (_) {
              jawabanSiswa = rawAnswer; // fallback ke string
            }
            break;
          case 'multiple_choice':
          case 'fill_blank':
          default:
            jawabanSiswa = rawAnswer; // String biasa
            break;
        }

        return {
          'soal_id': e['soal_id'],
          'data_jawaban': jawabanSiswa,
          'benar': e['benar'] == 1,
          'waktu_detik': e['waktu_detik'] ?? 0,
          'dijawab_pada': e['dijawab_pada'],
          'tipe_template': tipeTemplate, // ✅ P7: Kirim tipe_template
        };
      }).toList();

      // ✅ FIX 422: Filter defensif — buang item yang soal_id-nya null
      // atau data_jawaban-nya kosong agar server tidak mengembalikan 422.
      payload = payload.where((item) {
        final qId = item['soal_id'];
        final ans = item['data_jawaban'];
        final isAnswerPresent = ans != null &&
            !(ans is String && (ans as String).isEmpty) &&
            !(ans is List && (ans as List).isEmpty) &&
            !(ans is Map && (ans as Map).isEmpty);
        return qId != null && isAnswerPresent;
      }).toList();

      if (payload.isEmpty) {
        print('⚠️ syncUpProgress: Semua item difilter (soal_id/answer null). Upload dibatalkan.');
        return;
      }

      final response = await _dio.post(
        'sync/progress',
        data: {'answers': payload},
      );

      if (response.data['status'] == 'success') {
        print(
          '✅ Upload Berhasil! Menandai ${unsyncedData.length} data sebagai synced...',
        );

        // Batch update
        final batch = db.batch();
        for (var item in unsyncedData) {
          batch.update(
            'progres_siswa',
            {'sinkron': 1},
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

  /// --- BARU: SYNC DOWN (Download Progress Belajar saat login) ---
  Future<void> syncDownProgress() async {
    try {
      final response = await _dio.get('sync/progress');
      if (response.data['status'] == 'success') {
        List data = response.data['data'];
        final db = await DatabaseHelper.instance.database;
        final userList = await db.query('pengguna', limit: 1);
        if (userList.isEmpty) return;
        int penggunaId = userList.first['id'] as int;

        final batch = db.batch();
        for (var item in data) {
          batch.insert('progres_siswa', {
            'pengguna_id': penggunaId,
            'soal_id': item['soal_id'],
            'jawaban_siswa': item['data_jawaban']?.toString() ?? '',
            'benar': (item['benar'] == true || item['benar'] == 1) ? 1 : 0,
            'waktu_detik': item['waktu_detik'] ?? 0,
            'dijawab_pada': item['dijawab_pada'] ?? DateTime.now().toIso8601String(),
            'tipe_template': item['tipe_template'] ?? 'multiple_choice',
            'sinkron': 1, // Sudah sinkron
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        print('✅ SYNC: Downloaded ${data.length} progress data');
      }
    } catch (e) {
      print('❌ Error Sync Down Progress: $e');
    }
  }

  /// --- SYNC MATERI (Delta Sync dengan parameter force) ---
  Future<String?> syncMaterials({bool force = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userList = await db.query('pengguna', limit: 1);
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
              'pengguna',
              {'last_sync': newServerTime}, // Update last_sync
              where: 'id = ?',
              whereArgs: [user['id']],
            );
          }
          return newServerTime;
        }

        print('📥 Menemukan ${data.length} materi baru.');

        for (var item in data) {
          // Handle deleted materials
          if (item['status'] == 'deleted') {
            await db.delete(
              'materi',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            continue;
          }

          // 🔥 PERBAIKAN 2: Prioritaskan snake_case ('url_gambar')
          String? urlGambar = item['url_gambar'] ?? item['imageurl'];

          // 1. Download Cover Image
          String? localCoverPath;
          if (urlGambar != null) {
            localCoverPath = await _downloadFile(urlGambar);
          }

          // 2. Download Assets dalam Content JSON
          // Handle konten dari API
          var rawContent = item['konten'] ?? item['contentindo'] ?? [];
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
          await db.insert('materi', {
            'id': item['id'],
            'judul':
                item['judul'] ?? item['titleindo'] ?? 'Tanpa Judul',
            'kategori': item['kategori'] ?? 'umum',
            'url_gambar': urlGambar,
            'local_image_path': localCoverPath, // ✅ Masuk ke kolom snake_case
            'tingkat_kesulitan':
                item['tingkat_kesulitan'] ?? item['leveldifficulty'] ?? 1,
            'kode_bahasa':
                item['kode_bahasa'] ?? item['languagecode'] ?? 'id',
            'konten': jsonEncode(
              parsedContent,
            ), // Simpan sebagai JSON String
            'diperbarui_pada':
                item['diperbarui_pada'] ??
                item['updatedat'] ??
                DateTime.now().toIso8601String(),
            'ai_embeddings': (item['ai_embeddings'] != null)
                ? jsonEncode(item['ai_embeddings'])
                : null,
            'status_ai': item['status_ai'] ?? 'pending',
            'is_deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return newServerTime;
      }
    } catch (e) {
      print('❌ Error Sync Materi: $e'); // Ini yang tadi nampilin error Null
    }
    return null;
  }

  // ── FASE 4: ENGINE MANAJEMEN DLC GGUF (MEMORY-SAFE) ──
  // ── FASE 4.1: ENGINE MANAJEMEN DLC GGUF (RESUMABLE & MEMORY-SAFE) ──
  Future<bool> syncAIModelAndData(
    int materiId, {
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
      // Gunakan Dio instance baru tanpa timeout agar download file besar (491MB) tidak terputus
      final downloadDio = Dio(BaseOptions(
        headers: {
          'Host': ApiClient.hostDomain,
        },
      ));
      
      // Bypass SSL Certificate Error untuk download IP lokal
      downloadDio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );

      await downloadDio.download(
        modelUrl,
        modelFile.path,
        options: Options(
          headers: {
            'range': 'bytes=$existingLength-', // Request hanya sisa data
          },
        ),
        deleteOnError: false, // ⚠️ CRITICAL: Jangan hapus file jika error agar bisa lanjut nanti
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

  Future<String?> syncQuestions({bool force = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final user = (await db.query('pengguna', limit: 1)).isNotEmpty
          ? (await db.query('pengguna', limit: 1)).first
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
              'soal',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            continue;
          }

          // ✅ Parse opsi_json
          var rawOptions = item['opsi_json'] ?? [];
          String optionsString = (rawOptions is String)
              ? rawOptions
              : jsonEncode(rawOptions);

          // ✅ FIX #6: Parse data_soal
          var rawQuestionData = item['data_soal'];
          String? questionDataString;
          if (rawQuestionData != null) {
            questionDataString = (rawQuestionData is String)
                ? rawQuestionData
                : jsonEncode(rawQuestionData);
          }

          // ✅ FIX #6: Parse aset_diperlukan
          var rawAssetsRequired = item['aset_diperlukan'];
          String? assetsRequiredString;
          if (rawAssetsRequired != null) {
            // Server sudah guarantee array, tapi tetap defensive
            assetsRequiredString = (rawAssetsRequired is String)
                ? rawAssetsRequired
                : jsonEncode(rawAssetsRequired);
          }

          // ✅ FIX #6: Simpan SEMUA field termasuk yang baru
          await db.insert('soal', {
            'id': item['id'],
            'materi_id': item['materi_id'],
            'teks_soal': item['teks_soal'] ?? 'Soal Kosong',
            'question_text_tolaki': item['question_text_tolaki'],
            'opsi_json': optionsString,
            'kunci_jawaban': item['kunci_jawaban'] ?? 'a',
            'bobot_kesulitan': item['bobot_kesulitan'] ?? 1,
            // ✅ Field baru Fase 3
            'tipe_template': item['tipe_template'] ?? 'multiple_choice',
            'data_soal': questionDataString,
            'aset_diperlukan': assetsRequiredString,
            'diperbarui_pada': item['diperbarui_pada'],
            'is_deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        print('✅ Sync Questions selesai: ${data.length} soal diperbarui.');
        return response.data['server_time'] ?? DateTime.now().toIso8601String();
      }
    } catch (e) {
      print('❌ Error Sync Soal: $e');
    }
    return null;
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
        final List assetList = response.data['data']['assets'] ?? [];

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
          final String filename = asset['nama_file'];
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

        // ✅ FIX 403: Normalisasi URL — pastikan path relatif selalu
        // diawali 'storage/' agar symlink Laravel (storage:link) terpenuhi.
        // Jika URL sudah absolut (http/https) atau sudah mengandung 'storage/',
        // tidak ada perubahan yang dilakukan.
        String resolvedUrl = url;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          // Strip leading slash jika ada
          resolvedUrl = resolvedUrl.startsWith('/') ? resolvedUrl.substring(1) : resolvedUrl;
          if (!resolvedUrl.startsWith('storage/')) {
            resolvedUrl = 'storage/$resolvedUrl';
          }
          final baseUrl = ApiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '/');
          resolvedUrl = '$baseUrl$resolvedUrl';
        }

        await _dio.download(
          resolvedUrl,
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
      // Pastikan URL storage benar menggunakan route aset
      final baseUrl = ApiClient.baseUrl.replaceAll('/api/', '/assets/serve/');
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
      final userList = await db.query('pengguna', limit: 1);

      // Default ke 'id' jika user belum ada atau bahasa kosong
      String langCode = 'id';
      if (userList.isNotEmpty && userList.first['kode_bahasa'] != null) {
        langCode = userList.first['kode_bahasa'] as String;
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
    final List<Map<String, dynamic>> users = await db.query('pengguna', limit: 1);

    if (users.isEmpty || users.first['sinkron'] == 1) return;

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
          String serverUrl = response.data['data']['url_gambar'];

          await db.update(
            'pengguna',
            {
              'url_gambar': serverUrl,
              'sinkron': 1, // BERHASIL: Tandai bersih
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
    required int penggunaId,
    required int soalId,
    required String tipeTemplate,
    required dynamic
    jawabanSiswa, // String atau Map/List untuk template kompleks
    required bool benar,
    int? waktuDetik,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    // Serialize answer ke String untuk SQLite
    String answerString;
    if (jawabanSiswa is String) {
      answerString = jawabanSiswa;
    } else {
      // Map atau List → encode ke JSON string
      answerString = jsonEncode(jawabanSiswa);
    }

    // Cek apakah sudah ada jawaban benar sebelumnya
    final existingCorrect = await db.query(
      'progres_siswa',
      where: 'pengguna_id = ? AND soal_id = ? AND benar = 1',
      whereArgs: [penggunaId, soalId],
    );

    // Jika sudah benar sebelumnya, jangan overwrite
    if (existingCorrect.isNotEmpty) {
      print('ℹ️ Soal $soalId sudah pernah dijawab benar, skip.');
      return;
    }

    final existingAny = await db.query(
      'progres_siswa',
      where: 'pengguna_id = ? AND soal_id = ?',
      whereArgs: [penggunaId, soalId],
    );

    if (existingAny.isEmpty) {
      // Insert baru
      await db.insert('progres_siswa', {
        'pengguna_id': penggunaId,
        'soal_id': soalId,
        'jawaban_siswa': answerString,
        'benar': benar ? 1 : 0,
        'waktu_detik': waktuDetik ?? 0,
        'dijawab_pada': now,
        'tipe_template': tipeTemplate,
        'sinkron': 0,
      });
    } else if (benar) {
      // Update hanya jika jawaban sekarang benar
      await db.update(
        'progres_siswa',
        {
          'jawaban_siswa': answerString,
          'benar': 1,
          'waktu_detik': waktuDetik ?? 0,
          'dijawab_pada': now,
          'tipe_template': tipeTemplate,
          'sinkron': 0,
        },
        where: 'pengguna_id = ? AND soal_id = ?',
        whereArgs: [penggunaId, soalId],
      );
    }

    print(
      '💾 Progress saved: Q$soalId | $tipeTemplate | ${benar ? "✅" : "❌"}',
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
