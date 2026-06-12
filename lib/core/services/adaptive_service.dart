import 'package:nusalearn/core/database/database_helper.dart';

class AdaptiveService {
  static final AdaptiveService _instance = AdaptiveService._internal();
  factory AdaptiveService() => _instance;
  AdaptiveService._internal();

  /// Level terbuka secara progresif (maks level 5)
  Future<int> calculateStudentLevel(int penggunaId) async {
    final db = await DatabaseHelper.instance.database;

    for (int level = 1; level < 5; level++) {
        bool isMastered = await _isLevelMastered(db, penggunaId, level);
        if (!isMastered) {
            return level; // Berhenti di level pertama yang belum lulus
        }
    }

    return 5; // Jika lulus level 1, 2, 3, 4, maka masuk Level 5
  }

  /// o. FIX: Cek Level dengan menghitung UNIQUE soal_id yang benar
  /// Mencegah duplikasi jawaban yang sama dihitung berkali-kali
  Future<bool> _isLevelMastered(var db, int penggunaId, int level) async {
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT sp.soal_id) as correctcount
      FROM progres_siswa sp
      JOIN soal q ON sp.soal_id = q.id
      JOIN materi m ON q.materi_id = m.id
      WHERE sp.pengguna_id = ? AND sp.benar = 1 AND m.tingkat_kesulitan = ?
      ''',
      [penggunaId, level],
    );

    int correctCount = result.first['correctcount'] as int? ?? 0;

    return correctCount >= 5;
  }
}
