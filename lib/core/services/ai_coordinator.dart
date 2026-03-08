// lib/core/services/ai_coordinator.dart
// 🚀 FASE 3 & 4: AI Coordinator dengan Real-time Mode Switching

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nusalearn/core/services/ai_utility_service.dart';
import 'package:nusalearn/core/services/gemini_service.dart';
import 'package:nusalearn/core/services/tflite_service.dart';
import 'package:nusalearn/models/material_model.dart';

/// AI Coordinator: Mengatur transisi seamless antara Cloud (Gemini) dan Local (TFLite)
class AICoordinator {
  // ========================================
  // SINGLETON PATTERN
  // ========================================

  static final AICoordinator _instance = AICoordinator._internal();
  factory AICoordinator() => _instance;
  AICoordinator._internal();

  // ========================================
  // SERVICES & DEPENDENCIES
  // ========================================

  final GeminiService _geminiService = GeminiService();
  final TFLiteService _tfliteService = TFLiteService();
  final Connectivity _connectivity = Connectivity();

  // ========================================
  // STATE MANAGEMENT
  // ========================================

  bool _isOnline = false;
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Callback untuk notifikasi perubahan mode
  Function(bool isOnline)? onModeChanged;

  // ========================================
  // INITIALIZATION
  // ========================================

  /// Initialize coordinator dan mulai monitoring konektivitas
  Future<void> init() async {
    if (_isInitialized) return;

    print("🔧 Initializing AI Coordinator...");

    try {
      // 1. Load TFLite model
      await _tfliteService.loadModel();

      // 2. Check initial connectivity
      await _checkConnectivity();

      // 3. Start listening to connectivity changes
      _startConnectivityMonitoring();

      _isInitialized = true;
      print("✅ AI Coordinator Ready");
      print("   Mode: ${_isOnline ? 'Online (Gemini)' : 'Offline (TFLite)'}");
    } catch (e) {
      print("❌ AI Coordinator Init Error: $e");
      _isInitialized = false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _tfliteService.dispose();
    _isInitialized = false;
    print("🔴 AI Coordinator Disposed");
  }

  // ========================================
  // CONNECTIVITY MONITORING
  // ========================================

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;

      // ✅ FIX: Handle List<ConnectivityResult>
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;

      if (wasOnline != _isOnline) {
        print("🔄 Connectivity Changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}");
        onModeChanged?.call(_isOnline);
      }
    } catch (e) {
      print("⚠️ Connectivity Check Error: $e");
      _isOnline = false;
    }
  }

  /// Start real-time monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;

        // ✅ FIX: Handle List<ConnectivityResult>
        _isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;

        if (wasOnline != _isOnline) {
          print("🔄 Mode Switched: ${_isOnline ? 'ONLINE' : 'OFFLINE'}");
          onModeChanged?.call(_isOnline);
        }
      },
      onError: (error) {
        print("❌ Connectivity Stream Error: $error");
        _isOnline = false;
        onModeChanged?.call(false);
      },
    );
  }

  // ========================================
  // MAIN PROCESSING LOGIC
  // ========================================

  /// Entry point utama: routing otomatis berdasarkan konektivitas
  Future<String> processQuery(String input, MaterialModel material) async {
    if (!_isInitialized) {
      await init();
    }

    // Re-check connectivity sebelum proses (untuk memastikan status terkini)
    await _checkConnectivity();

    print("\n========================================");
    print("🤖 AI Processing Request");
    print("   Query: $input");
    print("   Mode: ${_isOnline ? 'ONLINE (Gemini)' : 'OFFLINE (TFLite)'}");
    print("   Material: ${material.titleIndo}");
    print("========================================\n");

    try {
      // Route ke processor yang sesuai
      if (_isOnline) {
        return await _processOnline(input, material);
      } else {
        return await _processOffline(input, material);
      }
    } catch (e) {
      print("❌ Processing Error: $e");

      // Fallback strategy: jika online gagal, coba offline
      if (_isOnline) {
        print("🔄 Online failed, falling back to offline...");
        return await _processOffline(input, material);
      }

      return _buildErrorMessage(e);
    }
  }

  // ========================================
  // OFFLINE PROCESSING (TFLite)
  // ========================================

  /// Enhanced offline processing dengan metadata validation
  Future<String> _processOffline(String input, MaterialModel material) async {
    // ===== PRE-VALIDATION =====

    // 1. Check AI Status
    if (material.aiStatus != 'ready' &&
        (material.aiEmbeddings == null || material.aiEmbeddings!.isEmpty)) {
      return """
⚠️ **Data Materi Belum Siap**

Materi ini belum selesai diproses oleh sistem. Silakan:
1. Pastikan terhubung ke internet
2. Kembali ke menu utama
3. Lakukan sync ulang

Setelah itu, AI offline akan berfungsi dengan baik.
""";
    }

    // 2. Apply Keyword Pivot (Bahasa Daerah → Indonesia)
    String pivotedInput = AIUtilityService.applyKeywordPivot(
      input,
      material.knowledgeBase.glossary,
    );

    print("🔄 Keyword Pivot: '$input' → '$pivotedInput'");

    // ===== INFERENCE =====

    // 3. Use Enhanced TFLite Service
    Map<String, dynamic> result = _tfliteService.findAnswer(
      material,
      pivotedInput,
    );

    String rawResponse = result['answer'] ?? 'Tidak ada jawaban';
    double confidence = result['confidence'] ?? 0.0;
    String source = result['source'] ?? 'unknown';

    // ===== POST-PROCESSING =====

    // 4. Log untuk debugging
    print("📊 AI Response: confidence=$confidence, source=$source");

    // 5. Add enhanced disclaimer dengan confidence level
    String finalResponse = AIUtilityService.addOfflineDisclaimer(
      rawResponse,
      confidence,
    );

    // 6. Add source metadata untuk transparency
    finalResponse += "\n\n_Sumber: $source _";

    return finalResponse;
  }

  // ========================================
  // ONLINE PROCESSING (Gemini)
  // ========================================

  /// Enhanced online processing dengan Knowledge Map grounding
  Future<String> _processOnline(String input, MaterialModel material) async {
    final knowledgeBase = material.knowledgeBase;

    // ✅ ENHANCED: Gunakan structured context dari utility
    final context = AIUtilityService.buildStructuredContext(knowledgeBase);

    final prompt =
        """
$context

=== PERTANYAAN SISWA ===
$input

=== INSTRUKSI ===
Kamu adalah asisten pembelajaran yang membantu siswa memahami materi "${material.titleIndo}".

ATURAN PENTING:
1. **HANYA gunakan informasi dari SUMMARY dan CONCEPTS di atas**
2. **JANGAN** menambahkan informasi di luar konteks yang diberikan
3. Jika pertanyaan di luar cakupan materi, katakan dengan jelas
4. Gunakan bahasa yang mudah dipahami siswa
5. Berikan contoh HANYA dari konteks materi yang tersedia
6. Jika ada istilah dalam TERMS, sebutkan padanannya dalam bahasa lokal

**VALIDASI**: Sebelum menjawab, pastikan jawaban Anda bisa dikutip langsung dari SUMMARY atau CONCEPTS di atas.

Berikan jawaban yang jelas, singkat, dan edukatif.
""";

    try {
      String response = await _geminiService.generateContent(prompt);

      // ✅ ENHANCED: Add metadata tentang source
      return """
🤖 **AI Assistant (Online Mode)**

$response

---
📚 Materi: ${material.titleIndo}
🌐 Model: Gemini Pro (Cloud)
✅ Grounded dengan Knowledge Map
""";
    } catch (e) {
      print("❌ Gemini Error: $e");
      // Fallback ke offline dengan notifikasi
      String offlineResult = await _processOffline(input, material);
      return """
⚠️ **Mode Online Gagal - Beralih ke Mode Offline**

$offlineResult
""";
    }
  }

  // ========================================
  // ERROR HANDLING
  // ========================================

  String _buildErrorMessage(dynamic error) {
    return """
❌ **Terjadi Kesalahan**

Maaf, ada kendala saat memproses pertanyaan Anda.

Detail Error: ${error.toString()}

Saran:
1. Periksa koneksi internet Anda
2. Restart aplikasi
3. Sync ulang data materi
4. Hubungi admin jika masalah berlanjut
""";
  }

  // ========================================
  // UTILITY METHODS
  // ========================================

  /// Get current mode status
  bool get isOnline => _isOnline;

  /// Get current mode as string
  String get currentMode => _isOnline ? 'online' : 'offline';

  /// Manual connectivity refresh
  Future<void> refreshConnectivity() async {
    await _checkConnectivity();
  }

  /// Debug method untuk testing
  Future<void> debugAIResponse(MaterialModel material, String question) async {
    print("\n========================================");
    print("🔍 AI DEBUG MODE");
    print("========================================");

    print("\n1. Material Info:");
    print("   - Title: ${material.titleIndo}");
    print("   - AI Status: ${material.aiStatus}");
    print("   - Has Embeddings: ${material.aiEmbeddings != null}");
    print("   - Concepts Count: ${material.knowledgeBase.concepts.length}");
    print("   - Glossary Count: ${material.knowledgeBase.glossary.length}");

    print("\n2. Question Analysis:");
    print("   - Original: $question");

    String pivoted = AIUtilityService.applyKeywordPivot(
      question,
      material.knowledgeBase.glossary,
    );
    print("   - After Pivot: $pivoted");

    bool isRelevant = AIUtilityService.isTopicallyRelevant(
      question,
      material.knowledgeBase,
    );
    print("   - Is Relevant: $isRelevant");

    print("\n3. Concept Matching:");
    var matches = AIUtilityService.findRelevantConcepts(
      question,
      material.knowledgeBase,
    );
    for (var match in matches.take(3)) {
      print(
        "   - ${match.concept.term}: score=${match.score}, type=${match.matchType}",
      );
    }

    print("\n4. Connectivity Status:");
    print("   - Is Online: $_isOnline");
    print("   - Current Mode: $currentMode");

    print("\n5. Running Inference...");
    String result = await processQuery(question, material);

    print("   - Final Answer Length: ${result.length} chars");
    print(
      "   - Preview: ${result.substring(0, result.length > 100 ? 100 : result.length)}...",
    );

    print("\n========================================\n");
  }
}
