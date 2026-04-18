// lib/core/services/ai_coordinator.dart

import 'dart:async';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nusalearn/core/services/ai_utility_service.dart';
import 'package:nusalearn/core/services/openai_service.dart';
import 'package:nusalearn/core/services/local_ai_controller_services.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/models/material_model.dart';

/// Ukuran cache maksimum (entry). Tiap entry ~2-5KB → 50 entry ≈ 100-250KB RAM
const int _kMaxCacheSize = 50;

/// AI Coordinator: Routing otomatis Online ↔ Offline dengan Smart Cache
class AICoordinator {
  // ═══ SINGLETON ═══════════════════════════════════════════════════════════
  static final AICoordinator _instance = AICoordinator._internal();
  factory AICoordinator() => _instance;
  AICoordinator._internal();

  // ═══ DEPENDENCIES ════════════════════════════════════════════════════════
  final OpenAIService _openAI = OpenAIService();
  final LocalAIControllerService _localAI = LocalAIControllerService();
  final Connectivity _connectivity = Connectivity();

  // ═══ STATE ═══════════════════════════════════════════════════════════════
  bool _isOnline = false;
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// LRU Cache: key = "$materialId:$queryHash" → cached answer
  final LinkedHashMap<String, String> _responseCache = LinkedHashMap();

  /// Callback mode change
  Function(bool isOnline)? onModeChanged;

  // ═══ INIT & DISPOSE ══════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;
    print('🔧 AI Coordinator v2 initializing...');
    try {
      await _checkConnectivity();
      _startConnectivityMonitoring();
      _isInitialized = true;
      print(
        '✅ AI Coordinator Ready — Mode: ${_isOnline ? "Online" : "Offline"}',
      );
    } catch (e) {
      print('❌ Init error: $e');
      _isInitialized = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _localAI.dispose();
    _responseCache.clear();
    _isInitialized = false;
    print('🔴 AI Coordinator Disposed');
  }

  // ═══ CONNECTIVITY ════════════════════════════════════════════════════════

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
      if (wasOnline != _isOnline) {
        print('🔄 Mode: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        onModeChanged?.call(_isOnline);
      }
    } catch (_) {
      _isOnline = false;
    }
  }

  void _startConnectivityMonitoring() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) {
        final wasOnline = _isOnline;
        _isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;
        if (wasOnline != _isOnline) {
          print('🔄 Switched: ${_isOnline ? "ONLINE" : "OFFLINE"}');
          onModeChanged?.call(_isOnline);
          if (_isOnline)
            _responseCache.clear(); // Invalidate cache saat kembali online
        }
      },
      onError: (_) {
        _isOnline = false;
        onModeChanged?.call(false);
      },
    );
  }

  // ═══ MAIN ENTRY POINT ════════════════════════════════════════════════════

  Future<String> processQuery(String input, MaterialModel material) async {
    if (!_isInitialized) await init();
    await _checkConnectivity();

    print('\n══════════════════════════════════════');
    print(
      '🤖 Query: "${input.length > 60 ? input.substring(0, 60) + "..." : input}"',
    );
    print(
      '   Mode: ${_isOnline ? "ONLINE" : "OFFLINE"} | Schema: ${material.aiSchemaVersion}',
    );
    print('══════════════════════════════════════\n');

    // ── Cache check ──────────────────────────────────────────────────────
    if (!_isOnline) {
      final cacheKey = _buildCacheKey(material.id, input);
      if (_responseCache.containsKey(cacheKey)) {
        print('⚡ Cache hit!');
        return _responseCache[cacheKey]!;
      }
    }

    try {
      String response;
      if (_isOnline) {
        response = await _processOnline(input, material);
      } else {
        response = await _processOffline(input, material);
        _cacheResponse(material.id, input, response);
      }
      return response;
    } catch (e) {
      print('❌ Error: $e');
      if (_isOnline) {
        try {
          final offline = await _processOffline(input, material);
          return '⚠️ **Online gagal → Beralih Offline**\n\n$offline';
        } catch (_) {}
      }
      return _buildErrorMessage(e);
    }
  }

  // ═══ ONLINE (OpenAI) ═════════════════════════════════════════════════════

  Future<String> _processOnline(String input, MaterialModel material) async {
    final kb = material.knowledgeBase;
    final meta = material.aiMetadata;
    final context = AIUtilityService.buildStructuredContext(kb);

    // Cek apakah input dalam bahasa daerah
    final normalizedInput = _normalizeForOnline(input, kb, meta);

    final prompt =
        '''
Kamu adalah asisten pembelajaran cerdas untuk aplikasi NusaLearn.
Selalu jawab dalam Bahasa Indonesia yang ramah dan mudah dipahami siswa.

=== KONTEKS MATERI: "${material.titleIndo}" ===
$context

=== PERTANYAAN SISWA ===
$normalizedInput

=== INSTRUKSI ===
1. Jawab HANYA berdasarkan konteks materi di atas.
2. Jika pertanyaan di luar materi, nyatakan dengan sopan.
3. Maksimal 6 paragraf, gunakan contoh jika relevan.
4. Jika ada istilah lokal di TERMS, sebutkan padanannya.
''';

    final response = await _openAI.generateContent(prompt);

    if (response.startsWith('Error:')) {
      print('⚠️ OpenAI error → fallback offline');
      final offline = await _processOffline(input, material);
      return '⚠️ **Mode Online Tidak Tersedia**\n\nBeralih ke mode offline:\n\n$offline';
    }

    return '''🤖 **Asisten AI (Online)**

$response

---
📚 ${material.titleIndo} · 🌐 Powered by OpenAI · ✅ Berdasarkan Materi''';
  }

  String _normalizeForOnline(
    String input,
    KnowledgeBase kb,
    Map<String, dynamic> meta,
  ) {
    // Pivot bahasa daerah → Indonesia sebelum kirim ke cloud
    String normalized = input;

    // Dari glossary materi
    for (final item in kb.glossary) {
      if (item.termLocal.isNotEmpty) {
        normalized = normalized.replaceAll(
          RegExp(
            r'\b' + RegExp.escape(item.termLocal) + r'\b',
            caseSensitive: false,
          ),
          item.term,
        );
      }
    }

    // Dari DictionaryService
    if (DictionaryService.instance.isLoaded) {
      normalized = DictionaryService.instance.translateToIndo(normalized);
    }

    return normalized;
  }

  // ═══ OFFLINE (Local RAG v2) ═══════════════════════════════════════════════

  Future<String> _processOffline(String input, MaterialModel material) async {
    final kb = material.knowledgeBase;

    if (kb.summary.isEmpty && kb.concepts.isEmpty) {
      return '''⚠️ **Data Materi Belum Siap**

Materi belum selesai diproses oleh AI. Silakan:
1. Hubungkan ke internet
2. Lakukan sync ulang dari menu utama
3. Tunggu status materi berubah menjadi "Ready"''';
    }

    return await _localAI.getResponse(input, material);
  }

  // ═══ CACHE ════════════════════════════════════════════════════════════════

  String _buildCacheKey(int materialId, String query) {
    // Hash sederhana: 8 karakter cukup untuk cache key
    final hash = query.toLowerCase().trim().hashCode.toRadixString(36);
    return '$materialId:$hash';
  }

  void _cacheResponse(int materialId, String query, String response) {
    if (response.contains('Tidak Ditemukan') ||
        response.contains('Belum Siap')) {
      return; // Jangan cache respons negatif
    }

    final key = _buildCacheKey(materialId, query);

    // LRU eviction: hapus entry terlama jika sudah penuh
    if (_responseCache.length >= _kMaxCacheSize) {
      _responseCache.remove(_responseCache.keys.first);
    }

    _responseCache[key] = response;
    print(
      '💾 Cached response (total: ${_responseCache.length}/$_kMaxCacheSize)',
    );
  }

  void clearCache() {
    _responseCache.clear();
    print('🗑️ Response cache cleared');
  }

  // ═══ ERROR ════════════════════════════════════════════════════════════════

  String _buildErrorMessage(dynamic error) {
    return '''❌ **Terjadi Kesalahan**

Maaf, ada kendala saat memproses pertanyaan.

Saran:
• Periksa koneksi internet
• Restart aplikasi
• Sync ulang data materi
• Hubungi admin jika berlanjut

_Detail: ${error.toString()}_''';
  }

  // ═══ GETTERS ══════════════════════════════════════════════════════════════

  bool get isOnline => _isOnline;
  String get currentMode => _isOnline ? 'online' : 'offline';
  int get cacheSize => _responseCache.length;

  Future<void> refreshConnectivity() async => await _checkConnectivity();
}
