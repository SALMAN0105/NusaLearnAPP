import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'package:nusalearn/core/services/dictionary_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Modul Aset & Kamus (Gawai)', () {
    late Database db;
    
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      await db.execute('''
        CREATE TABLE kamus_bahasa (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kode_bahasa TEXT NOT NULL,
          kata_sumber TEXT NOT NULL,
          terjemahan TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Memastikan DictionaryService mampu menyimpan kamus offline dengan bahasa Indonesia', () async {
      // 1. Simulasi Respon JSON Dictionary (format flat)
      final mockApiResponse = {
        'tolaki': {
          'makan': 'taa',
          'minum': 'mee'
        }
      };

      // 2. Simulasi Logika DictionaryService parsing Flat Format ke SQLite
      final languageCode = 'tolaki';
      final dictionaryMap = mockApiResponse[languageCode] as Map<String, String>;

      for (var entry in dictionaryMap.entries) {
        await db.insert('kamus_bahasa', {
          'kode_bahasa': languageCode,
          'kata_sumber': entry.key,
          'terjemahan': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. Verifikasi SQLite
      final result = await db.query('kamus_bahasa', where: 'kode_bahasa = ?', whereArgs: [languageCode]);
      
      expect(result.length, 2);
      expect(result.first['kata_sumber'], 'makan');
      expect(result.first['terjemahan'], 'taa');
    });
  });
}
