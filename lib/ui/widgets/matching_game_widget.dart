import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchingGameWidget extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final Function(String answerJson, double correctnessRatio) onSubmit;

  const MatchingGameWidget({
    super.key,
    required this.questionData,
    required this.onSubmit,
  });

  @override
  State<MatchingGameWidget> createState() => _MatchingGameWidgetState();
}

class _MatchingGameWidgetState extends State<MatchingGameWidget> {
  List<dynamic> _leftItems = [];
  List<dynamic> _rightItems = [];
  List<dynamic> _correctPairs = [];

  // State Management
  String? _selectedLeftId;
  String? _selectedRightId;

  // Menyimpan pasangan yang sudah terbentuk: { left_id: right_id }
  final Map<String, String> _formedPairs = {};

  // Palet warna untuk menandai pasangan yang sudah terbentuk
  final List<Color> _pairColors = [
    const Color(0xFFD2F945), // Lime
    const Color(0xFFFFB3D9), // Pink
    const Color(0xFFB3E5FF), // Blue
    const Color(0xFFFFDEB3), // Orange
    const Color(0xFFE0F7FA), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final pairs = widget.questionData['pairs'] as List? ?? [];
    _correctPairs = widget.questionData['correct_pairs'] as List? ?? [];

    for (var pair in pairs) {
      if (pair['left'] != null) _leftItems.add(pair['left']);
      if (pair['right'] != null) _rightItems.add(pair['right']);
    }

    // Acak urutan agar tidak sejajar langsung (O(N) Complexity)
    _leftItems.shuffle();
    _rightItems.shuffle();
  }

  void _handleTapLeft(String id) {
    if (_formedPairs.containsKey(id)) return; // Sudah dipasangkan
    setState(() {
      _selectedLeftId = (_selectedLeftId == id) ? null : id;
      _checkPairFormation();
    });
  }

  void _handleTapRight(String id) {
    if (_formedPairs.containsValue(id)) return; // Sudah dipasangkan
    setState(() {
      _selectedRightId = (_selectedRightId == id) ? null : id;
      _checkPairFormation();
    });
  }

  void _checkPairFormation() {
    if (_selectedLeftId != null && _selectedRightId != null) {
      // Bentuk pasangan
      _formedPairs[_selectedLeftId!] = _selectedRightId!;
      // Reset seleksi
      _selectedLeftId = null;
      _selectedRightId = null;
    }
  }

  void _undoPair(String leftId) {
    setState(() {
      _formedPairs.remove(leftId);
    });
  }

  void _handleValidation() {
    int correctCount = 0;

    // Hitung berapa pasangan yang benar
    for (var correctPair in _correctPairs) {
      String expectedLeft = correctPair['left'];
      String expectedRight = correctPair['right'];

      if (_formedPairs[expectedLeft] == expectedRight) {
        correctCount++;
      }
    }

    double ratio = _correctPairs.isEmpty
        ? 0.0
        : (correctCount / _correctPairs.length);

    List<Map<String, String>> answersPayload = _formedPairs.entries.map((e) {
      return {"left": e.key, "right": e.value};
    }).toList();

    widget.onSubmit(jsonEncode({'pairs': answersPayload}), ratio);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllPaired = _formedPairs.length == _leftItems.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruksi Pertanyaan
          Text(
            widget.questionData['question_text_indo'] ??
                'Pasangkan kotak kiri dan kanan.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ketuk item di kiri, lalu ketuk pasangannya di kanan.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Area Permainan (Dua Kolom)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KOLOM KIRI
              Expanded(
                child: Column(
                  children: _leftItems
                      .map((item) => _buildGameCard(item, true))
                      .toList(),
                ),
              ),
              const SizedBox(width: 16),
              // KOLOM KANAN
              Expanded(
                child: Column(
                  children: _rightItems
                      .map((item) => _buildGameCard(item, false))
                      .toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Tombol Konfirmasi (Muncul hanya jika semua sudah dipasangkan)
          if (isAllPaired)
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

  Widget _buildGameCard(Map<String, dynamic> item, bool isLeft) {
    String id = item['id'];
    String text = item['text'];

    // Status Cek
    bool isSelected = isLeft
        ? (_selectedLeftId == id)
        : (_selectedRightId == id);
    bool isPaired = isLeft
        ? _formedPairs.containsKey(id)
        : _formedPairs.containsValue(id);

    // Cari tahu warna pasangan jika sudah dipasangkan
    Color cardColor = Colors.white;
    if (isSelected) {
      cardColor = const Color(
        0xFFE0F7FA,
      ); // Highlight saat dipilih (Cyan terang)
    } else if (isPaired) {
      // Cari index pasangan untuk menetapkan warna yang sama
      int pairIndex = -1;
      if (isLeft) {
        pairIndex = _formedPairs.keys.toList().indexOf(id);
      } else {
        pairIndex = _formedPairs.values.toList().indexOf(id);
      }
      cardColor = _pairColors[pairIndex % _pairColors.length];
    }

    return GestureDetector(
      onTap: isPaired
          ? () {
              // Jika di-tap saat sudah dipasangkan, Undo (Lepas ikatan)
              if (isLeft) {
                _undoPair(id);
              } else {
                String? keyToRemove;
                _formedPairs.forEach((k, v) {
                  if (v == id) keyToRemove = k;
                });
                if (keyToRemove != null) _undoPair(keyToRemove!);
              }
            }
          : () => isLeft ? _handleTapLeft(id) : _handleTapRight(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.black,
            width: isSelected ? 3.0 : 2.0,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              offset: isSelected ? const Offset(2, 2) : const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
