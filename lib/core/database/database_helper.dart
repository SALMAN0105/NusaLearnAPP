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
      version:
          1, // Reset ke versi 1 karena fresh install — semua sudah di _createDB
      onCreate: _createDB,
    );
  }

  /// ✅ MASTER CREATE: Semua tabel dari v1-v4 digabung di sini.
  /// Tidak ada _onUpgrade karena ini fresh install dengan versi tunggal.
  /// LARANGAN: Jangan pernah rename kolom/field yang sudah ada.
  Future _createDB(Database db, int version) async {
    // ─── 1. TABEL USERS (mencakup kolom upgrade v2) ───────────────────
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

    // ─── 2. TABEL MATERIALS ───────────────────────────────────────────
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

    // ─── 3. TABEL DICTIONARY ──────────────────────────────────────────
    await db.execute('''
      CREATE TABLE dictionary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_indo TEXT,
        word_tolaki TEXT,
        language_code TEXT
      )
    ''');

    // ─── 4. TABEL QUESTIONS (mencakup kolom upgrade v3) ──────────────
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY,
        material_id INTEGER,
        question_text_indo TEXT,
        question_text_tolaki TEXT,
        options_json TEXT,
        correct_answer_key TEXT,
        difficulty_weight INTEGER,
        template_type TEXT DEFAULT 'multiple_choice',
        question_data TEXT,
        assets_required TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // ─── 5. TABEL STUDENT PROGRESS (mencakup kolom upgrade v3) ───────
    await db.execute('''
      CREATE TABLE student_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        question_id INTEGER,
        student_answer TEXT,
        is_correct INTEGER,
        time_spent_seconds INTEGER,
        answered_at TEXT,
        template_type TEXT DEFAULT 'multiple_choice',
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // ─── 6. TABEL RECENT MATERIALS ────────────────────────────────────
    await db.execute('''
      CREATE TABLE recent_materials (
        user_id INTEGER,
        material_id INTEGER,
        last_accessed TEXT,
        PRIMARY KEY (user_id, material_id)
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
      'CREATE INDEX IF NOT EXISTS idx_dict_lang ON dictionary(language_code)',
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
      'users': userCount,
      'materials': materialCount,
      'questions': questionCount,
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
