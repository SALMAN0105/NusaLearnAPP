import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nusalearn_final.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
  
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE pengguna ADD COLUMN kelas INTEGER;');
      } catch (e) {
        print("Column kelas mungkin sudah ada: $e");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pengguna (
        id INTEGER PRIMARY KEY,
        nama TEXT,
        nama_pengguna TEXT,
        token TEXT,
        kelas INTEGER,
        asal_sekolah TEXT,
        kode_bahasa TEXT,
        kode_pos TEXT,
        last_sync TEXT,
        url_gambar TEXT,
        local_image_path TEXT,
        sinkron INTEGER DEFAULT 1
      )
    ''');

    // ─── 2. TABEL MATERIALS ───────────────────────────────────────────
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

    // ─── 3. TABEL DICTIONARY ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_indo TEXT,
        word_tolaki TEXT,
        kode_bahasa TEXT
      )
    ''');

    // ─── 4. TABEL QUESTIONS (mencakup kolom upgrade v3) ──────────────
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

    // ─── 5. TABEL STUDENT PROGRESS (mencakup kolom upgrade v3) ───────
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

    // ─── 6. TABEL RECENT MATERIALS ────────────────────────────────────
    await db.execute('''
      CREATE TABLE recent_materials (
        pengguna_id INTEGER,
        materi_id INTEGER,
        last_accessed TEXT,
        PRIMARY KEY (pengguna_id, materi_id)
      )
    ''');

    // ─── 7. TABEL DOWNLOADED ASSETS ──────────────────────────────────
    await db.execute('''
      CREATE TABLE downloaded_assets (
        filename TEXT PRIMARY KEY,
        local_path TEXT,
        download_date TEXT,
        file_size INTEGER
      )
    ''');

    // ─── 8. TABEL AI MODEL REGISTRY (dari upgrade v4) ────────────────
    // Memory-Safe: Hanya menyimpan absolute_path STRING, DILARANG BLOB
    await db.execute('''
      CREATE TABLE ai_model_registry (
        id TEXT PRIMARY KEY,
        model_name TEXT NOT NULL,
        absolute_path TEXT,
        is_ready INTEGER NOT NULL DEFAULT 0,
        checksum TEXT,
        downloaded_at TEXT
      )
    ''');

    // ─── 9. B-TREE INDEX untuk Dictionary (dari upgrade v4) ──────────
    // Mencegah Table Scan O(N) → O(log M)
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_tolaki ON dictionary(word_tolaki)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_indo ON dictionary(word_indo)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dict_lang ON dictionary(kode_bahasa)',
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // UTILITY FUNCTIONS
  // ─────────────────────────────────────────────────────────────────────

  Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nusalearn_final.db');
    await deleteDatabase(path);
    _database = null;
  }

  /// Debug: Cek isi database
  Future<void> printDatabaseStats() async {
    final db = await database;

    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM pengguna'),
    );
    final materialCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM materi'),
    );
    final questionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM soal'),
    );
    final assetCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM downloaded_assets'),
    );

    print("📊 DATABASE STATS:");
    print("   Pengguna: $userCount");
    print("   Materi: $materialCount");
    print("   Soal: $questionCount");
    print("   Downloaded Assets: $assetCount");

    final dir = await getApplicationDocumentsDirectory();
    final files = await Directory(dir.path).list().toList();
    final dictFiles = files.where((f) => f.path.endsWith('.json')).toList();
    print("   Dictionary Files: ${dictFiles.length}");
  }

  /// Cek kesiapan offline
  Future<Map<String, dynamic>> checkOfflineReadiness() async {
    final db = await database;

    final userCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM pengguna'),
        ) ??
        0;
    final materialCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM materi'),
        ) ??
        0;
    final questionCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM soal'),
        ) ??
        0;
    final assetCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM downloaded_assets'),
        ) ??
        0;

    final dir = await getApplicationDocumentsDirectory();
    final files = await Directory(dir.path).list().toList();
    final dictFiles = files.where((f) => f.path.endsWith('.json')).toList();

    final bool isReady =
        userCount > 0 &&
        materialCount > 0 &&
        questionCount > 0 &&
        dictFiles.isNotEmpty;

    return {
      'ready': isReady,
      'pengguna': userCount,
      'materi': materialCount,
      'soal': questionCount,
      'assets': assetCount,
      'dictionaries': dictFiles.length,
    };
  }

  /// Get local path untuk asset — dengan validasi file fisik
  Future<String?> getAssetLocalPath(String filename) async {
    final db = await database;
    final result = await db.query(
      'downloaded_assets',
      where: 'filename = ?',
      whereArgs: [filename],
    );

    if (result.isNotEmpty) {
      final String localPath = result.first['local_path'] as String;
      if (await File(localPath).exists()) {
        return localPath;
      } else {
        // File fisik sudah hilang — hapus record stale dari DB
        await db.delete(
          'downloaded_assets',
          where: 'filename = ?',
          whereArgs: [filename],
        );
      }
    }
    return null;
  }
}
