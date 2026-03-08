import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Pastikan: flutter pub add intl
import 'package:sqflite/sqflite.dart'; // Wajib untuk ConflictAlgorithm
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/ui/widgets/json_material_renderer.dart';
import 'package:nusalearn/ui/widgets/ai_chat_sheet.dart';
import 'package:nusalearn/models/material_model.dart';

class MateriDetailScreen extends StatefulWidget {
  final Map<String, dynamic> material;

  const MateriDetailScreen({super.key, required this.material});

  @override
  State<MateriDetailScreen> createState() => _MateriDetailScreenState();
}

class _MateriDetailScreenState extends State<MateriDetailScreen> {
  @override
  void initState() {
    super.initState();
    _recordHistory();
  }

  // Logic mencatat "Terakhir Dibaca"
  Future<void> _recordHistory() async {
    final db = await DatabaseHelper.instance.database;

    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) {
      int userId = userResult.first['id'] as int;
      String now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Gunakan ConflictAlgorithm.replace agar waktu terupdate jika sudah ada
      await db.insert('recent_materials', {
        'user_id': userId,
        'material_id': widget.material['id'],
        'last_accessed': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print("✅ History tercatat: Materi ID ${widget.material['id']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? localPath = widget.material['local_image_path'];
    final bool hasCover = localPath != null && File(localPath).existsSync();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.teal,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.material['title_indo'],
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    const Shadow(blurRadius: 10, color: Colors.black45),
                  ],
                ),
              ),
              background: hasCover
                  ? Image.file(File(localPath), fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal, Colors.tealAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
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
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        "LEVEL ${widget.material['level_difficulty']}",
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.material['title_indo'],
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 10),
                  JsonMaterialRenderer(
                    contentJson: widget.material['content_json'] ?? '[]',
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                AiChatSheet(material: MaterialModel.fromMap(widget.material)),
          );
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
        label: Text(
          "Tanya AI",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade100),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: color.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
