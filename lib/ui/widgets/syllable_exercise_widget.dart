import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:audioplayers/audioplayers.dart'; // Opsional: Kalau mau ada suara "Ting!"

class SyllableExerciseWidget extends StatefulWidget {
  final Map<String, dynamic> data; // Blok JSON 'syllable_exercise'

  const SyllableExerciseWidget({super.key, required this.data});

  @override
  State<SyllableExerciseWidget> createState() => _SyllableExerciseWidgetState();
}

class _SyllableExerciseWidgetState extends State<SyllableExerciseWidget> {
  // Menyimpan status jawaban untuk setiap soal (id -> jawaban user)
  final Map<int, String> _userAnswers = {};

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = widget.data['items'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            "Latihan: Lengkapi Kata",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ),

        // Render setiap soal dalam bentuk Card
        ...items.map((item) => _buildExerciseCard(item)).toList(),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> item) {
    int id = item['id'];
    String prefix = item['question_prefix'] ?? '';
    String suffix = item['question_suffix'] ?? '';
    String correct = item['correct_answer'] ?? '';
    List<dynamic> options = item['options'] ?? [];
    String? imageUrl = item['image'];

    bool isAnswered = _userAnswers.containsKey(id);
    bool isCorrect = isAnswered && _userAnswers[id] == correct;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAnswered
              ? (isCorrect ? Colors.green : Colors.red)
              : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. GAMBAR SOAL
          if (imageUrl != null) _LocalImageLoader(fileName: imageUrl),

          const SizedBox(height: 16),

          // 2. AREA TEKS (SOAL)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prefix,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                // Slot Jawaban
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(width: 2, color: Colors.teal),
                    ),
                  ),
                  child: Text(
                    isAnswered
                        ? _userAnswers[id]!
                        : "...", // Tampilkan jawaban user
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isAnswered
                          ? (isCorrect ? Colors.green : Colors.red)
                          : Colors.teal,
                    ),
                  ),
                ),
                if (suffix != "__") // Jika suffix bukan placeholder kosong
                  Text(
                    suffix.replaceAll("__", ""), // Bersihkan
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. PILIHAN JAWABAN (TOMBOL)
          Wrap(
            spacing: 16,
            children: options.map<Widget>((opt) {
              String optionText = opt.toString();
              bool isSelected = _userAnswers[id] == optionText;

              return ElevatedButton(
                onPressed: isAnswered
                    ? null
                    : () {
                        setState(() {
                          _userAnswers[id] = optionText;
                        });
                        // Disini nanti bisa tambah logic simpan nilai ke database progress
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? (optionText == correct ? Colors.green : Colors.red)
                      : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.teal,
                  side: BorderSide(color: Colors.teal.shade100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: isSelected ? 0 : 2,
                ),
                child: Text(
                  optionText,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),

          // Feedback Teks
          if (isAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isCorrect ? "Hebat! Benar 🎉" : "Ups, coba lagi ya!",
                style: GoogleFonts.poppins(
                  color: isCorrect ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Helper Kecil untuk Load Gambar di Widget ini ---
class _LocalImageLoader extends StatefulWidget {
  final String fileName;
  const _LocalImageLoader({required this.fileName});

  @override
  State<_LocalImageLoader> createState() => _LocalImageLoaderState();
}

class _LocalImageLoaderState extends State<_LocalImageLoader> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/${widget.fileName}');
    if (await f.exists()) setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null)
      return const SizedBox(
        height: 100,
        child: Center(child: Icon(Icons.image, color: Colors.grey)),
      );
    return SizedBox(
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(_file!, fit: BoxFit.contain),
      ),
    );
  }
}
