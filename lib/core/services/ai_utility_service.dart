// lib/core/services/ai_utility_service_enhanced.dart

import '/models/material_model.dart';
import 'dart:math';

/// Enhanced AI Utility Service dengan fitur:
/// 1. Smart Keyword Pivot (word boundary aware)
/// 2. Knowledge Map Indexing
/// 3. Concept-First Retrieval
/// 4. Confidence Scoring
class AIUtilityService {
  // ========================================
  // 1. ENHANCED KEYWORD PIVOT
  // ========================================

  /// Melakukan substitusi kata dengan word boundary detection
  /// dan preserve original casing
  static String applyKeywordPivot(String input, List<GlossaryItem> glossary) {
    if (glossary.isEmpty) return input;

    String processedText = input;

    // Sort glossary by term length (longest first) untuk avoid partial replacement
    List<GlossaryItem> sortedGlossary = List.from(glossary);
    sortedGlossary.sort(
      (a, b) => b.termLocal.length.compareTo(a.termLocal.length),
    );

    for (var item in sortedGlossary) {
      String termIndo = item.term;
      String termLocal = item.termLocal;

      if (termLocal.isEmpty || termIndo.isEmpty) continue;

      // ✅ FIX: Gunakan word boundary regex
      // \b ensures we match whole words only
      RegExp regex = RegExp(
        r'\b' + RegExp.escape(termLocal) + r'\b',
        caseSensitive: false,
      );

      // Replace dengan preserve first-letter casing
      processedText = processedText.replaceAllMapped(regex, (match) {
        String matched = match.group(0)!;

        // Preserve casing: jika input Title Case → output juga Title Case
        if (matched[0] == matched[0].toUpperCase()) {
          return termIndo[0].toUpperCase() +
              termIndo.substring(1).toLowerCase();
        }
        return termIndo.toLowerCase();
      });
    }

    return processedText;
  }

  // ========================================
  // 2. KNOWLEDGE MAP INDEXING
  // ========================================

  /// Membuat index konsep untuk fast lookup
  static Map<String, ConceptItem> buildConceptIndex(
    KnowledgeBase knowledgeBase,
  ) {
    Map<String, ConceptItem> index = {};

    for (var concept in knowledgeBase.concepts) {
      // Index by term (lowercase)
      String key = concept.term.toLowerCase();
      index[key] = concept;

      // Also index by keywords in term (untuk partial match)
      List<String> words = concept.term.toLowerCase().split(' ');
      for (var word in words) {
        if (word.length > 3) {
          // Skip short words
          index[word] = concept;
        }
      }
    }

    return index;
  }

  /// Membuat glossary lookup map untuk fast translation
  static Map<String, GlossaryItem> buildGlossaryIndex(
    KnowledgeBase knowledgeBase,
  ) {
    Map<String, GlossaryItem> index = {};

    for (var item in knowledgeBase.glossary) {
      // Index by Indonesian term
      index[item.term.toLowerCase()] = item;
      // Index by local term
      if (item.termLocal.isNotEmpty) {
        index[item.termLocal.toLowerCase()] = item;
      }
    }

    return index;
  }

  // ========================================
  // 3. CONCEPT-FIRST RETRIEVAL
  // ========================================

  /// Mencari konsep yang paling relevan dengan query
  /// Returns: List of concepts sorted by relevance
  static List<ConceptMatch> findRelevantConcepts(
    String query,
    KnowledgeBase knowledgeBase,
  ) {
    List<ConceptMatch> matches = [];
    String queryLower = query.toLowerCase();
    List<String> queryTokens = queryLower
        .split(' ')
        .where((t) => t.length > 2)
        .toList();

    for (var concept in knowledgeBase.concepts) {
      double score = 0.0;
      String termLower = concept.term.toLowerCase();
      String explanationLower = concept.explanation.toLowerCase();

      // 1. Exact match di term (highest priority)
      if (queryLower.contains(termLower)) {
        score += 10.0;
      }

      // 2. Token match di term
      for (var token in queryTokens) {
        if (termLower.contains(token)) {
          score += 3.0;
        }
        if (explanationLower.contains(token)) {
          score += 1.0;
        }
      }

      // 3. Word overlap scoring
      List<String> conceptWords = termLower.split(' ');
      int overlap = queryTokens.where((t) => conceptWords.contains(t)).length;
      score += overlap * 2.0;

      if (score > 0) {
        matches.add(
          ConceptMatch(
            concept: concept,
            score: score,
            matchType: score >= 10 ? 'exact' : 'partial',
          ),
        );
      }
    }

    // Sort by score descending
    matches.sort((a, b) => b.score.compareTo(a.score));

    return matches;
  }

  // ========================================
  // 4. ENHANCED CONTEXT BUILDER
  // ========================================

  /// Membangun konteks terstruktur untuk AI inference
  /// Format optimized untuk TFLite parsing
  static String buildStructuredContext(KnowledgeBase knowledgeBase) {
    StringBuffer buffer = StringBuffer();

    // 1. Summary (highest priority)
    if (knowledgeBase.summary.isNotEmpty) {
      buffer.writeln('SUMMARY: ${knowledgeBase.summary}');
      buffer.writeln();
    }

    // 2. Concepts (second priority)
    if (knowledgeBase.concepts.isNotEmpty) {
      buffer.writeln('CONCEPTS:');
      for (var concept in knowledgeBase.concepts) {
        buffer.writeln('- ${concept.term}: ${concept.explanation}');
      }
      buffer.writeln();
    }

    // 3. Glossary (for reference)
    if (knowledgeBase.glossary.isNotEmpty) {
      buffer.writeln('TERMS:');
      for (var item in knowledgeBase.glossary) {
        String localInfo = item.termLocal.isNotEmpty
            ? ' (${item.termLocal})'
            : '';
        buffer.writeln('- ${item.term}$localInfo: ${item.content}');
      }
    }

    return buffer.toString();
  }

  // ========================================
  // 5. RELEVANCE CHECKING
  // ========================================

  /// Check apakah query relevan dengan materi aktif
  static bool isTopicallyRelevant(String query, KnowledgeBase knowledgeBase) {
    String queryLower = query.toLowerCase();

    // 1. Check against summary keywords
    String summaryLower = knowledgeBase.summary.toLowerCase();
    List<String> queryWords = queryLower
        .split(' ')
        .where((w) => w.length > 3)
        .toList();

    int summaryMatches = 0;
    for (var word in queryWords) {
      if (summaryLower.contains(word)) {
        summaryMatches++;
      }
    }

    // If >30% words match summary, consider relevant
    if (queryWords.isNotEmpty && (summaryMatches / queryWords.length) > 0.3) {
      return true;
    }

    // 2. Check against concept terms
    for (var concept in knowledgeBase.concepts) {
      if (queryLower.contains(concept.term.toLowerCase())) {
        return true;
      }
    }

    // 3. Check against glossary
    for (var item in knowledgeBase.glossary) {
      if (queryLower.contains(item.term.toLowerCase()) ||
          (item.termLocal.isNotEmpty &&
              queryLower.contains(item.termLocal.toLowerCase()))) {
        return true;
      }
    }

    return false; // Not relevant to this material
  }

  // ========================================
  // 6. ENHANCED DISCLAIMER
  // ========================================

  /// Menambahkan disclaimer dengan confidence level
  static String addOfflineDisclaimer(String response, double confidence) {
    String confidenceLabel;
    String icon;

    if (confidence >= 0.7) {
      confidenceLabel = "Tinggi";
      icon = "✅";
    } else if (confidence >= 0.4) {
      confidenceLabel = "Sedang";
      icon = "⚠️";
    } else {
      confidenceLabel = "Rendah";
      icon = "❌";
    }

    return """
$response

$icon **Mode Offline Aktif**
Tingkat Keyakinan: $confidenceLabel (${(confidence * 100).toStringAsFixed(0)}%)

Jawaban dihasilkan dari materi lokal. Untuk informasi lebih lengkap dan akurat, silakan terhubung ke internet.
""";
  }

  // ========================================
  // 7. UTILITY FUNCTIONS (LEGACY COMPATIBLE)
  // ========================================

  /// Extract concepts (legacy compatible)
  static List<String> extractConcepts(KnowledgeBase knowledgeBase) {
    return knowledgeBase.concepts.map((c) => c.term).toList();
  }

  /// Extract summary (legacy compatible)
  static String extractSummary(KnowledgeBase knowledgeBase) {
    return knowledgeBase.summary.isNotEmpty
        ? knowledgeBase.summary
        : 'Tidak ada ringkasan tersedia';
  }

  /// Simple similarity calculation (legacy)
  static double calculateSimilarity(String input, String target) {
    input = input.toLowerCase();
    target = target.toLowerCase();

    if (input == target) return 1.0;
    if (input.contains(target) || target.contains(input)) return 0.7;

    Set<String> inputWords = input.split(' ').toSet();
    Set<String> targetWords = target.split(' ').toSet();

    int commonWords = inputWords.intersection(targetWords).length;
    int totalWords = inputWords.union(targetWords).length;

    return totalWords > 0 ? commonWords / totalWords : 0.0;
  }
}

// ========================================
// HELPER CLASSES
// ========================================

/// Class untuk menyimpan hasil concept matching
class ConceptMatch {
  final ConceptItem concept;
  final double score;
  final String matchType; // 'exact' or 'partial'

  ConceptMatch({
    required this.concept,
    required this.score,
    required this.matchType,
  });

  @override
  String toString() =>
      'ConceptMatch(term: ${concept.term}, score: $score, type: $matchType)';
}

/// Configuration untuk AI Utility
class AIUtilityConfig {
  static const double MIN_CONFIDENCE_THRESHOLD = 0.3;
  static const double HIGH_CONFIDENCE_THRESHOLD = 0.7;
  static const int MAX_CONTEXT_LENGTH = 500; // characters
  static const int MIN_QUERY_LENGTH = 3; // words

  // Topical relevance thresholds
  static const double MIN_RELEVANCE_SCORE = 0.3;
  static const int MIN_MATCHING_CONCEPTS = 1;
}
