import 'package:nusalearn/core/database/database_helper.dart';

class AdaptiveService {
  static final AdaptiveService _instance = AdaptiveService._internal();
  factory AdaptiveService() => _instance;
  AdaptiveService._internal();

  /// ✅ FIX: Menghitung Level Siswa dengan Cache
  /// Level 2 terbuka jika Level 1 lulus (5 soal benar).
  /// Level 3 terbuka jika Level 2 lulus (5 soal benar).
  Future<int> calculateStudentLevel(int userId) async {
    final db = await DatabaseHelper.instance.database;

    // Cek Level 1
    bool level1Mastered = await _isLevelMastered(db, userId, 1);

    if (level1Mastered) {
      // Jika Level 1 Lulus, Cek Level 2
      bool level2Mastered = await _isLevelMastered(db, userId, 2);
      if (level2Mastered) {
        return 3; // Master Level 2, masuk Level 3
      }
      return 2; // Master Level 1, masuk Level 2
    }

    return 1; // Default: Masih di Level 1
  }

  /// ✅ FIX: Cek Level dengan menghitung UNIQUE question_id yang benar
  /// Mencegah duplikasi jawaban yang sama dihitung berkali-kali
  Future<bool> _isLevelMastered(var db, int userId, int level) async {
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT sp.question_id) as correctcount
      FROM student_progress sp
      JOIN questions q ON sp.question_id = q.id
      JOIN materials m ON q.material_id = m.id
      WHERE sp.user_id = ? AND sp.is_correct = 1 AND m.level_difficulty = ?
      ''',
      [userId, level],
    );

    int correctCount = result.first['correctcount'] as int? ?? 0;

    return correctCount >= 5;
  }
}
