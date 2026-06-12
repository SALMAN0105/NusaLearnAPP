// lib/core/services/local_ai_controller_services.dart
import 'dart:math';
import 'dart:io'; // Wajib untuk membaca path File absolut
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/models/material_model.dart';
import 'ai_utility_service.dart';
import 'keyword_pivot_engine_services.dart';
import 'dictionary_service.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LocalAIControllerService {
  static Map<String, dynamic> _safeMap(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is Map) return input.map((k, v) => MapEntry(k.toString(), v));
    print('⚠️ [LocalAI] Expected Map, got ${input.runtimeType}');
    return {};
  }

  /// Safe cast ke List
  static List _safeList(dynamic input) {
    if (input == null) return [];
    if (input is List) return input;
    print('⚠️ [LocalAI] Expected List, got ${input.runtimeType}');
    return [];
  }
  // ═══════════════════════════════════════════
  // PUBLIC ENTRY POINT
  // ═══════════════════════════════════════════

  // lib/core/services/local_ai_controller_services.dart

  Future<String> getResponse(String rawQuery, MaterialModel material) async {
    final kb = material.knowledgeBase;
    final meta = material.aiMetadata;

    // ✅ FIX: Guard yang lebih informatif
    // Cek apakah ada data APAPUN untuk dijawab
    final bool hasAnyData =
        kb.summary.isNotEmpty ||
        kb.concepts.isNotEmpty ||
        kb.glossary.isNotEmpty ||
        _safeList(meta['chunks']).isNotEmpty;

    if (!hasAnyData) {
      // Benar-benar tidak ada data sama sekali
      return _buildNotReadyMessage();
    }

    // ✅ BARU: Informasikan ke user jika mode fallback aktif
    final bool isFallbackMode = (meta['schema_version'] == 'fallback_1.0');

    // Lanjutkan pipeline normal...
    final normalizedQuery = await _normalizeQuery(rawQuery, kb, meta);
    final bool isLocalLanguageUsed =
        rawQuery.toLowerCase() != normalizedQuery.toLowerCase();

    final ragResult = await _runRagPipeline(
      normalizedQuery,
      rawQuery,
      material,
      meta,
      kb,
    );

    String llmGeneratedAnswer;
    try {
      llmGeneratedAnswer = await _generateWithLlama(
        query: normalizedQuery,
        contextText: ragResult.answer,
        isLocalLanguageUsed: isLocalLanguageUsed,
      );
    } catch (e) {
      print('⚠️ [LLM ENGINE] Fallback ke RAG murni. Error: $e');
      llmGeneratedAnswer = ragResult.answer;
    }

    final finalAnswer = await _translateAnswerIfNeeded(
      llmGeneratedAnswer,
      rawQuery,
      meta,
    );

    // ✅ Tambahkan disclaimer jika fallback mode
    final suffix = isFallbackMode
        ? '\n\n_⚠️ Data AI belum diproses penuh. Sync ulang untuk jawaban lebih akurat._'
        : '';

    return _buildFormattedResponse(
      answer: finalAnswer + suffix,
      source: ragResult.source,
      confidence: isFallbackMode
          ? ragResult.confidence *
                0.7 // Turunkan confidence saat fallback
          : ragResult.confidence,
      materialTitle: material.judul,
    );
  }

  // ═══════════════════════════════════════════
  // 🧠 ENGINE LLAMA.CPP INFERENCE
  // ═══════════════════════════════════════════
  Future<String> _generateWithLlama({
    required String query,
    required String contextText,
    required bool isLocalLanguageUsed,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Pengecekan Registri & Validasi Path
    final registry = await db.query(
      'ai_model_registry',
      where: 'is_ready = 1',
      limit: 1,
    );

    if (registry.isEmpty) {
      throw Exception("Model GGUF tidak ditemukan di registry.");
    }

    final String absolutePath = registry.first['absolute_path'] as String;
    if (!await File(absolutePath).exists()) {
      throw Exception("File fisik GGUF hilang dari disk.");
    }

    // 2. Penyusunan Prompt (Sistem ChatML Qwen)
    String constraintInstruction = isLocalLanguageUsed
        ? "JAWAB SANGAT SINGKAT. MAKSIMAL 2 KALIMAT. JANGAN BERTELE-TELE."
        : "Jawab dengan bahasa Indonesia yang ramah, ringkas, dan jelas.";

    final String prompt =
        """<|im_start|>system
Kamu adalah asisten AI NusaLearn. Tugasmu menjawab pertanyaan siswa murni berdasarkan KONTEKS MATERI yang diberikan.
JANGAN mengarang informasi di luar konteks. Jika konteks tidak relevan, katakan 'Maaf, saya tidak menemukan jawabannya di materi ini.'
$constraintInstruction

KONTEKS MATERI:
$contextText<|im_end|>
<|im_start|>user
$query<|im_end|>
<|im_start|>assistant
""";

    print('⚙️ [LLM ENGINE] Memuat model ke RAM & Memulai inferensi...');

    Llama? llama;
    try {
      // 3. Inisialisasi Model via FFI
      llama = Llama(absolutePath);

      // ✅ FIX: Gunakan setPrompt() + getNext() sesuai API llama_cpp_dart
      llama.setPrompt(prompt);

      // 4. Eksekusi Inferensi — stream token satu per satu
      String generatedResponse = "";
      final int maxTokens = isLocalLanguageUsed ? 100 : 300;
      int tokenCount = 0;

      while (tokenCount < maxTokens) {
        final (token, isDone) = llama.getNext();
        generatedResponse += token;
        tokenCount++;
        await Future.delayed(Duration.zero);

        if (isDone) {
          print('✅ [LLM ENGINE] Inferensi selesai (EOS).');
          break;
        }
      }

      if (tokenCount >= maxTokens) {
        print('🛡️ [LLM ENGINE] Batas token tercapai. Memotong inferensi.');
      }

      // Pembersihan token syntax bawaan Qwen jika terikut
      generatedResponse = generatedResponse.replaceAll('<|im_end|>', '').trim();

      return generatedResponse.isEmpty ? contextText : generatedResponse;
    } catch (e) {
      print('❌ [LLM ENGINE] Inferensi Gagal/OOM: $e');
      rethrow;
    } finally {
      // 5. 🧹 GARBAGE COLLECTION ABSOLUT (MISSION CRITICAL)
      llama?.dispose();
      print('🧹 [LLM ENGINE] Model dihancurkan dari RAM (Memory Freed).');
    }
  }

  // ═══════════════════════════════════════════
  // STEP 1: NORMALISASI QUERY
  // ═══════════════════════════════════════════

  Future<String> _normalizeQuery(
    String query,
    KnowledgeBase kb,
    Map<String, dynamic> meta,
  ) async {
    String result = KeywordPivotEngineService.process(query, kb.glossary);

    // ✅ _safeMap — tidak crash jika translation_hints berupa List atau null
    final hints = _safeMap(meta['translation_hints']);
    if (hints.isNotEmpty) {
      hints.forEach((local, indo) {
        final pattern = RegExp(
          r'\b' + RegExp.escape(local.toString()) + r'\b',
          caseSensitive: false,
        );
        result = result.replaceAll(pattern, indo.toString());
      });
    }

    if (DictionaryService.instance.isLoaded) {
      result = await DictionaryService.instance.translateToIndo(result);
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
      final kb2 = _safeMap(meta['knowledge_base']);
      final summary = (kb2['detailed_summary'] as String?) ?? kb.summary;
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
    final qaPairs = _safeList(meta['qa_pairs']); // ✅ _safeList
    if (qaPairs.isEmpty) return null;

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return null;

    _QAMatch? bestMatch;
    double bestScore = 0.0;

    for (final qa in qaPairs) {
      final qMap = _safeMap(qa); // ✅ _safeMap — tidak crash jika qa bukan Map
      final question = (qMap['question'] as String? ?? '').toLowerCase();
      final keywords = _safeList(
        qMap['keywords'],
      ).map((k) => k.toString().toLowerCase()).toSet();

      double score = 0.0;
      if (question.contains(query.toLowerCase())) score += 15.0;

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

    return _RagResult(
      answer: bestMatch.answer,
      source: 'QA Materi',
      confidence: (bestScore / 25.0).clamp(0.0, 1.0),
    );
  }

  // ═══════════════════════════════════════════
  // LAYER A0: NARRATIVE DATASET SEARCH
  // ═══════════════════════════════════════════

  // lib/core/services/local_ai_controller_services.dart

  _RagResult? _searchNarrativeDataset(String query, Map<String, dynamic> nd) {
    final queryLower = query.toLowerCase();
    final queryTokens = _tokenize(query);

    // ✅ DEFENSIVE CAST — semua field pakai helper, tidak ada 'as' langsung
    final characters = _safeList(nd['characters']);
    final plot = _safeMap(nd['plot']); // ← plot bisa [] dari AI non-naratif
    final themes = _safeList(nd['themes']);
    final moralValues = _safeList(nd['moral_values']);
    final narrativeQA = _safeList(nd['narrative_qa']);

    final isAskingAboutCharacter = _isCharacterQuery(queryLower);
    final isAskingAboutPlot = _isPlotQuery(queryLower);
    final isAskingAboutTheme = _isThemeQuery(queryLower);

    // --- Daftar semua karakter ---
    if (isAskingAboutCharacter && _isAskingListOfCharacters(queryLower)) {
      if (characters.isNotEmpty) {
        final charList = characters
            .map((c) {
              final cm = _safeMap(c);
              final name = cm['nama'] ?? '';
              final role = cm['peran'] ?? '';
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

    // --- Karakter tertentu ---
    if (isAskingAboutCharacter) {
      for (final c in characters) {
        final cm = _safeMap(c);
        final name = (cm['nama'] ?? '').toString().toLowerCase();
        final nameLocal = (cm['name_local'] ?? '').toString().toLowerCase();
        if (name.isNotEmpty &&
            (queryLower.contains(name) ||
                (nameLocal.isNotEmpty && queryLower.contains(nameLocal)))) {
          final traits = _safeList(
            cm['traits'],
          ).map((t) => t.toString()).join(', ');
          final desc = cm['description'] ?? '';
          final role = cm['peran'] ?? '';
          String answer =
              '**${cm['nama']}** adalah tokoh **$role** dalam materi ini.\n\n$desc';
          if (traits.isNotEmpty) answer += '\n\n**Sifat/watak:** $traits';
          return _RagResult(
            answer: answer,
            source: 'Dataset Naratif',
            confidence: 0.93,
          );
        }
      }
    }

    // --- Alur / plot ---
    // plot.isEmpty = true jika AI kirim [] atau {} → skip blok ini dengan aman
    if (isAskingAboutPlot && plot.isNotEmpty) {
      final settingPlace = plot['setting_place']?.toString() ?? '';
      final settingTime = plot['setting_time']?.toString() ?? '';
      final beginning = plot['beginning']?.toString() ?? '';
      final conflict = plot['conflict']?.toString() ?? '';
      final resolution = plot['resolution']?.toString() ?? '';

      if (queryLower.contains('tempat') ||
          queryLower.contains('di mana') ||
          queryLower.contains('latar')) {
        if (settingPlace.isNotEmpty) {
          return _RagResult(
            answer:
                'Cerita ini berlatar di **$settingPlace'
                '${settingTime.isNotEmpty ? '** pada **$settingTime' : ''}**.',
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
        final buf = StringBuffer();
        if (beginning.isNotEmpty) buf.writeln('**Awal:** $beginning\n');
        if (conflict.isNotEmpty) buf.writeln('**Konflik:** $conflict\n');
        if (resolution.isNotEmpty) buf.write('**Penyelesaian:** $resolution');
        final answer = buf.toString().trim();
        if (answer.isNotEmpty) {
          return _RagResult(
            answer: answer,
            source: 'Dataset Naratif',
            confidence: 0.88,
          );
        }
      }
    }

    // --- Tema / nilai moral ---
    if (isAskingAboutTheme) {
      if (themes.isNotEmpty || moralValues.isNotEmpty) {
        final buf = StringBuffer();
        if (themes.isNotEmpty) {
          buf.writeln(
            '**Tema:** ${themes.map((t) => t.toString()).join(', ')}\n',
          );
        }
        if (moralValues.isNotEmpty) {
          buf.write(
            '**Nilai moral/amanat:**\n'
            '${moralValues.map((v) => '• $v').join('\n')}',
          );
        }
        return _RagResult(
          answer: buf.toString().trim(),
          source: 'Dataset Naratif',
          confidence: 0.90,
        );
      }
    }

    // --- Fallback: narrative_qa ---
    if (narrativeQA.isNotEmpty) {
      _QAMatch? bestMatch;
      double bestScore = 0.0;

      for (final qa in narrativeQA) {
        final qMap = _safeMap(qa);
        final question = (qMap['question'] as String? ?? '').toLowerCase();
        final keywords = _safeList(
          qMap['keywords'],
        ).map((k) => k.toString().toLowerCase()).toSet();
        final keywordsLocal = _safeList(
          qMap['keywords_local'],
        ).map((k) => k.toString().toLowerCase()).toSet();

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
        return _RagResult(
          answer: bestMatch.answer,
          source: 'Dataset Naratif',
          confidence: (bestScore / 25.0).clamp(0.0, 1.0),
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
    // ✅ Semua akses meta pakai _safeList/_safeMap
    final chunks = _safeList(meta['chunks']);
    final invertedIndex = _safeMap(meta['inverted_index']);

    if (chunks.isEmpty) return null;

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return null;

    final candidateIds = <int>{};
    for (final token in queryTokens) {
      for (final id in _safeList(invertedIndex[token])) {
        if (id is int) candidateIds.add(id);
      }
      for (final key in invertedIndex.keys) {
        if (key.contains(token) || token.contains(key)) {
          for (final id in _safeList(invertedIndex[key])) {
            if (id is int) candidateIds.add(id);
          }
        }
      }
    }

    if (candidateIds.isEmpty) {
      for (int i = 0; i < chunks.length; i++) candidateIds.add(i);
    }

    double bestScore = 0.0;
    String bestText = '';
    int bestChunkId = -1;

    for (final chunkId in candidateIds) {
      if (chunkId >= chunks.length) continue;

      // ✅ _safeMap — tidak crash meski chunk bukan Map
      final chunk = _safeMap(chunks[chunkId]);
      final text = (chunk['text'] as String? ?? '').toLowerCase();
      final chunkKeywords = _safeList(
        chunk['keywords'],
      ).map((k) => k.toString().toLowerCase()).toList();
      final tfidf = _safeMap(chunk['tfidf']);

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
      final c = _safeMap(chunks[i]);
      final t = c['text'] as String? ?? '';
      if (t.isNotEmpty) contextParts.add(t);
    }

    final confidence = (bestScore / 20.0).clamp(0.0, 0.90);
    return _RagResult(
      answer: contextParts.join(' '),
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

    final conceptsV2 = _safeList(_safeMap(meta['knowledge_base'])['concepts']);
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
    final kb2 = _safeMap(meta['knowledge_base']);
    final facts = _safeList(kb2['key_facts']).map((f) => f.toString()).toList();
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
  // ✅ FIX: Ubah return type menjadi Future<String> dan tambahkan async
  Future<String> _translateAnswerIfNeeded(
    String answer,
    String originalQuery,
    Map<String, dynamic> meta,
  ) async {
    final langCode = meta['kode_bahasa'] as String? ?? 'id';
    if (langCode == 'id' || langCode == 'global') return answer;

    if (!DictionaryService.instance.isLoaded) return answer;

    // ✅ FIX: Tambahkan await
    return await DictionaryService.instance.translateToLocal(answer);
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
