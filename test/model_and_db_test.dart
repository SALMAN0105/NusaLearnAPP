import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nusalearn/models/material_model.dart';
import 'package:nusalearn/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    // Inisialisasi sqflite ffi untuk pengujian di desktop/CLI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Model Data (Cetakan Data)', () {
    test('MaterialModel.fromMap membaca kunci bahasa Indonesia', () {
      final jsonPayload = {
        'id': 1,
        'judul': 'Belajar Sejarah',
        'url_gambar': 'sejarah.png',
        'tingkat_kesulitan': 2,
        'kode_bahasa': 'id',
        'konten': '{"text": "Halo"}',
        'ai_embeddings': '{"tags": ["sejarah"]}',
        'status_ai': 'completed'
      };

      final model = MaterialModel.fromMap(jsonPayload);

      expect(model.id, 1);
      expect(model.judul, 'Belajar Sejarah');
      expect(model.urlGambar, 'sejarah.png');
      expect(model.tingkatKesulitan, 2);
      expect(model.kodeBahasa, 'id');
      expect(model.contentJson, '{"text": "Halo"}'); // variabel dalam Dart tetap contentJson namun dipetakan dari 'konten'
      expect(model.statusAi, 'completed');
    });
  });

  group('Pengujian Pangkalan Data Lokal (SQLite)', () {
    late Database db;
    
    setUp(() async {
      // Buat database di memori untuk setiap pengujian
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      // Jalankan skema pembuatan tabel dari DatabaseHelper
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

    test('Menyisipkan dan membaca data materi dengan skema bahasa Indonesia', () async {
      // Sisipkan data
      await db.insert('materi', {
        'id': 101,
        'judul': 'Matematika Dasar',
        'kategori': 'numerasi',
        'tingkat_kesulitan': 1,
        'kode_bahasa': 'id',
        'konten': '{}',
      });

      // Baca data
      final result = await db.query('materi', where: 'id = ?', whereArgs: [101]);

      expect(result.length, 1);
      expect(result.first['judul'], 'Matematika Dasar');
      expect(result.first['kategori'], 'numerasi');
    });
  });
}
