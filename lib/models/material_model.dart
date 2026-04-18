// lib/models/material_model.dart
// ✅ UPDATED: Kompatibel dengan ai_embeddings schema v2.0
import 'dart:convert';

// ==========================================
// MATERIAL MODEL
// ==========================================

class MaterialModel {
  final int id;
  final String titleIndo;
  final String? imageUrl;
  final String? localImagePath;
  final int levelDifficulty;
  final String languageCode;
  final String contentJson;
  final String? aiEmbeddings;
  final String aiStatus;

  MaterialModel({
    required this.id,
    required this.titleIndo,
    this.imageUrl,
    this.localImagePath,
    required this.levelDifficulty,
    required this.languageCode,
    required this.contentJson,
    this.aiEmbeddings,
    this.aiStatus = 'pending',
  });

  /// Getter: Parse ai_embeddings secara aman
  Map<String, dynamic> get aiMetadata {
    if (aiEmbeddings == null || aiEmbeddings!.isEmpty) {
      return _emptyMetadata();
    }
    try {
      final decoded = jsonDecode(aiEmbeddings!);
      return _toStringMap(decoded);
    } catch (e) {
      return {'error': 'Gagal parsing: $e', ..._emptyMetadata()};
    }
  }

  /// Getter: Narrative dataset (karakter, alur, tema)
  Map<String, dynamic> get narrativeDataset {
    final meta = aiMetadata;
    final nd = meta['narrative_dataset'];
    if (nd == null) return _emptyNarrativeDataset();
    if (nd is Map<String, dynamic>) return nd;
    if (nd is Map) return nd.map((k, v) => MapEntry(k.toString(), v));
    return _emptyNarrativeDataset();
  }

  static Map<String, dynamic> _emptyNarrativeDataset() => {
    'content_type': 'informational',
    'characters': [],
    'plot': {},
    'themes': [],
    'moral_values': [],
    'narrative_qa': [],
  };

  bool get hasNarrativeData {
    final nd = narrativeDataset;
    final chars = nd['characters'] as List? ?? [];
    final qa = nd['narrative_qa'] as List? ?? [];
    return chars.isNotEmpty || qa.isNotEmpty;
  }

  static Map<String, dynamic> _emptyMetadata() => {
    'schema_version': '1.0',
    'knowledge_base': {
      'summary': '',
      'detailed_summary': '',
      'concepts': [],
      'glossary': [],
      'key_facts': [],
      'themes': [],
    },
    'qa_pairs': [],
    'chunks': [],
    'inverted_index': {},
    'bilingual_qa': [],
    'translation_hints': {},
    'narrative_dataset': {
      'content_type': 'informational',
      'characters': [],
      'plot': {},
      'themes': [],
      'moral_values': [],
      'narrative_qa': [],
    },
  };

  /// Getter: KnowledgeBase (backward compatible)
  KnowledgeBase get knowledgeBase {
    final base = aiMetadata['knowledge_base'] ?? {};
    return KnowledgeBase.fromMap(base);
  }

  /// Getter: Schema version untuk feature detection
  String get aiSchemaVersion {
    return aiMetadata['schema_version'] as String? ?? '1.0';
  }

  bool get hasEnhancedAI => aiSchemaVersion.startsWith('2');

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    // Handle ai_embeddings yang bisa berupa Map atau String
    String? aiEmb;
    final raw = map['ai_embeddings'];
    if (raw is String) {
      aiEmb = raw;
    } else if (raw is Map) {
      aiEmb = jsonEncode(raw);
    }

    return MaterialModel(
      id: map['id'],
      titleIndo: map['title_indo'] ?? '',
      imageUrl: map['image_url'],
      localImagePath: map['local_image_path'],
      levelDifficulty: map['level_difficulty'] ?? 1,
      languageCode: map['language_code'] ?? 'id',
      contentJson: map['content_json'] ?? map['content_indo'] ?? '',
      aiEmbeddings: aiEmb,
      aiStatus: map['ai_status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title_indo': titleIndo,
      'image_url': imageUrl,
      'local_image_path': localImagePath,
      'level_difficulty': levelDifficulty,
      'language_code': languageCode,
      'content_json': contentJson,
      'ai_embeddings': aiEmbeddings,
      'ai_status': aiStatus,
    };
  }
}

// ==========================================
// SUB-MODELS
// ==========================================

class KnowledgeBase {
  final String summary;
  final String detailedSummary;
  final List<ConceptItem> concepts;
  final List<GlossaryItem> glossary;
  final List<String> keyFacts;
  final List<String> themes;

  KnowledgeBase({
    required this.summary,
    this.detailedSummary = '',
    required this.concepts,
    required this.glossary,
    this.keyFacts = const [],
    this.themes = const [],
  });

  factory KnowledgeBase.fromMap(dynamic rawMap) {
    final map = _toStringMap(rawMap);
    return KnowledgeBase(
      summary: (map['summary'] ?? '') as String,
      detailedSummary: (map['detailed_summary'] ?? '') as String,
      concepts: (map['concepts'] as List? ?? [])
          .map((i) => ConceptItem.fromMap(i))
          .toList(),
      glossary: (map['glossary'] as List? ?? [])
          .map((i) => GlossaryItem.fromMap(i))
          .toList(),
      keyFacts: (map['key_facts'] as List? ?? [])
          .map((f) => f.toString())
          .toList(),
      themes: (map['themes'] as List? ?? []).map((t) => t.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'detailed_summary': detailedSummary,
      'concepts': concepts.map((c) => c.toMap()).toList(),
      'glossary': glossary.map((g) => g.toMap()).toList(),
      'key_facts': keyFacts,
      'themes': themes,
    };
  }
}

class ConceptItem {
  final String term;
  final String explanation;
  final List<String> examples;
  final List<String> relatedTerms;

  ConceptItem({
    required this.term,
    required this.explanation,
    this.examples = const [],
    this.relatedTerms = const [],
  });

  factory ConceptItem.fromMap(dynamic rawMap) {
    final map = _toStringMap(rawMap);
    return ConceptItem(
      term: (map['term'] ?? '') as String,
      explanation: (map['explanation'] ?? '') as String,
      examples: (map['examples'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      relatedTerms: (map['related_terms'] as List? ?? [])
          .map((r) => r.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'term': term,
    'explanation': explanation,
    'examples': examples,
    'related_terms': relatedTerms,
  };
}

class GlossaryItem {
  final String term;
  final String termLocal;
  final String content;
  final String context;

  GlossaryItem({
    required this.term,
    required this.termLocal,
    required this.content,
    this.context = '',
  });

  factory GlossaryItem.fromMap(dynamic rawMap) {
    final map = _toStringMap(rawMap);
    return GlossaryItem(
      term: (map['term'] ?? '') as String,
      termLocal: (map['term_local'] ?? map['termLocal'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      context: (map['context'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'term': term,
    'term_local': termLocal,
    'content': content,
    'context': context,
  };
}

// ==========================================
// HELPER
// ==========================================

Map<String, dynamic> _toStringMap(dynamic input) {
  if (input == null) return {};
  if (input is Map<String, dynamic>) return input;
  if (input is Map) {
    return input.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

// ==========================================
// HELPER CLASSES (dipakai AIUtilityService)
// ==========================================

class ConceptMatch {
  final ConceptItem concept;
  final double score;
  final String matchType;

  ConceptMatch({
    required this.concept,
    required this.score,
    required this.matchType,
  });
}

class _SearchCandidate {
  final String title;
  final String content;
  final int score;

  _SearchCandidate({
    required this.title,
    required this.content,
    required this.score,
  });
}
