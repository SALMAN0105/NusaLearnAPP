import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/core/services/adaptive_service.dart'; // ✅ TAMBAH
import 'package:nusalearn/logic/providers/auth_provider.dart';

class QuizScreen extends StatefulWidget {
  final int materialId;
  final String materialTitle;

  const QuizScreen({
    super.key,
    required this.materialId,
    required this.materialTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isFinished = false;
  int _studentLevel = 1; // ✅ TAMBAH: Level siswa

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // ✅ FIX: Load soal berdasarkan level siswa
  void _loadQuestions() async {
    final db = await DatabaseHelper.instance.database;

    // 1. Hitung level siswa
    int userId = 0;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) userId = userResult.first['id'] as int;

    int calculatedLevel = await AdaptiveService().calculateStudentLevel(userId);

    // 2. ✅ QUERY BARU: Filter soal berdasarkan difficulty_weight <= level siswa
    final result = await db.query(
      'questions',
      where: 'material_id = ? AND is_deleted = 0 AND difficulty_weight <= ?',
      whereArgs: [widget.materialId, calculatedLevel],
      orderBy: 'difficulty_weight ASC', // Urutkan dari mudah ke sulit
    );

    setState(() {
      _questions = result;
      _studentLevel = calculatedLevel;
      _isLoading = false;
    });

    // ✅ DEBUG: Print untuk cek
    print("🎯 Level Siswa: $calculatedLevel");
    print("📝 Total Soal Tersedia: ${result.length}");
    result.forEach((q) {
      print("   - Soal ID ${q['id']}: Bobot ${q['difficulty_weight']}");
    });
  }

  Future<void> _submitAnswer(String selectedKey, String correctKey) async {
    bool isCorrect = selectedKey == correctKey;
    if (isCorrect) {
      _score++;
    }

    final db = await DatabaseHelper.instance.database;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) {
      int userId = userResult.first['id'] as int;
      int questionId = _questions[_currentIndex]['id'];
      String now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Cek apakah soal ini sudah pernah dijawab BENAR?
      final existing = await db.query(
        'student_progress',
        where: 'user_id = ? AND question_id = ? AND is_correct = 1',
        whereArgs: [userId, questionId],
      );

      if (existing.isEmpty) {
        final existingWrong = await db.query(
          'student_progress',
          where: 'user_id = ? AND question_id = ?',
          whereArgs: [userId, questionId],
        );

        if (existingWrong.isEmpty) {
          await db.insert('student_progress', {
            'user_id': userId,
            'question_id': questionId,
            'student_answer': selectedKey,
            'is_correct': isCorrect ? 1 : 0,
            'answered_at': now,
            'is_synced': 0,
          });

          print("✅ INSERT: Soal ID $questionId (Pertama kali)");
        } else if (isCorrect) {
          await db.update(
            'student_progress',
            {
              'student_answer': selectedKey,
              'is_correct': 1,
              'answered_at': now,
              'is_synced': 0,
            },
            where: 'user_id = ? AND question_id = ?',
            whereArgs: [userId, questionId],
          );
          print("✅ UPDATE: Soal ID $questionId (Salah → Benar)");
        }
      } else {
        print("⏭️ SKIP: Soal ID $questionId sudah dijawab BENAR sebelumnya");
      }
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _isFinished = true);
    }
  }

  String _smartTranslate(BuildContext context, String text) {
    final activeLang = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).activeLanguage;

    if (activeLang == 'id') {
      return text;
    }
    return DictionaryService().translate(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Kuis: ${widget.materialTitle}",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // ✅ TAMBAH: Indikator Level di AppBar
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.school, size: 16, color: Colors.green.shade800),
                const SizedBox(width: 4),
                Text(
                  "Lv $_studentLevel",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
          ? _buildEmptyState()
          : _isFinished
          ? _buildResult()
          : _buildQuestionUI(),
    );
  }

  // ✅ TAMBAH: State kosong ketika tidak ada soal untuk level siswa
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Belum Ada Soal Untukmu",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Soal untuk materi ini masih terkunci.\nNaikkan levelmu dengan menyelesaikan soal lain!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: Text(
                "Kembali",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionUI() {
    final question = _questions[_currentIndex];

    String questionText = _smartTranslate(
      context,
      question['question_text_indo'],
    );

    // ✅ TAMBAH: Tampilkan bobot soal
    int difficultyWeight = question['difficulty_weight'] ?? 1;

    List<dynamic> options = [];
    try {
      if (question['options_json'] is String) {
        options = [...jsonDecode(question['options_json'])];
      } else {
        options = question['options_json'];
      }
    } catch (e) {
      print("Error parse options: $e");
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey.shade200,
              color: Colors.teal,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Soal ${_currentIndex + 1}/${_questions.length}",
                  style: GoogleFonts.poppins(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // ✅ TAMBAH: Badge Kesulitan
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(difficultyWeight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.whatshot, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        "Bobot $difficultyWeight",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              questionText,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),

            ...options.map((opt) {
              String label = _smartTranslate(context, opt['text']);
              String key = opt['id'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _submitAnswer(key, question['correct_answer_key']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.teal.shade50,
                        child: Text(
                          key.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ✅ Helper: Warna badge kesulitan
  Color _getDifficultyColor(int weight) {
    switch (weight) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildResult() {
    double finalScore = (_score / _questions.length) * 100;
    bool isPassed = finalScore >= 70;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPassed
                ? Icons.emoji_events_rounded
                : Icons.sentiment_dissatisfied_rounded,
            size: 100,
            color: isPassed ? Colors.orange : Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            isPassed ? "Luar Biasa!" : "Tetap Semangat!",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Nilai Kamu: ${finalScore.toInt()}",
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              "Selesai",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
