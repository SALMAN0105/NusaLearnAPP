import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart'; // ✅ FIX: Import Provider
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart'; // ✅ FIX: Import AuthProvider
import 'package:nusalearn/ui/widgets/syllable_exercise_widget.dart';

class JsonMaterialRenderer extends StatelessWidget {
  final String contentJson;

  const JsonMaterialRenderer({super.key, required this.contentJson});

  @override
  Widget build(BuildContext context) {
    // ✅ FIX UTAMA: Bungkus dengan Consumer<AuthProvider> agar widget ini
    // di-rebuild otomatis setiap kali authProvider.switchLanguage() dipanggil
    // dan notifyListeners() dieksekusi.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Ambil bahasa yang sedang aktif dari provider
        final String activeLang = authProvider.activeLanguage;

        // Parsing JSON
        List<dynamic> blocks = [];
        try {
          blocks = jsonDecode(contentJson);
        } catch (e) {
          return Center(child: Text("Format materi rusak: $e"));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: blocks.map((block) {
            String type = block['type'] ?? 'paragraph';
            String content = block['content'] ?? '';

            // ✅ FIX: Translate HANYA jika bahasa aktif bukan 'id'
            // Sebelumnya selalu mentranslate tanpa cek bahasa aktif,
            // sehingga bahkan saat 'id' pun tetap masuk fungsi translate
            String translatedContent = (activeLang != 'id')
                ? DictionaryService().translate(content)
                : content;

            switch (type) {
              case 'heading':
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Text(
                    translatedContent,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                );

              case 'paragraph':
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    translatedContent,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                );

              case 'image':
                return _LocalImageRenderer(
                  fileName: block['url'],
                  caption: block['caption'],
                );

              case 'syllable_exercise':
                return SyllableExerciseWidget(data: block);

              default:
                return const SizedBox.shrink();
            }
          }).toList(),
        );
      },
    );
  }
}

// --- Helper Widget: Penampil Gambar Lokal ---
class _LocalImageRenderer extends StatefulWidget {
  final String? fileName;
  final String? caption;

  const _LocalImageRenderer({this.fileName, this.caption});

  @override
  State<_LocalImageRenderer> createState() => _LocalImageRendererState();
}

class _LocalImageRendererState extends State<_LocalImageRenderer> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.fileName == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${widget.fileName}');
    if (await file.exists()) {
      setState(() => _imageFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageFile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_imageFile!, fit: BoxFit.cover),
        ),
        if (widget.caption != null && widget.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              widget.caption!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
