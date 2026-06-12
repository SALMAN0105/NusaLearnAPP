import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nusalearn/models/material_model.dart';
import 'dart:convert';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Modul Materi Belajar (Gawai)', () {
    late Database db;
    
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      await db.execute('''
        CREATE TABLE materi (
          id INTEGER PRIMARY KEY,
          judul TEXT,
          kategori TEXT,
          url_gambar TEXT,
          local_image_path TEXT,
          tingkat_kesulitan INTEGER,
          kode_bahasa TEXT,
          konten TEXT,
          diperbarui_pada TEXT,
          is_deleted INTEGER DEFAULT 0,
          ai_embeddings TEXT,
          status_ai TEXT DEFAULT 'pending'
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Sinkronisasi JSON dari API dan menyisipkan ke tabel SQLite yang benar', () async {
      // 1. Data Mock yang didapatkan dari API Laravel (Sudah Berbahasa Indonesia)
      final mockApiResponse = {
        'id': 10,
        'judul': 'Pengenalan Huruf',
        'kategori': 'literasi',
        'tingkat_kesulitan': 1,
        'kode_bahasa': 'id',
        'konten': {"blocks": []},
        'diperbarui_pada': '2026-05-29T10:00:00Z',
      };

      // 2. Simulasi logika SyncService memecah data JSON API ke pangkalan data SQLite
      await db.insert('materi', {
        'id': mockApiResponse['id'],
        'judul': mockApiResponse['judul'],
        'kategori': mockApiResponse['kategori'], // Harus kategori, bukan category
        'tingkat_kesulitan': mockApiResponse['tingkat_kesulitan'],
        'kode_bahasa': mockApiResponse['kode_bahasa'],
        'konten': jsonEncode(mockApiResponse['konten']), // Harus konten, bukan content_json
        'diperbarui_pada': mockApiResponse['diperbarui_pada'],
        'is_deleted': 0,
        'status_ai': 'pending',
      });

      // 3. Verifikasi Database Lokal
      final result = await db.query('materi', where: 'id = ?', whereArgs: [10]);
      
      expect(result.length, 1);
      expect(result.first['judul'], 'Pengenalan Huruf');
      expect(result.first['kategori'], 'literasi');
      expect(result.first['konten'], '{"blocks":[]}');
      
      // 4. Verifikasi Cetakan Data (Model Parsing) membaca kolom bahasa Indonesia lokal dengan benar
      final materialModel = MaterialModel.fromMap(result.first);
      expect(materialModel.judul, 'Pengenalan Huruf');
      expect(materialModel.contentJson, '{"blocks":[]}'); // Dart model maps 'konten' to 'contentJson'
      expect(materialModel.tingkatKesulitan, 1);
    });
  });
}
