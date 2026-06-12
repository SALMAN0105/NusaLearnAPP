import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

class DragDropQuizWidget extends StatefulWidget {
  final Map<String, dynamic> dataSoal;
  final Function(String answerJson, double correctnessRatio) onSubmit;

  const DragDropQuizWidget({
    super.key,
    required this.dataSoal,
    required this.onSubmit,
  });

  @override
  State<DragDropQuizWidget> createState() => _DragDropQuizWidgetState();
}

class _DragDropQuizWidgetState extends State<DragDropQuizWidget> {
  // State untuk menyimpan posisi item: { itemId: zoneId }
  final Map<String, String> _placedItems = {};
  final Map<String, File> _localImages = {};

  List<dynamic> _items = [];
  List<dynamic> _zones = [];
  Map<String, dynamic> _correctMapping = {};

  @override
  void initState() {
    super.initState();
    _items = widget.dataSoal['items'] ?? [];
    _zones = widget.dataSoal['zones'] ?? [];
    _correctMapping = widget.dataSoal['correct_mapping'] ?? {};
    _loadImages();
  }

  Future<void> _loadImages() async {
    final dir = await getApplicationDocumentsDirectory();
    for (var item in _items) {
      if (item['image_asset'] != null) {
        final file = File('${dir.path}/${item['image_asset']}');
        if (await file.exists()) {
          _localImages[item['id']] = file;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _handleValidation() {
    int correctCount = 0;

    // Hitung berapa item yang benar
    for (var item in _items) {
      String itemId = item['id'];
      if (_placedItems[itemId] == _correctMapping[itemId]) {
        correctCount++;
      }
    }

    // Cegah Division by Zero, hitung rasio desimal
    double ratio = _items.isEmpty ? 0.0 : (correctCount / _items.length);

    String answerPayload = jsonEncode({'mapping': _placedItems});
    widget.onSubmit(answerPayload, ratio); // Kirim rasio, bukan boolean
  }

  @override
  Widget build(BuildContext context) {
    // Filter item yang belum diletakkan di zona mana pun
    final availableItems = _items
        .where((item) => !_placedItems.containsKey(item['id']))
        .toList();
    final bool isAllPlaced = availableItems.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruksi Pertanyaan
          Text(
            widget.dataSoal['teks_soal'] ??
                'Pasangkan item ke zona yang tepat.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Render Zona Drop (DragTarget)
          ..._zones.map((zone) => _buildDropZone(zone)).toList(),

          const SizedBox(height: 32),

          // Render Item yang bisa di-drag (Draggable)
          if (availableItems.isNotEmpty) ...[
            Text(
              "PILIHAN ITEM:",
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
              children: availableItems
                  .map((item) => _buildDraggableItem(item))
                  .toList(),
            ),
          ],

          const SizedBox(height: 40),

          // Tombol Konfirmasi (Muncul hanya jika semua item sudah diletakkan)
          if (isAllPlaced)
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

  // WIDGET: Zona Penempatan (Target)
  Widget _buildDropZone(Map<String, dynamic> zone) {
    String zoneId = zone['id'];

    // Cari item apa saja yang diletakkan user di zona ini
    List<dynamic> itemsInThisZone = _items
        .where((item) => _placedItems[item['id']] == zoneId)
        .toList();

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        setState(() {
          _placedItems[details.data] = zoneId; // Pindahkan item ke zona ini
        });
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovered = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered
                ? const Color(0xFFEDE9FE)
                : const Color(0xFFF5F3FF),
            border: Border.all(
              color: isHovered ? const Color(0xFF7C3AED) : Colors.black,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone['label'] is Map ? (zone['label']['label'] ?? 'Zona') : (zone['label'] ?? 'Zona'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // Tempat merender item yang sudah di-drop
              if (itemsInThisZone.isEmpty)
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withOpacity(0.1),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.download_rounded, color: Colors.black26),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: itemsInThisZone
                      .map((item) => _buildPlacedItem(item))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET: Item yang Sedang Di-drag
  Widget _buildDraggableItem(Map<String, dynamic> item) {
    Widget itemUI = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
      ),
      child: item['text'] != null 
        ? Text(
            item['text'],
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          )
        : (item['image_asset'] != null 
            ? (_localImages[item['id']] != null 
                ? Image.file(_localImages[item['id']]!, height: 60, width: 60, fit: BoxFit.cover)
                : const SizedBox(height: 60, width: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
            : const Text("Kosong")),
    );

    return Draggable<String>(
      data: item['id'],
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.05, child: itemUI),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: itemUI),
      child: itemUI,
    );
  }

  // WIDGET: Item yang Sudah Berada di dalam Zona
  Widget _buildPlacedItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {
        // Klik untuk mengembalikan item ke daftar pilihan
        setState(() {
          _placedItems.remove(item['id']);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDEB3), // Oranye pastel
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item['text'] != null
                ? Text(
                    item['text'],
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  )
                : (_localImages[item['id']] != null
                    ? Image.file(_localImages[item['id']]!, height: 30, width: 30, fit: BoxFit.cover)
                    : const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))),
            const SizedBox(width: 8),
            const Icon(Icons.close_rounded, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
