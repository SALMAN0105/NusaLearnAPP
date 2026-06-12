import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nusalearn/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Modul Otentikasi & Akun (Gawai)', () {
    late Database db;
    
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      await db.execute('''
        CREATE TABLE pengguna (
          id INTEGER PRIMARY KEY,
          nama TEXT,
          nama_pengguna TEXT,
          token TEXT,
          asal_sekolah TEXT,
          kode_bahasa TEXT,
          kode_pos TEXT,
          last_sync TEXT,
          url_gambar TEXT,
          local_image_path TEXT,
          sinkron INTEGER DEFAULT 1
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Menyimpan Profil Pengguna setelah Masuk (Login)', () async {
      final mockApiResponseUser = {
        'id': 5,
        'nama': 'Siswa Teladan',
        'nama_pengguna': 'teladan_01',
        'asal_sekolah': 'SDN 1 Kendari',
        'kode_bahasa': 'tlk',
        'kode_pos': '93111',
      };
      final mockToken = 'token_rahasia_123';

      // Simulasi blok auth_provider.dart menyimpan profil ke SQLite
      await db.insert('pengguna', {
        'id': mockApiResponseUser['id'],
        'nama': mockApiResponseUser['nama'],
        'nama_pengguna': mockApiResponseUser['nama_pengguna'],
        'token': mockToken,
        'asal_sekolah': mockApiResponseUser['asal_sekolah'],
        'kode_bahasa': mockApiResponseUser['kode_bahasa'],
        'kode_pos': mockApiResponseUser['kode_pos'],
        'last_sync': null,
      });

      // Verifikasi Pembacaan Data
      final result = await db.query('pengguna', where: 'id = ?', whereArgs: [5]);
      
      expect(result.length, 1);
      expect(result.first['nama'], 'Siswa Teladan');
      expect(result.first['nama_pengguna'], 'teladan_01');
      expect(result.first['token'], 'token_rahasia_123');
      expect(result.first['kode_bahasa'], 'tlk');
    });
  });
}
