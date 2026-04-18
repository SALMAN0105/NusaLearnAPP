import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/widgets/drag_drop_quiz_widget.dart';
import 'package:nusalearn/ui/widgets/matching_game_widget.dart';
import 'package:nusalearn/ui/widgets/fill_blank_quiz_widget.dart';
import 'package:nusalearn/ui/widgets/image_quiz_widget.dart';

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
  // === STATE INTI ===
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  double _score = 0.0;
  bool _isLoading = true;
  bool _isFinished = false;
  int _studentLevel = 1;

  // === STATE GAMIFIKASI & REVIEW ===
  bool _showFeedbackOverlay = false;
  bool _isCurrentCorrect = false;
  bool _isReviewMode = false; // Mode Pembahasan aktif
  Map<int, dynamic> _studentAnswersCache =
      {}; // Menyimpan jawaban siswa untuk Review

  AudioPlayer? _bgmPlayer;
  AudioPlayer? _sfxPlayer;

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
    _playBgmOffline();
  }

  @override
  void dispose() {
    _bgmPlayer?.stop();
    _bgmPlayer?.dispose();
    _sfxPlayer?.stop();
    _sfxPlayer?.dispose();
    super.dispose();
  }

  // --- AUDIO LOGIC ---
  Future<void> _playBgmOffline() async {
    try {
      _bgmPlayer ??= AudioPlayer();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.play(AssetSource('audio/quiz_bgm.wav'));
    } catch (e) {
      debugPrint("Gagal memutar BGM: $e");
    }
  }

  Future<void> _playResultSfxOffline(bool isPassed) async {
    try {
      await _bgmPlayer?.pause();
      _sfxPlayer ??= AudioPlayer();
      String sfxFile = isPassed ? 'audio/success.mp3' : 'audio/fail.mp3';
      await _sfxPlayer!.play(AssetSource(sfxFile));
    } catch (e) {
      debugPrint("Gagal memutar SFX: $e");
    }
  }

  // --- SUBMIT LOGIC (Diperbarui dengan Delay & Animasi) ---
  Future<void> _submitAnswer(String selectedKey, String correctKey) async {
    if (_showFeedbackOverlay || _isReviewMode) return;

    double ratio = (selectedKey == correctKey) ? 1.0 : 0.0;
    _score += ratio;

    _studentAnswersCache[_questions[_currentIndex]['id']] = selectedKey;

    await _saveProgressToDb(selectedKey, ratio, 'multiple_choice');
    await _showFeedbackAndNext(ratio);
  }

  Future<void> _submitMultimediaAnswer(
    String answerJsonPayload,
    double ratio,
  ) async {
    if (_showFeedbackOverlay || _isReviewMode) return;

    _score += ratio; // Injeksi nilai parsial ke skor akhir

    String templateType =
        _questions[_currentIndex]['template_type'] ?? 'multiple_choice';
    _studentAnswersCache[_questions[_currentIndex]['id']] = answerJsonPayload;

    await _saveProgressToDb(answerJsonPayload, ratio, templateType);
    await _showFeedbackAndNext(ratio); // Kirim rasio untuk evaluasi animasi
  }

  Future<void> _saveProgressToDb(
    dynamic answerData,
    double ratio,
    String templateType,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isEmpty) return;

    int userId = userResult.first['id'] as int;
    int questionId = _questions[_currentIndex]['id'];
    String now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Konversi rasio ke boolean database (Jika > 0 berarti dia setidaknya mendapat poin)
    int isCorrectDb = (ratio > 0) ? 1 : 0;

    final existing = await db.query(
      'student_progress',
      where: 'user_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );

    if (existing.isEmpty) {
      await db.insert('student_progress', {
        'user_id': userId,
        'question_id': questionId,
        'student_answer': (answerData is String)
            ? answerData
            : jsonEncode(answerData),
        'is_correct': isCorrectDb,
        'answered_at': now,
        'template_type': templateType,
        'is_synced': 0,
      });
    } else if (isCorrectDb == 1 || existing.first['is_correct'] == 0) {
      await db.update(
        'student_progress',
        {
          'student_answer': (answerData is String)
              ? answerData
              : jsonEncode(answerData),
          'is_correct': isCorrectDb,
          'answered_at': now,
          'is_synced': 0,
        },
        where: 'user_id = ? AND question_id = ?',
        whereArgs: [userId, questionId],
      );
    }
  }

  // --- FEEDBACK ANIMATION SEQUENCER ---
  Future<void> _showFeedbackAndNext(double ratio) async {
    bool isPassedAnimation =
        ratio > 0; // Jika salah semua (0.0) baru animasi fail

    setState(() {
      _isCurrentCorrect = isPassedAnimation;
      _showFeedbackOverlay = true;
    });

    _playResultSfxOffline(isPassedAnimation);

    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    setState(() {
      _showFeedbackOverlay = false;
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _bgmPlayer?.resume();
      } else {
        _isFinished = true;
      }
    });
  }

  String _smartTranslate(BuildContext context, String text) {
    final activeLang = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).activeLanguage;
    if (activeLang == 'id') return text;
    return DictionaryService().translate(text);
  }

  // === UI BUILDERS ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          _isReviewMode ? "Pembahasan Soal" : "Kuis",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _kBlack,
          ),
        ),
        centerTitle: true,
        backgroundColor: _isReviewMode ? const Color(0xFFE0F7FA) : _kWhite,
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
          onPressed: () {
            if (_isReviewMode) {
              // Jika di mode review, kembali ke halaman hasil
              setState(() => _isReviewMode = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(color: _kBlack, height: 2.0),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBlack))
          : _questions.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                if (_isFinished && !_isReviewMode)
                  _buildResult()
                else
                  _buildQuestionUI(),

                // OVERLAY LOTTIE PER SOAL
                if (_showFeedbackOverlay)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    alignment: Alignment.center,
                    child: Lottie.asset(
                      _isCurrentCorrect
                          ? "assets/animasi/succes.json"
                          : "assets/animasi/fail.json",
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                      repeat: false,
                    ),
                  ),
              ],
            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionUI() {
    final question = _questions[_currentIndex];
    String templateType = question['template_type'] ?? 'multiple_choice';
    int difficultyWeight = question['difficulty_weight'] ?? 1;
    double progress = (_currentIndex) / _questions.length;

    // Parsing AI Explanation dari database
    String aiExplanation = "";
    try {
      if (question['question_data'] != null) {
        var parsedData = (question['question_data'] is String)
            ? jsonDecode(question['question_data'])
            : question['question_data'];
        aiExplanation =
            parsedData['explanation'] ?? "Tidak ada pembahasan tersedia.";
      }
    } catch (e) {
      aiExplanation = "Tidak ada pembahasan tersedia.";
    }

    return Column(
      children: [
        // Progress Bar
        Container(
          height: 8,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _kWhite,
            border: Border(bottom: BorderSide(color: _kBlack, width: 2.0)),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _isReviewMode ? 1.0 : progress,
            child: Container(
              decoration: BoxDecoration(
                color: _isReviewMode ? const Color(0xFFB3E5FF) : _kLime,
                border: const Border(
                  right: BorderSide(color: _kBlack, width: 2.0),
                ),
              ),
            ),
          ),
        ),

        // Factory Router & Spacing Fix
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _dispatchQuestionTemplate(
                  question,
                  templateType,
                  difficultyWeight,
                ),

                // --- POST-QUIZ REVIEW BOX ---
                if (_isReviewMode)
                  Container(
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F0FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBlack, width: 2),
                      boxShadow: const [
                        BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: _kPurple),
                            const SizedBox(width: 8),
                            Text(
                              "PEMBAHASAN AI",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: _kPurple,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _smartTranslate(context, aiExplanation),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _kBlack,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Navigasi Mode Review
                if (_isReviewMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kWhite,
                            foregroundColor: _kBlack,
                            side: const BorderSide(color: _kBlack, width: 2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Sebelumnya"),
                        ),
                        ElevatedButton(
                          onPressed: _currentIndex < _questions.length - 1
                              ? () => setState(() => _currentIndex++)
                              : () => setState(() => _isReviewMode = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kLime,
                            foregroundColor: _kBlack,
                            side: const BorderSide(color: _kBlack, width: 2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentIndex < _questions.length - 1
                                ? "Selanjutnya"
                                : "Tutup",
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dispatchQuestionTemplate(
    Map<String, dynamic> question,
    String templateType,
    int difficultyWeight,
  ) {
    // Inject _isReviewMode ke child (Anda perlu menyesuaikan child widgets nanti jika butuh read-only absolute)
    // Untuk saat ini, fungsi pointer disable via IgnorePointer adalah trik paling aman di Flutter.
    Widget childUI;
    switch (templateType) {
      case 'multiple_choice':
        childUI = _buildMultipleChoiceUI(question, difficultyWeight);
        break;
      case 'drag_and_drop':
        childUI = DragDropQuizWidget(
          questionData: question['question_data'] is String
              ? jsonDecode(question['question_data'])
              : (question['question_data'] ?? {}),
          onSubmit: _submitMultimediaAnswer,
        );
        break;
      case 'matching_game':
        childUI = MatchingGameWidget(
          questionData: question['question_data'] is String
              ? jsonDecode(question['question_data'])
              : (question['question_data'] ?? {}),
          onSubmit: _submitMultimediaAnswer,
        );
        break;
      case 'fill_blank':
        childUI = FillBlankQuizWidget(
          questionData: question['question_data'] is String
              ? jsonDecode(question['question_data'])
              : (question['question_data'] ?? {}),
          onSubmit: _submitMultimediaAnswer,
        );
        break;
      case 'image_quiz':
        childUI = ImageQuizWidget(
          questionData: question['question_data'] is String
              ? jsonDecode(question['question_data'])
              : (question['question_data'] ?? {}),
          onSubmit: _submitMultimediaAnswer,
        );
        break;
      default:
        childUI = _buildMultipleChoiceUI(question, difficultyWeight);
    }

    // Jika mode review, matikan semua interaksi ketukan
    if (_isReviewMode) {
      return IgnorePointer(
        ignoring: true, // Nonaktifkan interaksi
        child: Opacity(opacity: 0.85, child: childUI),
      );
    }
    return childUI;
  }

  Widget _buildMultipleChoiceUI(
    Map<String, dynamic> question,
    int difficultyWeight,
  ) {
    String questionText = _smartTranslate(
      context,
      question['question_text_indo'],
    );
    List<dynamic> options = [];
    try {
      options = (question['options_json'] is String)
          ? jsonDecode(question['options_json'])
          : (question['options_json'] ?? []);
    } catch (e) {
      options = [];
    }

    String correctKey = question['correct_answer_key'] ?? '';
    String? userSavedAnswer = _studentAnswersCache[question['id']];

    return Padding(
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
          const SizedBox(
            height: 40,
          ), // PERBAIKAN SPASI 1: Jarak Soal dengan Opsi
          ...options.map((opt) {
            String label = _smartTranslate(context, opt['text']);
            String key = opt['id'];

            // Highlight logic untuk Mode Review
            Color boxBgColor = _kWhite;
            if (_isReviewMode) {
              if (key == correctKey)
                boxBgColor = const Color(0xFFA7F3D0); // Hijau Benar
              else if (key == userSavedAnswer && userSavedAnswer != correctKey)
                boxBgColor = const Color(0xFFFECDD3); // Merah Salah
            }

            return GestureDetector(
              onTap: () => _submitAnswer(key, correctKey),
              child: Container(
                margin: const EdgeInsets.only(
                  bottom: 20,
                ), // PERBAIKAN SPASI 2: Margin Bottom Antar Opsi
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: boxBgColor,
                  border: Border.all(color: _kBlack, width: 2.0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
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
                    if (_isReviewMode && key == correctKey)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                    if (_isReviewMode &&
                        key == userSavedAnswer &&
                        key != correctKey)
                      const Icon(Icons.cancel, color: Colors.red, size: 24),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
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
      child: SingleChildScrollView(
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
              child: SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  isPassed
                      ? "assets/animasi/succes.json"
                      : "assets/animasi/fail.json",
                  fit: BoxFit.contain,
                  repeat: true,
                ),
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

            // TOMBOL REVIEW & SELESAI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 0; // Reset ke soal pertama
                        _isReviewMode = true; // Aktifkan mode pembahasan
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3E5FF),
                        border: Border.all(color: _kBlack, width: 2.0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.find_in_page_rounded,
                            color: _kBlack,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Lihat Pembahasan",
                            style: GoogleFonts.plusJakartaSans(
                              color: _kBlack,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _kWhite,
                        border: Border.all(color: _kBlack, width: 2.0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: _kBlack, offset: Offset(4, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Selesai",
                        style: GoogleFonts.plusJakartaSans(
                          color: _kBlack,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
