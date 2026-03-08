// lib/core/services/local_ai_controller_services.dart

import 'package:nusalearn/models/material_model.dart';
import 'tflite_service.dart';
import 'ai_utility_service.dart';
import 'keyword_pivot_engine_services.dart';

class LocalAIControllerService {
  final TFLiteService _tfliteService = TFLiteService();

  Future<String> getResponse(String rawQuery, MaterialModel material) async {
    // ✅ FIX: Gunakan getter knowledgeBase dari MaterialModel
    final kb = material.knowledgeBase;

    // Validasi summary kosong (bukan null check karena KnowledgeBase always exist)
    if (kb.summary.isEmpty && kb.concepts.isEmpty) {
      return "Maaf, data pendukung materi tidak ditemukan atau belum diproses.";
    }

    // 1. Keyword Pivot (Bahasa Daerah -> Indonesia)
    final normalizedQuery = KeywordPivotEngineService.process(
      rawQuery,
      kb.glossary,
    );

    print("🔄 Query transformation: '$rawQuery' → '$normalizedQuery'");

    // 2. ✅ FIX: Deterministic Concept Lookup menggunakan concepts (bukan knowledgeMap)
    final matchedConcept = _findInConcepts(normalizedQuery, kb.concepts);

    if (matchedConcept != null) {
      return _formatResponse(
        content: matchedConcept.explanation,
        source: "Konsep Materi",
        confidence: 1.0,
      );
    }

    // 3. Trigger Ringkasan
    if (_isAskingForSummary(normalizedQuery)) {
      if (kb.summary.isNotEmpty) {
        return _formatResponse(
          content: kb.summary,
          source: "Ringkasan Materi",
          confidence: 0.95,
        );
      }
    }

    // 4. ✅ FIX: Fallback ke TFLite dengan proper error handling
    try {
      final prediction = _tfliteService.findAnswer(material, normalizedQuery);

      // Menggunakan utilitas disclaimer yang sudah ada
      return AIUtilityService.addOfflineDisclaimer(
        prediction['answer'] ?? "Saya tidak menemukan jawaban di materi ini.",
        prediction['confidence'] ?? 0.0,
      );
    } catch (e) {
      print("❌ TFLite Error: $e");
      return _formatResponse(
        content:
            "Maaf, saya tidak dapat menemukan jawaban untuk pertanyaan tersebut dalam materi ini.",
        source: "Pencarian Lokal",
        confidence: 0.0,
      );
    }
  }

  /// ✅ FIX: Mencari dalam List<ConceptItem> bukan KnowledgeMapItem
  ConceptItem? _findInConcepts(String query, List<ConceptItem> concepts) {
    if (concepts.isEmpty) return null;

    final queryLower = query.toLowerCase();

    // Strategy 1: Exact match pada term
    for (var concept in concepts) {
      final termLower = concept.term.toLowerCase();
      if (queryLower.contains(termLower)) {
        print("✅ Found exact concept match: ${concept.term}");
        return concept;
      }
    }

    // Strategy 2: Partial match dengan threshold
    for (var concept in concepts) {
      final termLower = concept.term.toLowerCase();
      final termWords = termLower.split(' ');

      int matchCount = 0;
      for (var word in termWords) {
        if (word.length > 3 && queryLower.contains(word)) {
          matchCount++;
        }
      }

      // Jika 50% atau lebih kata dari concept term ada di query
      if (matchCount >= (termWords.length * 0.5).ceil()) {
        print(
          "✅ Found partial concept match: ${concept.term} (score: $matchCount/${termWords.length})",
        );
        return concept;
      }
    }

    return null;
  }

  /// Check apakah user bertanya tentang ringkasan/overview
  bool _isAskingForSummary(String query) {
    const triggers = [
      'ringkasan',
      'inti materi',
      'kesimpulan',
      'tentang apa',
      'jelaskan isi',
      'rangkuman',
      'garis besar',
      'secara umum',
      'overview',
    ];

    final queryLower = query.toLowerCase();
    return triggers.any((t) => queryLower.contains(t));
  }

  /// Format respons dengan metadata
  String _formatResponse({
    required String content,
    required String source,
    required double confidence,
  }) {
    final confidencePercent = (confidence * 100).toInt();
    String confidenceIcon;

    if (confidence >= 0.8) {
      confidenceIcon = "✅";
    } else if (confidence >= 0.5) {
      confidenceIcon = "⚠️";
    } else {
      confidenceIcon = "ℹ️";
    }

    return """
$content

---
$confidenceIcon **Mode Offline**
📚 Sumber: $source
🎯 Akurasi: $confidencePercent%

_Jawaban berdasarkan data lokal perangkat. Hubungkan ke internet untuk informasi yang lebih lengkap._
""";
  }

  /// Dispose resources
  void dispose() {
    _tfliteService.dispose();
  }
}
