import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/core/services/voice_service.dart';
import 'package:nusalearn/core/services/ai_coordinator.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/models/material_model.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/sync_service.dart';

// Gunakan konstanta yang sama di file ini jika terpisah
const Color _kLime = Color(0xFFD2F945);
const Color _kPurple = Color.fromARGB(255, 156, 132, 242);
const Color _kBlack = Color(0xFF000000);
const Color _kWhite = Color(0xFFFFFFFF);
const double _kBorderWidth = 1.5;

class AiChatSheet extends StatefulWidget {
  final MaterialModel material;

  const AiChatSheet({super.key, required this.material});

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AICoordinator _aiCoordinator;

  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Halo! Ada yang bisa dibantu tentang materi ini?'},
  ];

  bool _isListening = false;
  bool _isThinking = false;
  bool _hasText = false;
  String _currentMode = 'offline';
  bool _isModelReady = false;
  bool _isDownloadingModel = false;
  double _modelDownloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _aiCoordinator = AICoordinator();
    _aiCoordinator.init();
    _checkModelStatus();

    _aiCoordinator.onModeChanged = (bool isOnline) {
      if (mounted)
        setState(() => _currentMode = isOnline ? 'online' : 'offline');
    };

    VoiceService().init();
    _textController.addListener(() {
      setState(() => _hasText = _textController.text.trim().isNotEmpty);
    });

    _checkAIReadiness();

    //sementara
    Future<void> _debugAiEmbeddings() async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'materi',
        columns: ['id', 'status_ai', 'ai_embeddings'],
        where: 'id = ?',
        whereArgs: [widget.material.id],
      );
      if (rows.isEmpty) {
        print('❌ Material tidak ada di DB');
        return;
      }

      final row = rows.first;
      print('📊 status_ai: ${row['status_ai']}');
      print('📊 ai_embeddings null?: ${row['ai_embeddings'] == null}');
      print(
        '📊 ai_embeddings kosong?: ${(row['ai_embeddings'] as String?)?.isEmpty}',
      );
      print(
        '📊 knowledgeBase.summary: "${widget.material.knowledgeBase.summary}"',
      );
    }
  }

  // GANTI _checkModelStatus() menjadi:
  Future<void> _checkModelStatus() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'ai_model_registry',
      where: 'is_ready = 1',
      limit: 1,
    );

    bool ready = false;
    if (result.isNotEmpty) {
      final path = result.first['absolute_path'] as String?;
      if (path != null && await File(path).exists()) {
        int fileLength = await File(path).length();
        // Validasi ukuran model (GGUF qwen2.5-0.5b adalah ~491MB)
        if (fileLength > 450000000) {
          ready = true;
        } else {
          // File hasil timeout/korup, hapus agar bisa unduh ulang
          print('⚠️ Model korup/tidak lengkap ($fileLength bytes), mereset...');
          await db.update('ai_model_registry', {'is_ready': 0});
          try {
            await File(path).delete();
          } catch (e) {
            print("Gagal menghapus file: $e");
          }
        }
      } else {
        // Registry stale — reset agar user bisa download ulang
        await db.update('ai_model_registry', {'is_ready': 0});
      }
    }

    if (mounted) setState(() => _isModelReady = ready);
  }

  Future<void> _startModelDownload() async {
    setState(() {
      _isDownloadingModel = true;
      _modelDownloadProgress = 0.0;
    });

    // Panggil SyncService dengan callback onProgress
    final success = await SyncService().syncAIModelAndData(
      widget.material.id,
      onProgress: (p) {
        if (mounted) setState(() => _modelDownloadProgress = p);
      },
    );

    if (mounted) {
      setState(() {
        _isDownloadingModel = false;
        if (success) {
          _isModelReady = true;
        } else {
          // Beri notifikasi ke siswa bahwa unduhan terjeda
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Koneksi terganggu. Klik download lagi untuk melanjutkan.",
              ),
            ),
          );
        }
      });
    }
  }

  void _checkAIReadiness() {
    if (widget.material.statusAi != 'ready') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messages.add({
            'role': 'ai',
            'text': '''⚠️ **Data AI Belum Siap**
Materi ini sedang diproses. Beberapa fitur AI mungkin terbatas.
Silakan sync ulang untuk hasil optimal.''',
          });
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    VoiceService().stopSpeaking();
    VoiceService().stopListening();
    _aiCoordinator.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startListening() async {
    setState(() => _isListening = true);
    await VoiceService().startListening(
      onResult: (text) {
        if (mounted) setState(() => _textController.text = text);
      },
    );
  }

  void _stopListeningAndSend() async {
    setState(() => _isListening = false);
    await VoiceService().stopListening();
    if (_textController.text.trim().isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      _processQuery(_textController.text);
    }
  }

  void _handleTextSubmit() {
    if (_textController.text.trim().isEmpty) return;
    _processQuery(_textController.text);
  }

  Future<void> _processQuery(String text) async {
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _textController.clear();
      _hasText = false;
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      String aiResponse = await _aiCoordinator.processQuery(
        text,
        widget.material,
      );

      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': aiResponse});
          _isThinking = false;
        });
        _scrollToBottom();
        VoiceService().speak(aiResponse);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': '''❌ **Terjadi Kesalahan**
Maaf, ada kendala saat memproses pertanyaan.
Detail: ${e.toString()}''',
          });
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  // === AKHIR LOGIKA INTI ===

  @override
  Widget build(BuildContext context) {
    // 🔥 ROOT CAUSE DEFENSE: MediaQuery viewInsets untuk menaikkan UI saat keyboard muncul
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height:
            MediaQuery.of(context).size.height *
            0.85, // Memastikan ruang yang luas
        decoration: BoxDecoration(
          color: _kWhite,
          border: Border.all(color: _kBlack, width: 2.0),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [BoxShadow(color: _kBlack, offset: Offset(0, -4))],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Container(height: 2, color: _kBlack), // Hard divider
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['peran'] == 'user';
                  return _buildMessageBubble(msg, isUser);
                },
              ),
            ),
            if (_isThinking) _buildThinkingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F0FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 6,
            decoration: BoxDecoration(
              color: _kBlack,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          // Baris Status & Tombol Download
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                "Asisten AI",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: _kBlack,
                ),
              ),
              _buildModeIndicator(),

              // 🧠 TOMBOL DOWNLOAD MODEL (OPT-IN DLC)
              if (!_isModelReady)
                GestureDetector(
                  onTap: _isDownloadingModel ? null : _startModelDownload,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isDownloadingModel
                          ? _kWhite
                          : const Color(0xFFB3E5FF),
                      border: Border.all(color: _kBlack, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isDownloadingModel
                          ? []
                          : const [
                              BoxShadow(color: _kBlack, offset: Offset(2, 2)),
                            ],
                    ),
                    child: _isDownloadingModel
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: _modelDownloadProgress > 0
                                  ? _modelDownloadProgress
                                  : null,
                              color: _kBlack,
                            ),
                          )
                        : Text(
                            "Download model Nusa-Edge 0.5B untuk menggunakan fitur tanya Ai offline",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kBlack,
                            ),
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.material.judul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _kBlack.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModeIndicator() {
    final bool isOnline = _currentMode == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? _kLime : const Color(0xFFFFDEB3), // Hijau atau Orange
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBlack, width: _kBorderWidth),
        boxShadow: const [BoxShadow(color: _kBlack, offset: Offset(2, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.cloud_done_rounded : Icons.offline_bolt_rounded,
            size: 12,
            color: _kBlack,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _kBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? _kLime : _kWhite,
          border: Border.all(color: _kBlack, width: _kBorderWidth),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          boxShadow: const [BoxShadow(color: _kBlack, offset: Offset(3, 3))],
        ),
        child: Text(
          msg['text']!,
          style: GoogleFonts.plusJakartaSans(
            color: _kBlack,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kBlack, width: 1.5),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_kBlack),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "AI sedang menganalisis...",
              style: GoogleFonts.plusJakartaSans(
                color: _kBlack.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _kWhite,
        border: Border(top: BorderSide(color: _kBlack, width: 2.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kWhite,
                border: Border.all(color: _kBlack, width: _kBorderWidth),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: _kBlack, offset: Offset(3, 3)),
                ],
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4, // 🔥 TextField bisa membesar
                keyboardType: TextInputType.multiline, // 🔥 Fitur WhatsApp
                textInputAction:
                    TextInputAction.newline, // 🔥 Enter membuat baris baru
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: _kBlack,
                ),
                decoration: InputDecoration(
                  hintText: _isListening
                      ? "Mendengarkan..."
                      : "Ketik pertanyaan...",
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: _isListening ? Colors.red : _kBlack.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // TOMBOL KIRIM / MIC DENGAN NEO-BRUTALISM
          _hasText
              ? GestureDetector(
                  onTap: _handleTextSubmit,
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _kLime,
                      border: Border.all(color: _kBlack, width: _kBorderWidth),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: _kBlack, offset: Offset(3, 3)),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: _kBlack,
                      size: 24,
                    ),
                  ),
                )
              : GestureDetector(
                  onLongPress: _startListening,
                  onLongPressUp: _stopListeningAndSend,
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _isListening ? const Color(0xFFFFB3D9) : _kPurple,
                      border: Border.all(color: _kBlack, width: _kBorderWidth),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: _kBlack, offset: Offset(3, 3)),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _kBlack,
                      size: 26,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
