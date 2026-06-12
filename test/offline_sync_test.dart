import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:nusalearn/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Pengujian Skenario Sinkronisasi Berkala (Offline-First)', () {
    late Database db;
    
    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      
      await db.execute('''
        CREATE TABLE progres_siswa (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pengguna_id INTEGER,
          soal_id INTEGER,
          jawaban_siswa TEXT,
          benar INTEGER,
          waktu_detik INTEGER,
          dijawab_pada TEXT,
          tipe_template TEXT DEFAULT 'multiple_choice',
          sinkron INTEGER DEFAULT 0
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('Simulasi aplikasi mengumpulkan data saat offline dan menyusun tumpukan payload sinkronisasi', () async {
      // 1. Aplikasi Gawai Mati Internet: Pengguna menjawab 3 soal
      final waktuOffline = DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
      
      await db.insert('progres_siswa', {
        'pengguna_id': 1,
        'soal_id': 101,
        'jawaban_siswa': '{"selected": "A"}',
        'benar': 1,
        'waktu_detik': 15,
        'dijawab_pada': waktuOffline,
        'tipe_template': 'multiple_choice',
        'sinkron': 0 // Belum terkirim
      });

      await db.insert('progres_siswa', {
        'pengguna_id': 1,
        'soal_id': 102,
        'jawaban_siswa': '{"selected": "C"}',
        'benar': 0,
        'waktu_detik': 20,
        'dijawab_pada': waktuOffline,
        'tipe_template': 'multiple_choice',
        'sinkron': 0
      });

      await db.insert('progres_siswa', {
        'pengguna_id': 1,
        'soal_id': 103,
        'jawaban_siswa': '{"selected": "B"}',
        'benar': 1,
        'waktu_detik': 10,
        'dijawab_pada': waktuOffline,
        'tipe_template': 'multiple_choice',
        'sinkron': 0
      });

      // 2. Internet Nyala: Aplikasi bersiap mengirim tumpukan data ke peladen
      // Verifikasi bahwa ada 3 data yang belum tersinkronisasi
      final unsyncedData = await db.query('progres_siswa', where: 'sinkron = 0');
      
      expect(unsyncedData.length, 3);
      
      // Simulasi transformasi data oleh SyncService menjadi array 'answers'
      List<Map<String, dynamic>> payload = unsyncedData.map((e) {
        return {
          'soal_id': e['soal_id'],
          'data_jawaban': e['jawaban_siswa'], 
          'benar': e['benar'] == 1,
          'waktu_detik': e['waktu_detik'] ?? 0,
          'dijawab_pada': e['dijawab_pada'],
          'tipe_template': e['tipe_template'],
        };
      }).toList();

      expect(payload.length, 3);
      expect(payload[0]['data_jawaban'], '{"selected": "A"}'); // Harus terbaca sebagai 'data_jawaban'
      expect(payload[0]['dijawab_pada'], waktuOffline); // Waktu terkunci sesuai saat offline

      // 3. Simulasi server membalas status success
      // Menandai seluruh row menjadi sinkron = 1
      final batch = db.batch();
      for (var item in unsyncedData) {
        batch.update(
          'progres_siswa',
          {'sinkron': 1},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      await batch.commit();

      // 4. Verifikasi bahwa tidak ada lagi data menumpuk
      final remainingData = await db.query('progres_siswa', where: 'sinkron = 0');
      expect(remainingData.length, 0);

      // Pastikan data masih ada di database lokal sebagai riwayat belajar (sinkron = 1)
      final allData = await db.query('progres_siswa');
      expect(allData.length, 3);
      expect(allData[0]['sinkron'], 1);
    });
  });
}
