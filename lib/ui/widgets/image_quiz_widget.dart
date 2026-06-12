import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class ImageQuizWidget extends StatefulWidget {
  final Map<String, dynamic> dataSoal;
  final Function(String answerJson, double correctnessRatio) onSubmit;

  const ImageQuizWidget({
    super.key,
    required this.dataSoal,
    required this.onSubmit,
  });

  @override
  State<ImageQuizWidget> createState() => _ImageQuizWidgetState();
}

class _ImageQuizWidgetState extends State<ImageQuizWidget> {
  String? _selectedAreaId;
  String _mainImageFilename = "";
  List<dynamic> _tapAreas = [];
  String _correctAreaId = "";

  File? _imageFile;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _mainImageFilename = widget.dataSoal['main_image'] ?? "";

    // Support kedua format: 'tap_areas' (format lama) dan 'options' (format baru dari DB)
    final rawAreas = widget.dataSoal['tap_areas'];
    final rawOptions = widget.dataSoal['options'];

    if (rawAreas != null && (rawAreas as List).isNotEmpty) {
      _tapAreas = rawAreas;
    } else if (rawOptions != null && (rawOptions as List).isNotEmpty) {
      // Konversi format 'options' ke format 'tap_areas' yang diharapkan widget
      _tapAreas = (rawOptions as List).map((opt) {
        return {
          'id': opt['id'] ?? '',
          'label': opt['text'] ?? opt['label'] ?? 'Pilihan',
        };
      }).toList();
    }

    // Ambil jawaban benar dari berbagai kemungkinan kunci
    _correctAreaId =
        widget.dataSoal['correct_area'] ??
        widget.dataSoal['correct_answer'] ??
        widget.dataSoal['kunci_jawaban'] ??
        "";

    // Fallback: cari dari is_correct di dalam options
    if (_correctAreaId.isEmpty && rawOptions != null) {
      for (var opt in rawOptions) {
        if (opt['is_correct'] == true) {
          _correctAreaId = opt['id'] ?? '';
          break;
        }
      }
    }

    _loadImageLocally();
  }

  // Resolusi I/O File Secara Asinkron (Mencegah UI Freeze)
  Future<void> _loadImageLocally() async {
    if (_mainImageFilename.isEmpty) {
      setState(() => _isLoadingImage = false);
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_mainImageFilename');

      if (await file.exists()) {
        setState(() {
          _imageFile = file;
          _isLoadingImage = false;
        });
      } else {
        setState(() => _isLoadingImage = false);
      }
    } catch (e) {
      debugPrint("Gagal memuat gambar lokal: $e");
      setState(() => _isLoadingImage = false);
    }
  }

  void _handleSelection(String areaId) {
    setState(() {
      _selectedAreaId = areaId;
    });
  }

  void _handleValidation() {
    if (_selectedAreaId == null) return;

    bool benar = (_selectedAreaId == _correctAreaId);

    String answerPayload = jsonEncode({'selected': _selectedAreaId});
    // Karena ini cuma klik 1 area, nilainya tetap absolut 1.0 atau 0.0
    widget.onSubmit(answerPayload, benar ? 1.0 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Teks Pertanyaan
          Text(
            widget.dataSoal['teks_soal'] ??
                'Perhatikan gambar berikut dan pilih jawaban yang tepat.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // 2. Kontainer Gambar Utama (Neo-Brutalism)
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(4, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _isLoadingImage
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: Colors.black.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Gambar Hilang",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // 3. Label Pilihan
          Text(
            "PILIH BAGIAN YANG TEPAT:",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.grey[600],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          // 4. Daftar Pilihan Area
          ..._tapAreas.map((area) {
            String areaId = area['id'];
            String label = area['label'] ?? 'Area';
            bool isSelected = _selectedAreaId == areaId;

            return GestureDetector(
              onTap: () => _handleSelection(areaId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFD2F945)
                      : Colors.white, // kLime jika terpilih
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                        ]
                      : const [
                          BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // 5. Tombol Konfirmasi
          if (_selectedAreaId != null)
            GestureDetector(
              onTap: _handleValidation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFC299FF), // Purple kustom
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
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
