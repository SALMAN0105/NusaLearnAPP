// lib/screens/ai_chat_sheet.dart
// 🚀 FASE 4: AI Chat Sheet dengan Material Model Integration
// ✅ FIXED: MaterialModel parameter error resolved

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/core/services/voice_service.dart';
import 'package:nusalearn/core/services/ai_coordinator.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/models/material_model.dart';

class AiChatSheet extends StatefulWidget {
  final MaterialModel material; // ✅ Type-safe dengan MaterialModel

  const AiChatSheet({super.key, required this.material});

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AICoordinator _aiCoordinator;

  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': 'Halo! Ada yang bisa dibantu tentang materi ini?'},
  ];

  bool _isListening = false;
  bool _isThinking = false;
  bool _hasText = false;
  String _currentMode = 'offline'; // 'offline' atau 'online'

  @override
  void initState() {
    super.initState();

    // ✅ Initialize AI Coordinator
    _aiCoordinator = AICoordinator();
    _aiCoordinator.init();

    // ✅ Listen to connectivity changes
    _aiCoordinator.onModeChanged = (bool isOnline) {
      if (mounted) {
        setState(() {
          _currentMode = isOnline ? 'online' : 'offline';
        });
      }
    };

    VoiceService().init();
    _textController.addListener(() {
      setState(() => _hasText = _textController.text.trim().isNotEmpty);
    });

    // ✅ Check initial AI readiness
    _checkAIReadiness();
  }

  /// Validasi kesiapan data AI
  void _checkAIReadiness() {
    if (widget.material.aiStatus != 'ready') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messages.add({
            'role': 'ai',
            'text': '''
⚠️ **Data AI Belum Siap**

Materi ini sedang diproses. Beberapa fitur AI mungkin terbatas.
Silakan sync ulang untuk hasil optimal.
''',
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

  // ========================================
  // VOICE INPUT HANDLERS
  // ========================================

  void _startListening() async {
    print("🎤 User pressed mic button");
    setState(() => _isListening = true);

    await VoiceService().startListening(
      onResult: (text) {
        print("📝 Voice result: $text");
        if (mounted) {
          setState(() => _textController.text = text);
        }
      },
    );
  }

  void _stopListeningAndSend() async {
    print("🛑 User released mic button");
    setState(() => _isListening = false);
    await VoiceService().stopListening();

    if (_textController.text.trim().isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
      _processQuery(_textController.text);
    }
  }

  // ========================================
  // TEXT INPUT HANDLER
  // ========================================

  void _handleTextSubmit() {
    if (_textController.text.trim().isEmpty) return;
    _processQuery(_textController.text);
  }

  // ========================================
  // CORE AI PROCESSING (✅ FIXED)
  // ========================================

  Future<void> _processQuery(String text) async {
    // 1. UPDATE UI: Tampilkan Chat User
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _textController.clear();
      _hasText = false;
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      // 2. ✅ VALIDASI: Pastikan material tersedia
      if (widget.material == null) {
        throw Exception("Material tidak tersedia");
      }

      // 3. UX DELAY: Simulasi "Berpikir"
      await Future.delayed(const Duration(milliseconds: 600));

      // 4. ✅ FIX: Panggil AI Coordinator dengan parameter yang benar
      // AICoordinator.processQuery(String input, MaterialModel material)
      String aiResponse = await _aiCoordinator.processQuery(
        text, // Parameter 1: String input (query dari user)
        widget.material, // Parameter 2: MaterialModel (BUKAN String!)
      );

      // 5. FINAL UPDATE: Tampilkan Jawaban AI
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'text': aiResponse});
          _isThinking = false;
        });
        _scrollToBottom();

        // 6. ACCESSIBILITY: Text-to-Speech
        VoiceService().speak(aiResponse);
      }
    } catch (e) {
      // Error Handling
      print("❌ Error Processing Query: $e");
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text':
                '''
❌ **Terjadi Kesalahan**

Maaf, ada kendala saat memproses pertanyaan.
Silakan coba lagi atau hubungi admin.

Detail: ${e.toString()}
''',
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

  // ========================================
  // UI BUILD
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg, isUser);
              },
            ),
          ),
          if (_isThinking) _buildThinkingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ========================================
  // UI COMPONENTS
  // ========================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Title with Mode Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Asisten Belajar",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              _buildModeIndicator(),
            ],
          ),

          // Material Title
          const SizedBox(height: 4),
          Text(
            widget.material.titleIndo,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _currentMode == 'online'
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _currentMode == 'online'
              ? Colors.green.shade300
              : Colors.orange.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _currentMode == 'online' ? Icons.cloud_done : Icons.offline_bolt,
            size: 12,
            color: _currentMode == 'online'
                ? Colors.green.shade700
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            _currentMode == 'online' ? 'Online' : 'Offline',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _currentMode == 'online'
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          msg['text']!,
          style: GoogleFonts.poppins(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Sedang berpikir...",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: _isListening
                      ? "Mendengarkan..."
                      : "Ketik pertanyaan...",
                  hintStyle: TextStyle(
                    color: _isListening ? Colors.red : Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _handleTextSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // TOMBOL GANDA (KIRIM / MIC)
          _hasText
              ? GestureDetector(
                  onTap: _handleTextSubmit,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.teal,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              : GestureDetector(
                  onLongPress: _startListening,
                  onLongPressUp: _stopListeningAndSend,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: _isListening ? Colors.red : Colors.teal,
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
