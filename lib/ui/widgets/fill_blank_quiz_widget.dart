import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FillBlankQuizWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final Function(String answerJson, double correctnessRatio) onSubmit;

  const FillBlankQuizWidget({
    super.key,
    required this.questionData,
    required this.onSubmit,
  });

  @override
  State<FillBlankQuizWidget> createState() => _FillBlankQuizWidgetState();
}

class _FillBlankQuizWidgetState extends State<FillBlankQuizWidget> {
  String _questionText = "";
  List<dynamic> _blanksData = [];
  List<dynamic> _wordBank = [];

  // State: { blank_id : kata_yang_dipilih }
  final Map<String, String> _userAnswers = {};

  // Penunjuk slot mana yang sedang aktif untuk diisi
  String? _activeBlankId;

  @override
  void initState() {
    super.initState();
    _questionText = widget.questionData['question_text_indo'] ?? "";
    _blanksData = widget.questionData['blanks'] ?? [];
    _wordBank = widget.questionData['word_bank'] ?? [];

    // Inisialisasi slot kosong
    for (var blank in _blanksData) {
      _userAnswers[blank['id']] = "";
    }

    // Set slot pertama sebagai yang aktif secara default
    if (_blanksData.isNotEmpty) {
      _activeBlankId = _blanksData.first['id'];
    }
  }

  void _handleWordTap(String word) {
    if (_activeBlankId == null) return;

    setState(() {
      // Masukkan kata ke slot yang aktif
      _userAnswers[_activeBlankId!] = word;

      // Geser otomatis ke slot kosong berikutnya (jika ada)
      _activeBlankId = null; // Reset dulu
      for (var blank in _blanksData) {
        if (_userAnswers[blank['id']] == "") {
          _activeBlankId = blank['id'];
          break;
        }
      }
    });
  }

  void _handleSlotTap(String blankId) {
    setState(() {
      // Jika slot sudah ada isinya, kosongkan dan kembalikan kata ke word bank
      if (_userAnswers[blankId] != "") {
        _userAnswers[blankId] = "";
      }
      _activeBlankId = blankId;
    });
  }

  void _handleValidation() {
    int correctCount = 0;

    // Hitung blank yang diisi dengan benar
    for (var blank in _blanksData) {
      String expected = blank['correct_answer'].toString().trim().toLowerCase();
      String actual = _userAnswers[blank['id']].toString().trim().toLowerCase();

      if (expected == actual) {
        correctCount++;
      }
    }

    double ratio = _blanksData.isEmpty
        ? 0.0
        : (correctCount / _blanksData.length);

    String answerPayload = jsonEncode({
      'answers': _userAnswers.values.toList(),
    });
    widget.onSubmit(answerPayload, ratio);
  }

  @override
  Widget build(BuildContext context) {
    // Mengecek apakah semua slot sudah terisi
    bool isAllFilled = !_userAnswers.values.any((ans) => ans.isEmpty);

    // Kata-kata yang sudah dipakai agar di-disable di word bank
    List<String> usedWords = _userAnswers.values
        .where((w) => w.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Instruksi
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Lengkapi kalimat di bawah ini!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Area Teks & Slot Rumpang (Inline)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: _buildInlineQuestion(),
          ),

          const SizedBox(height: 32),

          // Bank Kata (Word Bank)
          Text(
            "PILIHAN KATA:",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey[600],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _wordBank.map((word) {
              bool isUsed = usedWords.contains(word);
              return _buildWordChip(word.toString(), isUsed);
            }).toList(),
          ),

          const SizedBox(height: 40),

          // Tombol Konfirmasi
          if (isAllFilled)
            GestureDetector(
              onTap: _handleValidation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2F945), // kLime
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  "KUNCI JAWABAN",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Engine pemecah teks dan penyisip slot secara dinamis
  // Engine pemecah teks menggunakan RichText untuk mencegah layout pecah
  Widget _buildInlineQuestion() {
    List<String> parts = _questionText.split('___');
    List<InlineSpan> spans = [];

    int blankIndex = 0;

    for (int i = 0; i < parts.length; i++) {
      // 1. Masukkan potongan teks
      if (parts[i].isNotEmpty) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.8,
            ),
          ),
        );
      }

      // 2. Sisipkan Slot Rumpang (Inline WidgetSpan)
      if (i < parts.length - 1 && blankIndex < _blanksData.length) {
        String currentBlankId = _blanksData[blankIndex]['id'];
        String currentAnswer = _userAnswers[currentBlankId] ?? "";
        bool isActive = _activeBlankId == currentBlankId;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _handleSlotTap(currentBlankId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(
                  horizontal: 6,
                ), // Margin agar tidak menabrak huruf
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE0F7FA)
                      : (currentAnswer.isNotEmpty
                            ? const Color(0xFFD2F945)
                            : const Color(0xFFF5F3FF)),
                  border: Border.all(
                    color: isActive ? const Color(0xFF7C3AED) : Colors.black,
                    width: isActive ? 2.5 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: Color(0xFF7C3AED),
                            offset: Offset(2, 2),
                          ),
                        ]
                      : const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                ),
                child: Text(
                  currentAnswer.isEmpty ? "      " : currentAnswer,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isActive ? const Color(0xFF7C3AED) : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        );
        blankIndex++;
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildWordChip(String word, bool isUsed) {
    return GestureDetector(
      onTap: isUsed ? null : () => _handleWordTap(word),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUsed ? Colors.grey[200] : Colors.white,
          border: Border.all(
            color: isUsed ? Colors.grey[400]! : Colors.black,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isUsed
              ? []
              : const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
        ),
        child: Text(
          word,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isUsed ? Colors.grey[400] : Colors.black,
            decoration: isUsed ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
