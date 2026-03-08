// lib/core/services/tflite_service_.dart
// 🚀 FASE 4: Enhanced TFLite dengan Knowledge Map Priority

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:nusalearn/core/services/bert_tokenizer.dart';
import 'package:nusalearn/core/services/ai_utility_service.dart';
import 'package:nusalearn/models/material_model.dart';

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Interpreter? _interpreter;
  final BertTokenizer _tokenizer = BertTokenizer();
  bool _isReady = false;

  // ========================================
  // INITIALIZATION
  // ========================================

  Future<void> loadModel() async {
    if (_isReady) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelPath = '${directory.path}/mobilebert.tflite';

      if (await File(modelPath).exists()) {
        var options = InterpreterOptions()..threads = 2;

        _interpreter = await Interpreter.fromFile(
          File(modelPath),
          options: options,
        );
        await _tokenizer.loadVocab();

        _isReady = true;
        print("🧠 AI Ready: MobileBERT Loaded ( Mode)");
      } else {
        print("⚠️ Model belum diunduh.");
      }
    } catch (e) {
      print("❌ Gagal load AI: $e");
    }
  }

  void dispose() {
    _interpreter?.close();
    _isReady = false;
  }

  // ========================================
  // MAIN ENTRY POINT ()
  // ========================================

  /// Fungsi utama dengan Metadata-Driven approach
  /// Returns: {
  ///   'answer': String,
  ///   'confidence': double,
  ///   'source': String, // 'concept', 'summary', 'chunk', or 'fallback'
  /// }
  Map<String, dynamic> findAnswer(MaterialModel material, String question) {
    // ===== VALIDATION =====
    if (!_isReady) {
      return {
        'answer': 'AI sedang memuat...',
        'confidence': 0.0,
        'source': 'error',
      };
    }

    // 1. Pre-Check: Guardrail Etika & Relevansi
    GuardrailResult guardrail = _checkGuardrails(question, material);
    if (!guardrail.passed) {
      return {
        'answer': guardrail.message,
        'confidence': 1.0,
        'source': 'guardrail',
      };
    }

    try {
      // 2. Extract Knowledge Base
      KnowledgeBase knowledgeBase = material.knowledgeBase;

      // ===== STRATEGY 1: CONCEPT-FIRST RETRIEVAL =====
      var conceptResult = _tryConceptBasedRetrieval(question, knowledgeBase);
      if (conceptResult != null && conceptResult['confidence'] >= 0.5) {
        print("✅ CONCEPT-BASED retrieval successful");
        return conceptResult;
      }

      // ===== STRATEGY 2: SUMMARY-BASED (untuk general questions) =====
      var summaryResult = _trySummaryBasedRetrieval(question, knowledgeBase);
      if (summaryResult != null && summaryResult['confidence'] >= 0.4) {
        print("✅ SUMMARY-BASED retrieval successful");
        return summaryResult;
      }

      // ===== STRATEGY 3: CHUNK-BASED (fallback dengan TFLite) =====
      if (material.aiEmbeddings != null && material.aiEmbeddings!.isNotEmpty) {
        var chunkResult = _tryChunkBasedRetrieval(
          question,
          material.aiEmbeddings!,
          knowledgeBase,
        );
        if (chunkResult != null && chunkResult['confidence'] >= 0.3) {
          print("✅ CHUNK-BASED retrieval successful");
          return chunkResult;
        }
      }

      // ===== FINAL FALLBACK: NOT FOUND =====
      return {
        'answer': _buildNotFoundMessage(question, knowledgeBase),
        'confidence': 0.0,
        'source': 'not_found',
      };
    } catch (e) {
      print("❌ AI Processing Error: $e");
      return {
        'answer': 'Terjadi kesalahan pemrosesan.',
        'confidence': 0.0,
        'source': 'error',
      };
    }
  }

  // ========================================
  // STRATEGY 1: CONCEPT-BASED RETRIEVAL
  // ========================================

  Map<String, dynamic>? _tryConceptBasedRetrieval(
    String question,
    KnowledgeBase knowledgeBase,
  ) {
    // Find relevant concepts
    List<ConceptMatch> matches = AIUtilityService.findRelevantConcepts(
      question,
      knowledgeBase,
    );

    if (matches.isEmpty) return null;

    // Take top match
    ConceptMatch topMatch = matches.first;

    // Confidence based on match type and score
    double confidence = topMatch.matchType == 'exact'
        ? 0.8
        : (topMatch.score / 15.0).clamp(0.3, 0.7);

    // Build answer from concept explanation
    String answer = _buildConceptAnswer(topMatch.concept, question);

    return {
      'answer': answer,
      'confidence': confidence,
      'source': 'concept',
      'metadata': {
        'concept_term': topMatch.concept.term,
        'match_score': topMatch.score,
      },
    };
  }

  String _buildConceptAnswer(ConceptItem concept, String question) {
    // Check if question is asking for definition
    bool isDefinition =
        question.toLowerCase().contains('apa itu') ||
        question.toLowerCase().contains('pengertian') ||
        question.toLowerCase().contains('maksud');

    if (isDefinition) {
      return '${concept.term} adalah ${concept.explanation}';
    }

    // Check if asking for explanation
    bool isExplanation =
        question.toLowerCase().contains('bagaimana') ||
        question.toLowerCase().contains('jelaskan') ||
        question.toLowerCase().contains('cara');

    if (isExplanation) {
      return 'Mengenai ${concept.term}: ${concept.explanation}';
    }

    // Default: just return explanation
    return concept.explanation;
  }

  // ========================================
  // STRATEGY 2: SUMMARY-BASED RETRIEVAL
  // ========================================

  Map<String, dynamic>? _trySummaryBasedRetrieval(
    String question,
    KnowledgeBase knowledgeBase,
  ) {
    if (knowledgeBase.summary.isEmpty) return null;

    // Check if question is asking for general overview
    List<String> overviewKeywords = [
      'tentang apa',
      'isi materi',
      'ringkasan',
      'rangkuman',
      'secara umum',
      'garis besar',
    ];

    bool isOverviewQuestion = overviewKeywords.any(
      (kw) => question.toLowerCase().contains(kw),
    );

    if (isOverviewQuestion) {
      return {
        'answer': knowledgeBase.summary,
        'confidence': 0.7,
        'source': 'summary',
      };
    }

    // Check if summary contains relevant keywords from question
    String questionLower = question.toLowerCase();
    String summaryLower = knowledgeBase.summary.toLowerCase();

    List<String> questionWords = questionLower
        .split(' ')
        .where((w) => w.length > 3)
        .toList();

    int matches = questionWords.where((w) => summaryLower.contains(w)).length;
    double relevance = questionWords.isEmpty
        ? 0
        : matches / questionWords.length;

    if (relevance >= 0.5) {
      // Summary is relevant, use it
      return {
        'answer': knowledgeBase.summary,
        'confidence': relevance * 0.6, // Max 0.6 untuk summary-based
        'source': 'summary',
      };
    }

    return null;
  }

  // ========================================
  // STRATEGY 3: CHUNK-BASED RETRIEVAL ()
  // ========================================

  Map<String, dynamic>? _tryChunkBasedRetrieval(
    String question,
    String aiEmbeddings,
    KnowledgeBase knowledgeBase,
  ) {
    try {
      // 1. Parse embeddings JSON
      var parsed = jsonDecode(aiEmbeddings);
      List<dynamic> chunks = (parsed is Map && parsed.containsKey('chunks'))
          ? parsed['chunks']
          : (parsed is List ? parsed : []);

      if (chunks.isEmpty) return null;

      // 2.  chunk retrieval dengan concept weighting
      String bestContext = _retrieveRelevantChunk(
        chunks,
        question,
        knowledgeBase,
      );

      if (bestContext.isEmpty) return null;

      // 3. Run BERT inference
      return _runBertInference(question, bestContext);
    } catch (e) {
      print("❌ Chunk retrieval error: $e");
      return null;
    }
  }

  String _retrieveRelevantChunk(
    List<dynamic> chunks,
    String question,
    KnowledgeBase knowledgeBase,
  ) {
    // Tokenize question
    List<String> qTokens = question
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 3)
        .toList();

    // Build concept index for weighting
    Map<String, ConceptItem> conceptIndex = AIUtilityService.buildConceptIndex(
      knowledgeBase,
    );

    String bestText = "";
    double maxScore = 0.0;

    for (var chunk in chunks) {
      String text = chunk['text'] ?? chunk['content'] ?? "";
      if (text.isEmpty) continue;

      double score = 0.0;
      String lowerText = text.toLowerCase();

      // 1. Keyword matching dengan concept weighting
      for (var token in qTokens) {
        if (lowerText.contains(token)) {
          // Check if token is a concept
          double weight = conceptIndex.containsKey(token) ? 5.0 : 2.0;
          score += weight;
        }
      }

      // 2. Chunk keywords matching (from backend preprocessing)
      if (chunk['keywords'] != null) {
        List<dynamic> chunkKeywords = chunk['keywords'];
        for (var kw in chunkKeywords) {
          String kwStr = kw.toString().toLowerCase();
          if (question.toLowerCase().contains(kwStr)) {
            double weight = conceptIndex.containsKey(kwStr) ? 8.0 : 4.0;
            score += weight;
          }
        }
      }

      // 3. Concept term exact match (highest priority)
      for (var concept in knowledgeBase.concepts) {
        if (lowerText.contains(concept.term.toLowerCase()) &&
            question.toLowerCase().contains(concept.term.toLowerCase())) {
          score += 10.0;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestText = text;
      }
    }

    //  threshold: require minimum score
    return maxScore >= 5.0 ? bestText : "";
  }

  Map<String, dynamic> _runBertInference(String question, String context) {
    // Limit context length
    if (context.length > 500) {
      context = context.substring(0, 500);
    }

    var encoded = _tokenizer.encodeQA(question, context);

    // Input Tensors
    var inputIds = [encoded['input_ids']];
    var mask = [encoded['attention_mask']];
    var segmentIds = [encoded['token_type_ids']];

    // Output Buffers
    var output0 = List.filled(1 * 384, 0.0).reshape([1, 384]);
    var output1 = List.filled(1 * 384, 0.0).reshape([1, 384]);

    try {
      _interpreter!.runForMultipleInputs(
        [inputIds, mask, segmentIds],
        {0: output0, 1: output1},
      );
    } catch (e) {
      // Fallback if inference error
      return {'answer': context, 'confidence': 0.4, 'source': 'chunk_fallback'};
    }

    List<double> startLogits = output0[0];
    List<double> endLogits = output1[0];

    int startIndex = _argmax(startLogits);
    int endIndex = _argmax(endLogits);

    // Validate indices
    if (endIndex < startIndex) endIndex = startIndex + 15;
    if (endIndex >= 384) endIndex = 383;

    List<int> answerIds = encoded['input_ids']!.sublist(
      startIndex,
      endIndex + 1,
    );
    String answer = _tokenizer.decode(answerIds);

    // Filter junk answers
    if (answer.contains('[CLS]') ||
        answer.contains('[SEP]') ||
        answer.trim().length < 5) {
      return {'answer': context, 'confidence': 0.35, 'source': 'chunk_context'};
    }

    // Calculate confidence
    double confidence = (startLogits[startIndex] + endLogits[endIndex]) / 2.0;
    confidence = (confidence / 10.0).clamp(0.0, 1.0); // Normalize

    return {'answer': answer, 'confidence': confidence, 'source': 'chunk_bert'};
  }

  int _argmax(List<double> list) {
    double maxVal = -double.infinity;
    int maxIdx = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i] > maxVal) {
        maxVal = list[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  // ========================================
  // GUARDRAILS ()
  // ========================================

  GuardrailResult _checkGuardrails(String question, MaterialModel material) {
    String questionLower = question.toLowerCase();

    // 1. Check forbidden topics (hardcoded blacklist)
    List<String> forbidden = [
      'siapa kamu',
      'buatkan kode',
      'harga bitcoin',
      'cara hack',
      'politik',
      'berita terbaru',
      'kabar terkini',
    ];

    for (var word in forbidden) {
      if (questionLower.contains(word)) {
        return GuardrailResult(
          passed: false,
          message:
              'Maaf, saya hanya bisa menjawab pertanyaan seputar materi pelajaran.',
        );
      }
    }

    // 2. Check minimum question length
    if (question.trim().split(' ').length < 2) {
      return GuardrailResult(
        passed: false,
        message: 'Pertanyaan terlalu pendek. Coba jelaskan lebih detail ya!',
      );
    }

    // 3. Check topical relevance
    bool isRelevant = AIUtilityService.isTopicallyRelevant(
      question,
      material.knowledgeBase,
    );

    if (!isRelevant) {
      return GuardrailResult(
        passed: false,
        message: _buildIrrelevantMessage(question, material),
      );
    }

    return GuardrailResult(passed: true, message: '');
  }

  // ========================================
  // HELPER MESSAGES
  // ========================================

  String _buildNotFoundMessage(String question, KnowledgeBase knowledgeBase) {
    String concepts = knowledgeBase.concepts
        .take(3)
        .map((c) => c.term)
        .join(', ');

    return """
Maaf, saya tidak menemukan informasi spesifik tentang "$question" di materi ini.

Materi ini membahas: $concepts

Coba tanyakan hal yang lebih spesifik tentang topik di atas, atau hubungkan ke internet untuk jawaban yang lebih lengkap.
""";
  }

  String _buildIrrelevantMessage(String question, MaterialModel material) {
    String title = material.titleIndo;
    String concepts = material.knowledgeBase.concepts
        .take(3)
        .map((c) => c.term)
        .join(', ');

    return """
Pertanyaan Anda sepertinya di luar topik materi "$title".

Materi ini fokus membahas: $concepts

Silakan tanyakan hal-hal yang terkait dengan topik tersebut.
""";
  }
}

// ========================================
// HELPER CLASSES
// ========================================

class GuardrailResult {
  final bool passed;
  final String message;

  GuardrailResult({required this.passed, required this.message});
}
