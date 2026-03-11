import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color _kLime = Color(0xFFD2F945);
const Color _kPurple = Color.fromARGB(255, 156, 132, 242);
const Color _kBlack = Color(0xFF000000);
const Color _kWhite = Color(0xFFFFFFFF);
const double _kBorderWidth = 1.5;

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
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isFinished = false;
  int _studentLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() async {
    final db = await DatabaseHelper.instance.database;

    int userId = 0;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) userId = userResult.first['id'] as int;

    int calculatedLevel = await AdaptiveService().calculateStudentLevel(userId);

    final result = await db.query(
      'questions',
      where: 'material_id = ? AND is_deleted = 0 AND difficulty_weight <= ?',
      whereArgs: [widget.materialId, calculatedLevel],
      orderBy: 'difficulty_weight ASC',
    );

    setState(() {
      _questions = result;
      _studentLevel = calculatedLevel;
      _isLoading = false;
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
        }
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
    if (activeLang == 'id') return text;
    return DictionaryService().translate(text);
  }
  // === AKHIR LOGIKA INTI ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          "Kuis",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _kBlack,
          ),
        ),
        centerTitle: true,
        backgroundColor: _kWhite,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kWhite,
              border: Border.all(color: _kBlack, width: 1.5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: _kBlack, offset: Offset(2, 2)),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _kBlack,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(color: _kBlack, height: 2.0), // Hard bottom border
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _kLime,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBlack, width: _kBorderWidth),
              boxShadow: const [
                BoxShadow(color: _kBlack, offset: Offset(2, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, size: 14, color: _kBlack),
                const SizedBox(width: 6),
                Text(
                  "Lv $_studentLevel",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _kBlack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBlack))
          : _questions.isEmpty
          ? _buildEmptyState()
          : _isFinished
          ? _buildResult()
          : _buildQuestionUI(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 80, color: _kBlack),
            const SizedBox(height: 24),
            Text(
              "Belum Ada Soal",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _kBlack,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Soal untuk materi ini masih terkunci.\nNaikkan levelmu dengan menyelesaikan materi lain!",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kBlack.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _kPurple,
                  border: Border.all(color: _kBlack, width: _kBorderWidth),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, color: _kBlack),
                    const SizedBox(width: 8),
                    Text(
                      "Kembali",
                      style: GoogleFonts.plusJakartaSans(
                        color: _kBlack,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
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

    double progress = (_currentIndex) / _questions.length; // Index started at 0

    return Column(
      children: [
        // Custom Progress Indicator Bar
        Container(
          height: 8,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _kWhite,
            border: Border(bottom: BorderSide(color: _kBlack, width: 2.0)),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: const BoxDecoration(
                color: _kLime,
                border: Border(right: BorderSide(color: _kBlack, width: 2.0)),
              ),
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kWhite,
                        border: Border.all(color: _kBlack, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: _kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Text(
                        "Soal ${_currentIndex + 1} / ${_questions.length}",
                        style: GoogleFonts.plusJakartaSans(
                          color: _kBlack,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficultyWeight),
                        border: Border.all(color: _kBlack, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: _kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.whatshot_rounded,
                            size: 14,
                            color: _kBlack,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Bobot $difficultyWeight",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _kBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  questionText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kBlack,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                ...options.map((opt) {
                  String label = _smartTranslate(context, opt['text']);
                  String key = opt['id'];

                  return GestureDetector(
                    onTap: () =>
                        _submitAnswer(key, question['correct_answer_key']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _kWhite,
                        border: Border.all(color: _kBlack, width: 2.0),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _kLime,
                              shape: BoxShape.circle,
                              border: Border.all(color: _kBlack, width: 1.5),
                            ),
                            child: Text(
                              key.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: _kBlack,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kBlack,
                              ),
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
        ),
      ],
    );
  }

  Color _getDifficultyColor(int weight) {
    switch (weight) {
      case 1:
        return const Color(0xFFD2F945); // Lime
      case 2:
        return const Color(0xFFB3E5FF); // Light Blue
      case 3:
        return const Color(0xFFFFDEB3); // Light Orange
      case 4:
        return const Color(0xFFFFB3D9); // Pink
      case 5:
        return const Color(0xFF9C84F2); // Purple
      default:
        return _kWhite;
    }
  }

  Widget _buildResult() {
    double finalScore = (_score / _questions.length) * 100;
    bool isPassed = finalScore >= 70;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isPassed ? _kLime : const Color(0xFFFFDEB3),
              shape: BoxShape.circle,
              border: Border.all(color: _kBlack, width: 2.0),
              boxShadow: const [
                BoxShadow(color: _kBlack, offset: Offset(4, 4)),
              ],
            ),
            child: Icon(
              isPassed
                  ? Icons.emoji_events_rounded
                  : Icons.sentiment_dissatisfied_rounded,
              size: 80,
              color: _kBlack,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isPassed ? "Luar Biasa!" : "Tetap Semangat!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _kBlack,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Nilai Kamu:",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kBlack.withOpacity(0.7),
            ),
          ),
          Text(
            "${finalScore.toInt()}",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: _kPurple,
              shadows: const [Shadow(color: _kBlack, offset: Offset(4, 4))],
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                color: _kWhite,
                border: Border.all(color: _kBlack, width: 2.0),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                ],
              ),
              child: Text(
                "Selesai",
                style: GoogleFonts.plusJakartaSans(
                  color: _kBlack,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
