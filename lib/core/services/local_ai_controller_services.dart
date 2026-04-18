// lib/core/services/local_ai_controller_services.dart
import 'dart:math';
import 'package:nusalearn/models/material_model.dart';
import 'ai_utility_service.dart';
import 'keyword_pivot_engine_services.dart';
import 'dictionary_service.dart';

class LocalAIControllerService {
  // ═══════════════════════════════════════════
  // PUBLIC ENTRY POINT
  // ═══════════════════════════════════════════

  Future<String> getResponse(String rawQuery, MaterialModel material) async {
    final kb = material.knowledgeBase;
    final meta = material.aiMetadata;

    // Guard: data kosong
    if (kb.summary.isEmpty && kb.concepts.isEmpty && kb.glossary.isEmpty) {
      return _buildNotReadyMessage();
    }

    // 1. Normalisasi bahasa daerah → Indonesia
    final normalizedQuery = _normalizeQuery(rawQuery, kb, meta);
    print('🔄 Query: "$rawQuery" → "$normalizedQuery"');

    // 2. Pipeline RAG (urutan prioritas)
    final result = await _runRagPipeline(
      normalizedQuery,
      rawQuery,
      material,
      meta,
      kb,
    );

    // 3. Terjemahkan jawaban ke bahasa daerah jika perlu
    final finalAnswer = _translateAnswerIfNeeded(result.answer, rawQuery, meta);

    return _buildFormattedResponse(
      answer: finalAnswer,
      source: result.source,
      confidence: result.confidence,
      materialTitle: material.titleIndo,
    );
  }

  // ═══════════════════════════════════════════
  // STEP 1: NORMALISASI QUERY
  // ═══════════════════════════════════════════

  String _normalizeQuery(
    String query,
    KnowledgeBase kb,
    Map<String, dynamic> meta,
  ) {
    // a) Pivot bahasa daerah → Indo dari glossary materi
    String result = KeywordPivotEngineService.process(query, kb.glossary);

    // b) Pivot menggunakan translation_hints dari ai_embeddings
    //    Format yang benar: {kata_lokal: kata_Indonesia}
    //    Loop: forEach((local, indo) → ganti kata lokal dengan kata Indonesia
    final hints = meta['translation_hints'] as Map<String, dynamic>? ?? {};
    if (hints.isNotEmpty) {
      hints.forEach((local, indo) {
        final pattern = RegExp(
          r'\b' + RegExp.escape(local.toString()) + r'\b',
          caseSensitive: false,
        );
        result = result.replaceAll(pattern, indo.toString());
      });
    }

    // c) Pivot dari DictionaryService (kamus yang didownload)
    if (DictionaryService.instance.isLoaded) {
      result = DictionaryService.instance.translateToIndo(result);
    }

    return result;
  }

  // ═══════════════════════════════════════════
  // STEP 2: RAG PIPELINE
  // ═══════════════════════════════════════════

  Future<_RagResult> _runRagPipeline(
    String query,
    String originalQuery,
    MaterialModel material,
    Map<String, dynamic> meta,
    KnowledgeBase kb,
  ) async {
    // ── Layer A0: Narrative Dataset (prioritas TERTINGGI) ─────────────
    if (material.hasNarrativeData) {
      final narrativeResult = _searchNarrativeDataset(
        query,
        material.narrativeDataset,
      );
      if (narrativeResult != null) {
        print(
          '✅ RAG Layer A0: Narrative Dataset (confidence: ${narrativeResult.confidence})',
        );
        return narrativeResult;
      }
    }

    // ── BUG FIX ISU 2: Layer E-early untuk pertanyaan definisi ────────
    // Pertanyaan "apa itu X" / "definisi X" harus langsung ke Glossary,
    // bukan ke QA Match yang bisa menghasilkan jawaban kurang tepat.
    if (_isDefinitionQuery(query)) {
      final earlyGlossary = _searchGlossary(query, kb.glossary);
      if (earlyGlossary != null) {
        print('✅ RAG Layer E-early: Glossary (definition query)');
        return earlyGlossary;
      }
    }

    // ── Layer A: QA Direct Match ──────────────────────────────────────
    final qaResult = _searchQAPairs(query, meta);
    if (qaResult != null) {
      print(
        '✅ RAG Layer A: QA Direct Match (confidence: ${qaResult.confidence})',
      );
      return qaResult;
    }

    // ── Layer B: Summary query ────────────────────────────────────────
    if (_isAskingForSummary(query)) {
      final summary =
          (meta['knowledge_base']?['detailed_summary'] as String?) ??
          kb.summary;
      if (summary.isNotEmpty) {
        return _RagResult(
          answer: summary,
          source: 'Ringkasan Materi',
          confidence: 0.95,
        );
      }
    }

    // ── Layer C: TF-IDF Chunk Retrieval ──────────────────────────────
    final chunkResult = _tfidfChunkRetrieval(query, meta, kb);
    if (chunkResult != null && chunkResult.confidence >= 0.55) {
      print(
        '✅ RAG Layer C: TF-IDF Chunk (confidence: ${chunkResult.confidence})',
      );
      return chunkResult;
    }

    // ── Layer D: Concept Match ────────────────────────────────────────
    final conceptResult = _searchConcepts(query, kb, meta);
    if (conceptResult != null) {
      print(
        '✅ RAG Layer D: Concept Match (confidence: ${conceptResult.confidence})',
      );
      return conceptResult;
    }

    // ── Layer E: Glossary Match ───────────────────────────────────────
    final glossaryResult = _searchGlossary(query, kb.glossary);
    if (glossaryResult != null) {
      print('✅ RAG Layer E: Glossary Match');
      return glossaryResult;
    }

    // ── Layer F: Key Facts ────────────────────────────────────────────
    final factsResult = _searchKeyFacts(query, meta);
    if (factsResult != null) {
      print('✅ RAG Layer F: Key Facts Match');
      return factsResult;
    }

    // ── Layer G: Summary Fallback ─────────────────────────────────────
    if (kb.summary.isNotEmpty) {
      return _RagResult(
        answer:
            'Berdasarkan materi ini:\n\n${kb.summary}\n\n'
            '_Pertanyaan spesifik kamu belum tercakup langsung. '
            'Coba hubungkan ke internet untuk jawaban lebih lengkap._',
        source: 'Ringkasan Materi',
        confidence: 0.35,
      );
    }

    return _RagResult(
      answer:
          'Maaf, saya tidak menemukan informasi yang relevan. '
          'Coba pertanyaan dengan kata kunci berbeda, atau hubungkan ke internet.',
      source: 'Tidak Ditemukan',
      confidence: 0.0,
    );
  }

  // ═══════════════════════════════════════════
  // LAYER A: QA DIRECT MATCH
  // ═══════════════════════════════════════════

  _RagResult? _searchQAPairs(String query, Map<String, dynamic> meta) {
    final qaPairs = meta['qa_pairs'] as List? ?? [];
    if (qaPairs.isEmpty) return null;

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return null;

    _QAMatch? bestMatch;
    double bestScore = 0.0;

    for (final qa in qaPairs) {
      final qMap = qa as Map<String, dynamic>;
      final question = (qMap['question'] as String? ?? '').toLowerCase();
      final keywords = (qMap['keywords'] as List? ?? [])
          .map((k) => k.toString().toLowerCase())
          .toSet();

      double score = 0.0;

      if (question.contains(query.toLowerCase())) {
        score += 15.0;
      }

      for (final kw in keywords) {
        if (query.toLowerCase().contains(kw)) score += 4.0;
        for (final token in queryTokens) {
          if (kw.contains(token) || token.contains(kw)) score += 2.0;
        }
      }

      final questionTokens = _tokenize(question);
      final overlap = queryTokens
          .where((t) => questionTokens.contains(t))
          .length;
      final jaccard =
          overlap / (queryTokens.length + questionTokens.length - overlap + 1);
      score += jaccard * 10.0;

      if (score > bestScore) {
        bestScore = score;
        bestMatch = _QAMatch(
          question: qMap['question'] as String? ?? '',
          answer: qMap['answer'] as String? ?? '',
          score: score,
        );
      }
    }

    if (bestMatch == null || bestScore < 5.0) return null;

    final confidence = (bestScore / 25.0).clamp(0.0, 1.0);
    return _RagResult(
      answer: bestMatch.answer,
      source: 'QA Materi',
      confidence: confidence,
    );
  }

  // ═══════════════════════════════════════════
  // LAYER A0: NARRATIVE DATASET SEARCH
  // ═══════════════════════════════════════════

  _RagResult? _searchNarrativeDataset(String query, Map<String, dynamic> nd) {
    final queryLower = query.toLowerCase();
    final queryTokens = _tokenize(query);

    final isAskingAboutCharacter = _isCharacterQuery(queryLower);
    final isAskingAboutPlot = _isPlotQuery(queryLower);
    final isAskingAboutTheme = _isThemeQuery(queryLower);

    final characters = nd['characters'] as List? ?? [];
    final plot = nd['plot'] as Map<String, dynamic>? ?? {};
    final themes = nd['themes'] as List? ?? [];
    final moralValues = nd['moral_values'] as List? ?? [];
    final narrativeQA = nd['narrative_qa'] as List? ?? [];

    // --- 2. Daftar karakter ---
    if (isAskingAboutCharacter && _isAskingListOfCharacters(queryLower)) {
      if (characters.isNotEmpty) {
        final charList = characters
            .map((c) {
              final cm = c as Map<String, dynamic>;
              final name = cm['name'] ?? '';
              final role = cm['role'] ?? '';
              final desc = cm['description'] ?? '';
              return '• **$name** ($role): $desc';
            })
            .join('\n');
        return _RagResult(
          answer: 'Karakter/tokoh dalam materi ini:\n\n$charList',
          source: 'Dataset Naratif',
          confidence: 0.95,
        );
      }
    }

    // --- 3. Karakter tertentu ---
    if (isAskingAboutCharacter) {
      for (final c in characters) {
        final cm = c as Map<String, dynamic>;
        final name = (cm['name'] ?? '').toString().toLowerCase();
        final nameLocal = (cm['name_local'] ?? '').toString().toLowerCase();
        if (name.isNotEmpty &&
            (queryLower.contains(name) ||
                (nameLocal.isNotEmpty && queryLower.contains(nameLocal)))) {
          final traits = (cm['traits'] as List? ?? []).join(', ');
          final desc = cm['description'] ?? '';
          final role = cm['role'] ?? '';
          String answer =
              '**${cm['name']}** adalah tokoh **$role** dalam materi ini.\n\n$desc';
          if (traits.isNotEmpty) answer += '\n\n**Sifat/watak:** $traits';
          return _RagResult(
            answer: answer,
            source: 'Dataset Naratif',
            confidence: 0.93,
          );
        }
      }
    }

    // --- 4. Alur / plot ---
    if (isAskingAboutPlot && plot.isNotEmpty) {
      final beginning = plot['beginning'] ?? '';
      final conflict = plot['conflict'] ?? '';
      final resolution = plot['resolution'] ?? '';
      final settingPlace = plot['setting_place'] ?? '';
      final settingTime = plot['setting_time'] ?? '';

      if (queryLower.contains('tempat') ||
          queryLower.contains('di mana') ||
          queryLower.contains('latar')) {
        if (settingPlace.isNotEmpty) {
          return _RagResult(
            answer:
                'Cerita ini berlatar di **$settingPlace**${settingTime.isNotEmpty ? ' pada **$settingTime**' : ''}.',
            source: 'Dataset Naratif',
            confidence: 0.90,
          );
        }
      }
      if (queryLower.contains('konflik') ||
          queryLower.contains('masalah') ||
          queryLower.contains('permasalahan')) {
        if (conflict.isNotEmpty) {
          return _RagResult(
            answer: 'Konflik utama: $conflict',
            source: 'Dataset Naratif',
            confidence: 0.90,
          );
        }
      }
      if (beginning.isNotEmpty ||
          conflict.isNotEmpty ||
          resolution.isNotEmpty) {
        String answer = '';
        if (beginning.isNotEmpty) answer += '**Awal:** $beginning\n\n';
        if (conflict.isNotEmpty) answer += '**Konflik:** $conflict\n\n';
        if (resolution.isNotEmpty) answer += '**Penyelesaian:** $resolution';
        if (answer.isNotEmpty) {
          return _RagResult(
            answer: answer.trim(),
            source: 'Dataset Naratif',
            confidence: 0.88,
          );
        }
      }
    }

    // --- 5. Tema / nilai moral ---
    if (isAskingAboutTheme) {
      if (themes.isNotEmpty || moralValues.isNotEmpty) {
        String answer = '';
        if (themes.isNotEmpty) answer += '**Tema:** ${themes.join(', ')}\n\n';
        if (moralValues.isNotEmpty) {
          answer +=
              '**Nilai moral/amanat:**\n${moralValues.map((v) => '• $v').join('\n')}';
        }
        return _RagResult(
          answer: answer.trim(),
          source: 'Dataset Naratif',
          confidence: 0.90,
        );
      }
    }

    // --- 6. Fallback: narrative_qa ---
    if (narrativeQA.isNotEmpty) {
      _QAMatch? bestMatch;
      double bestScore = 0.0;

      for (final qa in narrativeQA) {
        final qMap = qa as Map<String, dynamic>;
        final question = (qMap['question'] as String? ?? '').toLowerCase();
        final keywords = (qMap['keywords'] as List? ?? [])
            .map((k) => k.toString().toLowerCase())
            .toSet();
        final keywordsLocal = (qMap['keywords_local'] as List? ?? [])
            .map((k) => k.toString().toLowerCase())
            .toSet();

        double score = 0.0;
        if (question.contains(queryLower)) score += 15.0;
        for (final kw in {...keywords, ...keywordsLocal}) {
          if (queryLower.contains(kw)) score += 4.0;
          for (final token in queryTokens) {
            if (kw.contains(token) || token.contains(kw)) score += 2.0;
          }
        }
        final qTokens = _tokenize(question);
        final overlap = queryTokens.where((t) => qTokens.contains(t)).length;
        final jaccard =
            overlap / (queryTokens.length + qTokens.length - overlap + 1);
        score += jaccard * 10.0;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = _QAMatch(
            question: qMap['question'] as String? ?? '',
            answer: qMap['answer'] as String? ?? '',
            score: score,
          );
        }
      }

      if (bestMatch != null && bestScore >= 4.0) {
        final confidence = (bestScore / 25.0).clamp(0.0, 1.0);
        return _RagResult(
          answer: bestMatch.answer,
          source: 'Dataset Naratif',
          confidence: confidence,
        );
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════
  // HELPER: DETEKSI TIPE PERTANYAAN
  // ═══════════════════════════════════════════

  bool _isCharacterQuery(String q) {
    const triggers = [
      'siapa',
      'tokoh',
      'karakter',
      'pelaku',
      'pemain',
      'protagonist',
      'antagonis',
      'pemeran',
      'figure',
      'figur',
    ];
    return triggers.any((t) => q.contains(t));
  }

  bool _isAskingListOfCharacters(String q) {
    return q.contains('saja') ||
        q.contains('semua') ||
        q.contains('ada apa') ||
        q.contains('daftar') ||
        q.contains('ada siapa') ||
        q.contains('berapa');
  }

  bool _isPlotQuery(String q) {
    const triggers = [
      'cerita',
      'alur',
      'plot',
      'kisah',
      'bagaimana',
      'awal',
      'akhir',
      'konflik',
      'ending',
      'setting',
      'latar',
      'tempat',
      'kapan',
    ];
    return triggers.any((t) => q.contains(t));
  }

  bool _isThemeQuery(String q) {
    const triggers = [
      'tema',
      'amanat',
      'pesan',
      'moral',
      'nilai',
      'pelajaran',
      'makna',
    ];
    return triggers.any((t) => q.contains(t));
  }

  // BUG FIX ISU 2: helper baru untuk deteksi pertanyaan definisi
  // Dipakai oleh Layer E-early agar "apa itu X" langsung ke Glossary
  bool _isDefinitionQuery(String q) {
    const triggers = [
      'apa itu',
      'definisi',
      'pengertian',
      'artinya',
      'maksud dari',
    ];
    return triggers.any((t) => q.toLowerCase().contains(t));
  }

  // ═══════════════════════════════════════════
  // LAYER C: TF-IDF CHUNK RETRIEVAL
  // ═══════════════════════════════════════════

  _RagResult? _tfidfChunkRetrieval(
    String query,
    Map<String, dynamic> meta,
    KnowledgeBase kb,
  ) {
    final chunks = meta['chunks'] as List? ?? [];
    final invertedIndex = meta['inverted_index'] as Map<String, dynamic>? ?? {};

    if (chunks.isEmpty) return null;

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return null;

    final candidateIds = <int>{};
    for (final token in queryTokens) {
      final ids = invertedIndex[token] as List?;
      if (ids != null) {
        for (final id in ids) {
          candidateIds.add(id as int);
        }
      }
      for (final key in invertedIndex.keys) {
        if (key.contains(token) || token.contains(key)) {
          final ids2 = invertedIndex[key] as List?;
          if (ids2 != null) {
            for (final id in ids2) candidateIds.add(id as int);
          }
        }
      }
    }

    if (candidateIds.isEmpty) {
      for (int i = 0; i < chunks.length; i++) {
        candidateIds.add(i);
      }
    }

    double bestScore = 0.0;
    String bestText = '';
    int bestChunkId = -1;

    for (final chunkId in candidateIds) {
      if (chunkId >= chunks.length) continue;
      final chunk = chunks[chunkId] as Map<String, dynamic>;
      final text = (chunk['text'] as String? ?? '').toLowerCase();
      final chunkKeywords = (chunk['keywords'] as List? ?? [])
          .map((k) => k.toString().toLowerCase())
          .toList();
      final tfidf = chunk['tfidf'] as Map<String, dynamic>? ?? {};

      double score = 0.0;

      for (final token in queryTokens) {
        if (text.contains(token)) {
          final tfidfScore = (tfidf[token] as num?)?.toDouble() ?? 0.0;
          score += 2.0 + tfidfScore * 5.0;
        }
      }

      for (final kw in chunkKeywords) {
        if (queryTokens.contains(kw)) score += 3.0;
        for (final token in queryTokens) {
          if (kw.contains(token) || token.contains(kw)) score += 1.5;
        }
      }

      for (final concept in kb.concepts) {
        final termLower = concept.term.toLowerCase();
        if (text.contains(termLower) &&
            query.toLowerCase().contains(termLower)) {
          score += 5.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestText = chunk['text'] as String? ?? '';
        bestChunkId = chunkId;
      }
    }

    if (bestScore < 3.0 || bestText.isEmpty) return null;

    final contextParts = <String>[];
    for (
      int i = max(0, bestChunkId - 1);
      i <= min(chunks.length - 1, bestChunkId + 1);
      i++
    ) {
      final c = chunks[i] as Map<String, dynamic>;
      final t = c['text'] as String? ?? '';
      if (t.isNotEmpty) contextParts.add(t);
    }
    final fullContext = contextParts.join(' ');

    final confidence = (bestScore / 20.0).clamp(0.0, 0.90);
    return _RagResult(
      answer: fullContext,
      source: 'Konten Materi',
      confidence: confidence,
    );
  }

  // ═══════════════════════════════════════════
  // LAYER D: CONCEPT MATCH
  // ═══════════════════════════════════════════

  _RagResult? _searchConcepts(
    String query,
    KnowledgeBase kb,
    Map<String, dynamic> meta,
  ) {
    final matches = AIUtilityService.findRelevantConcepts(query, kb);
    if (matches.isEmpty) return null;

    final best = matches.first;
    if (best.score < 3.0) return null;

    final conceptsV2 = (meta['knowledge_base']?['concepts'] as List? ?? []);
    final enhancedConcept = conceptsV2.firstWhere(
      (c) =>
          (c as Map<String, dynamic>)['term']?.toString().toLowerCase() ==
          best.concept.term.toLowerCase(),
      orElse: () => null,
    );

    String answer = '**${best.concept.term}**\n\n${best.concept.explanation}';

    if (enhancedConcept != null) {
      final eMap = enhancedConcept as Map<String, dynamic>;
      final examples = (eMap['examples'] as List? ?? []).cast<String>();
      final relatedTerms = (eMap['related_terms'] as List? ?? [])
          .cast<String>();

      if (examples.isNotEmpty) {
        answer += '\n\n**Contoh:**\n${examples.map((e) => '• $e').join('\n')}';
      }
      if (relatedTerms.isNotEmpty) {
        answer += '\n\n_Istilah terkait: ${relatedTerms.join(', ')}_';
      }
    }

    if (matches.length > 1 && best.score < 10.0) {
      final others = matches
          .skip(1)
          .take(2)
          .map((m) => m.concept.term)
          .join(', ');
      answer += '\n\n_Topik terkait: ${others}_';
    }

    final confidence = (best.score / 15.0).clamp(0.0, 0.95);
    return _RagResult(
      answer: answer,
      source: 'Konsep Materi',
      confidence: confidence,
    );
  }

  // ═══════════════════════════════════════════
  // LAYER E: GLOSSARY MATCH
  // ═══════════════════════════════════════════

  _RagResult? _searchGlossary(String query, List<GlossaryItem> glossary) {
    final queryLower = query.toLowerCase();
    for (final item in glossary) {
      final termLower = item.term.toLowerCase();
      final localLower = item.termLocal.toLowerCase();

      if (queryLower.contains(termLower) ||
          (localLower.isNotEmpty && queryLower.contains(localLower))) {
        final localInfo = item.termLocal.isNotEmpty
            ? ' _(${item.termLocal})_'
            : '';
        return _RagResult(
          answer: '**${item.term}$localInfo**\n\n${item.content}',
          source: 'Glosarium',
          confidence: 0.85,
        );
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════
  // LAYER F: KEY FACTS
  // ═══════════════════════════════════════════

  _RagResult? _searchKeyFacts(String query, Map<String, dynamic> meta) {
    final facts = (meta['knowledge_base']?['key_facts'] as List? ?? [])
        .map((f) => f.toString())
        .toList();
    if (facts.isEmpty) return null;

    final queryTokens = _tokenize(query);
    final relevantFacts = <String>[];

    for (final fact in facts) {
      final factTokens = _tokenize(fact.toLowerCase());
      final overlap = queryTokens.where((t) => factTokens.contains(t)).length;
      if (overlap >= 1) relevantFacts.add(fact);
    }

    if (relevantFacts.isEmpty) return null;

    final answer =
        'Fakta penting terkait pertanyaanmu:\n\n'
        '${relevantFacts.map((f) => '• $f').join('\n')}';
    return _RagResult(answer: answer, source: 'Fakta Kunci', confidence: 0.65);
  }

  // ═══════════════════════════════════════════
  // STEP 3: BILINGUAL TRANSLATION
  // ═══════════════════════════════════════════

  String _translateAnswerIfNeeded(
    String answer,
    String originalQuery,
    Map<String, dynamic> meta,
  ) {
    final langCode = meta['language_code'] as String? ?? 'id';
    if (langCode == 'id' || langCode == 'global') return answer;

    if (!DictionaryService.instance.isLoaded) return answer;

    return DictionaryService.instance.translateToLocal(answer);
  }

  // ═══════════════════════════════════════════
  // FORMAT RESPONSE
  // ═══════════════════════════════════════════

  String _buildFormattedResponse({
    required String answer,
    required String source,
    required double confidence,
    required String materialTitle,
  }) {
    String confidenceLabel;
    String icon;

    if (confidence >= 0.80) {
      confidenceLabel = 'Tinggi';
      icon = '✅';
    } else if (confidence >= 0.55) {
      confidenceLabel = 'Sedang';
      icon = '🔵';
    } else if (confidence >= 0.30) {
      confidenceLabel = 'Rendah';
      icon = '⚠️';
    } else {
      confidenceLabel = 'Sangat Rendah';
      icon = '❓';
    }

    final disclaimer = confidence < 0.55
        ? '\n\n_Jawaban ini mungkin kurang spesifik. Coba hubungkan ke internet untuk jawaban lebih akurat._'
        : '';

    return '''🤖 **Asisten AI (Offline)**

$answer$disclaimer

---
📚 $materialTitle · $icon Keyakinan: $confidenceLabel
🔍 Sumber: $source · 📴 Mode Offline''';
  }

  String _buildNotReadyMessage() {
    return '''⚠️ **Data Materi Belum Siap**

Materi ini belum memiliki data AI yang lengkap. Langkah perbaikan:
1. Pastikan terhubung ke internet
2. Kembali ke menu utama
3. Tunggu proses sync selesai

Setelah itu, AI offline akan berfungsi dengan akurasi penuh.''';
  }

  // ═══════════════════════════════════════════
  // HELPER UTILS
  // ═══════════════════════════════════════════

  static const _summaryTriggers = [
    'apa itu',
    'jelaskan',
    'ceritakan',
    'ringkasan',
    'ringkas',
    'gambaran',
    'tentang materi',
    'materi ini',
    'isi materi',
    'rangkuman',
    'kesimpulan',
    'secara singkat',
    'secara umum',
  ];

  bool _isAskingForSummary(String query) {
    final q = query.toLowerCase();
    return _summaryTriggers.any((t) => q.contains(t));
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
  }

  void dispose() {
    // no-op
  }
}

// ═══════════════════════════════════════════
// HELPER CLASSES
// ═══════════════════════════════════════════

class _RagResult {
  final String answer;
  final String source;
  final double confidence;

  const _RagResult({
    required this.answer,
    required this.source,
    required this.confidence,
  });
}

class _QAMatch {
  final String question;
  final String answer;
  final double score;

  const _QAMatch({
    required this.question,
    required this.answer,
    required this.score,
  });
}

class GuardrailResult {
  final bool passed;
  final String message;

  GuardrailResult({required this.passed, required this.message});
}
