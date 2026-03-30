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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Tambah kolom baru secara aman (Backward Compatible)
          await db.execute('ALTER TABLE users ADD COLUMN image_url TEXT');
          await db.execute(
            'ALTER TABLE users ADD COLUMN local_image_path TEXT',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN is_synced INTEGER DEFAULT 1',
          );
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Tabel User (Sudah oke, tapi mari rapikan ke snake_case agar konsisten kedepannya)
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      name TEXT,
      username TEXT,
      token TEXT,
      school_origin TEXT,
      language_code TEXT,
      postal_code TEXT,
      last_sync TEXT,
      image_url TEXT,
      local_image_path TEXT,
      is_synced INTEGER DEFAULT 1
    )
  ''');

    // 2. Tabel Materials (INI PENYEBAB ERROR local_image_path)
    await db.execute('''
    CREATE TABLE materials (
      id INTEGER PRIMARY KEY,
      title_indo TEXT,
      category TEXT,
      image_url TEXT,
      local_image_path TEXT,
      level_difficulty INTEGER,
      language_code TEXT,
      content_json TEXT,
      updated_at TEXT,
      is_deleted INTEGER DEFAULT 0,
      ai_embeddings TEXT, 
      ai_status TEXT DEFAULT 'pending'
    )
  ''');

    // 3. Tabel Dictionary
    await db.execute('''
    CREATE TABLE dictionary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_indo TEXT,
      word_tolaki TEXT,
      language_code TEXT
    )
  ''');
    // Index opsional
    // await db.execute('CREATE INDEX idx_dictionary_word ON dictionary(word_indo, language_code)');

    // 4. Tabel Questions (INI PENYEBAB ERROR question_text_indo)
    await db.execute('''
    CREATE TABLE questions (
      id INTEGER PRIMARY KEY,
      material_id INTEGER,
      question_text_indo TEXT,
      question_text_tolaki TEXT,
      options_json TEXT,
      correct_answer_key TEXT,
      difficulty_weight INTEGER,
      updated_at TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''');

    // 5. Tabel Progress
    await db.execute('''
    CREATE TABLE student_progress (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      question_id INTEGER,
      student_answer TEXT,
      is_correct INTEGER,
      time_spent_seconds INTEGER,
      answered_at TEXT,
      is_synced INTEGER DEFAULT 0
    )
  ''');

    // 6. Tabel Recent Materials
    await db.execute('''
    CREATE TABLE recent_materials (
      user_id INTEGER,
      material_id INTEGER,
      last_accessed TEXT,
      PRIMARY KEY (user_id, material_id)
    )
  ''');

    // 7. Tabel Downloaded Assets
    await db.execute('''
    CREATE TABLE downloaded_assets (
      filename TEXT PRIMARY KEY,
      local_path TEXT,
      download_date TEXT,
      file_size INTEGER
    )
  ''');
  }

  Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nusalearn_final.db');
    await deleteDatabase(path);
    _database = null;
  }

  /// ✅ FUNGSI DEBUG: Cek isi database
  Future<void> printDatabaseStats() async {
    final db = await database;

    final userCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    final materialCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM materials'),
    );
    final questionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM questions'),
    );
    final assetCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM downloaded_assets'),
    );

    print("📊 DATABASE STATS:");
    print("   Users: $userCount");
    print("   Materials: $materialCount");
    print("   Questions: $questionCount");
    print("   Downloaded Assets: $assetCount");

    // Cek file kamus
    final dir = await getApplicationDocumentsDirectory();
    final files = await Directory(dir.path).list().toList();
    final dictFiles = files.where((f) => f.path.endsWith('.json')).toList();
    print("   Dictionary Files: ${dictFiles.length}");
  }

  /// ✅ FUNGSI BARU: Cek kesiapan offline
  Future<Map<String, dynamic>> checkOfflineReadiness() async {
    final db = await database;

    // Count data
    final userCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;

    final materialCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM materials'),
        ) ??
        0;

    final questionCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM questions'),
        ) ??
        0;

    final assetCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM downloaded_assets'),
        ) ??
        0;

    // Cek kamus
    final dir = await getApplicationDocumentsDirectory();
    final files = await Directory(dir.path).list().toList();
    final dictFiles = files.where((f) => f.path.endsWith('.json')).toList();

    bool isReady =
        userCount > 0 &&
        materialCount > 0 &&
        questionCount > 0 &&
        dictFiles.isNotEmpty;

    return {
      'ready': isReady,
      'users': userCount,
      'materials': materialCount,
      'questions': questionCount,
      'assets': assetCount,
      'dictionaries': dictFiles.length,
    };
  }

  /// ✅ FUNGSI BARU: Get local path untuk asset
  /// ✅ FUNGSI BARU: Get local path untuk asset
  Future<String?> getAssetLocalPath(String filename) async {
    final db = await database;
    final result = await db.query(
      'downloaded_assets',
      where: 'filename = ?',
      whereArgs: [filename],
    );

    if (result.isNotEmpty) {
      // ✅ FIX: Gunakan ['local_path'], BUKAN ['localpath']
      String localPath = result.first['local_path'] as String;

      if (await File(localPath).exists()) {
        return localPath;
      } else {
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
