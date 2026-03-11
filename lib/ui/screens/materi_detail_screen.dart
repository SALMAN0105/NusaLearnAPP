import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/ui/widgets/json_material_renderer.dart';
import 'package:nusalearn/ui/widgets/ai_chat_sheet.dart';
import 'package:nusalearn/models/material_model.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 1.5;

class MateriDetailScreen extends StatefulWidget {
  final Map<String, dynamic> material;

  const MateriDetailScreen({super.key, required this.material});

  @override
  State<MateriDetailScreen> createState() => _MateriDetailScreenState();
}

class _MateriDetailScreenState extends State<MateriDetailScreen> {
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  @override
  void initState() {
    super.initState();
    _recordHistory();
  }

  Future<void> _recordHistory() async {
    final db = await DatabaseHelper.instance.database;

    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) {
      int userId = userResult.first['id'] as int;
      String now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      await db.insert('recent_materials', {
        'user_id': userId,
        'material_id': widget.material['id'],
        'last_accessed': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print("✅ History tercatat: Materi ID ${widget.material['id']}");
    }
  }
  // === AKHIR LOGIKA INTI ===

  @override
  Widget build(BuildContext context) {
    final String? localPath = widget.material['local_image_path'];
    final bool hasCover = localPath != null && File(localPath).existsSync();

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F0FF,
      ), // Latar belakang abu-ungu Neo-Brutalis
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: kPurple,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kWhite,
                  border: Border.all(color: kBlack, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: kBlack, offset: Offset(2, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: kBlack,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.material['title_indo'],
                style: GoogleFonts.plusJakartaSans(
                  color: kWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  shadows: const [
                    Shadow(blurRadius: 0, color: kBlack, offset: Offset(2, 2)),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kBlack, width: 2.0)),
                ),
                child: hasCover
                    ? Image.file(File(localPath), fit: BoxFit.cover)
                    : Container(
                        color: kPurple,
                        child: const Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 80,
                            color: Colors.white30,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: kWhite,
                border: Border(top: BorderSide(color: kBlack, width: 2.0)),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(0),
                ), // Tajam untuk Neo-Brutalis
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildBadge(
                        (widget.material['category'] ?? '-')
                            .toString()
                            .toUpperCase(),
                        const Color(0xFFFFDEB3), // Warna orange pastel
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        "LEVEL ${widget.material['level_difficulty']}",
                        const Color(0xFFB3E5FF), // Warna biru pastel
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.material['title_indo'],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 2, color: kBlack, width: double.infinity),
                  const SizedBox(height: 16),
                  JsonMaterialRenderer(
                    contentJson: widget.material['content_json'] ?? '[]',
                  ),
                  const SizedBox(height: 100), // Extra space untuk FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: kLime,
          border: Border.all(color: kBlack, width: kBorderWidth),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled:
                  true, // WAJIB untuk menyesuaikan ukuran layar & keyboard
              backgroundColor: Colors.transparent,
              builder: (context) =>
                  AiChatSheet(material: MaterialModel.fromMap(widget.material)),
            );
          },
          icon: const Icon(Icons.smart_toy_rounded, color: kBlack),
          label: Text(
            "Tanya AI",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              color: kBlack,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBlack, width: 1.5),
        boxShadow: const [BoxShadow(color: kBlack, offset: Offset(2, 2))],
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: kBlack,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
