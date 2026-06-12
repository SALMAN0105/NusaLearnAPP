import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Modul Soal & Kuis (Gawai)', () {
    late Database db;
    
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      await db.execute('''
        CREATE TABLE soal (
          id INTEGER PRIMARY KEY,
          materi_id INTEGER,
          teks_soal TEXT,
          question_text_tolaki TEXT,
          opsi_json TEXT,
          kunci_jawaban TEXT,
          bobot_kesulitan INTEGER,
          tipe_template TEXT DEFAULT 'multiple_choice',
          data_soal TEXT,
          aset_diperlukan TEXT,
          diperbarui_pada TEXT,
          is_deleted INTEGER DEFAULT 0
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Sinkronisasi JSON Soal (Template Drag & Drop)', () async {
      // 1. Data Mock Soal dari API Laravel (Menggunakan bahasa Indonesia yang baru)
      final mockApiResponse = {
        'id': 20,
        'materi_id': 10,
        'teks_soal': 'Tarik gambar yang sesuai ke dalam kotak.',
        'kunci_jawaban': 'b',
        'bobot_kesulitan': 3,
        'tipe_template': 'drag_and_drop',
        'data_soal': {"zones": []}, // Berupa Map dari API (akan di-encode ke String)
        'aset_diperlukan': ["gambar_1.png", "gambar_2.png"], // Array dari API
        'diperbarui_pada': '2026-05-29T10:00:00Z',
      };

      // 2. Simulasi logika SyncService memecah data JSON API ke SQLite
      String? dataSoalString = (mockApiResponse['data_soal'] is String) 
          ? mockApiResponse['data_soal'] as String
          : jsonEncode(mockApiResponse['data_soal']);
          
      String? asetDiperlukanString = (mockApiResponse['aset_diperlukan'] is String)
          ? mockApiResponse['aset_diperlukan'] as String
          : jsonEncode(mockApiResponse['aset_diperlukan']);

      await db.insert('soal', {
        'id': mockApiResponse['id'],
        'materi_id': mockApiResponse['materi_id'],
        'teks_soal': mockApiResponse['teks_soal'],
        'question_text_tolaki': null,
        'opsi_json': '[]',
        'kunci_jawaban': mockApiResponse['kunci_jawaban'],
        'bobot_kesulitan': mockApiResponse['bobot_kesulitan'],
        'tipe_template': mockApiResponse['tipe_template'],
        'data_soal': dataSoalString,
        'aset_diperlukan': asetDiperlukanString,
        'diperbarui_pada': mockApiResponse['diperbarui_pada'],
        'is_deleted': 0,
      });

      // 3. Verifikasi Database Lokal
      final result = await db.query('soal', where: 'id = ?', whereArgs: [20]);
      
      expect(result.length, 1);
      expect(result.first['teks_soal'], 'Tarik gambar yang sesuai ke dalam kotak.');
      expect(result.first['tipe_template'], 'drag_and_drop');
      expect(result.first['data_soal'], '{"zones":[]}');
      expect(result.first['aset_diperlukan'], '["gambar_1.png","gambar_2.png"]');
    });
  });
}
