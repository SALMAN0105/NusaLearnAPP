// lib/models/material_model.dart
import 'dart:convert';

// ==========================================
// MATERIAL MODEL (Metadata-First Architecture)
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

  /// Getter Utama untuk Akses Metadata AI (Knowledge Base) secara Aman.
  Map<String, dynamic> get aiMetadata {
    if (aiEmbeddings == null || aiEmbeddings!.isEmpty) {
      return {
        'knowledge_base': {
          'summary': 'Metadata belum diproses.',
          'concepts': [],
          'glossary': [],
        },
        'chunks': [],
      };
    }
    try {
      return jsonDecode(aiEmbeddings!);
    } catch (e) {
      return {
        'error': 'Gagal parsing metadata: $e',
        'knowledge_base': {'summary': '', 'concepts': [], 'glossary': []},
        'chunks': [],
      };
    }
  }

  /// Akses Terstruktur ke Peta Pengetahuan (Digunakan untuk Grounding AI)
  KnowledgeBase get knowledgeBase {
    final base = aiMetadata['knowledge_base'] ?? {};
    return KnowledgeBase.fromMap(base);
  }

  /// Factory untuk Sinkronisasi Data dari SQLite
  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: map['id'],
      titleIndo: map['title_indo'] ?? '',
      imageUrl: map['image_url'],
      localImagePath: map['local_image_path'],
      levelDifficulty: map['level_difficulty'] ?? 1,
      languageCode: map['language_code'] ?? 'id',
      contentJson: map['content_json'] ?? '',
      aiEmbeddings: map['ai_embeddings'],
      aiStatus: map['ai_status'] ?? 'pending',
    );
  }

  /// Konversi kembali ke Map untuk penyimpanan SQLite
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
// SUB-MODELS UNTUK GROUNDING & PIVOT
// ==========================================

class KnowledgeBase {
  final String summary;
  final List<ConceptItem> concepts;
  final List<GlossaryItem> glossary;

  KnowledgeBase({
    required this.summary,
    required this.concepts,
    required this.glossary,
  });

  factory KnowledgeBase.fromMap(Map<String, dynamic> map) {
    return KnowledgeBase(
      summary: map['summary'] ?? '',
      concepts: (map['concepts'] as List? ?? [])
          .map((i) => ConceptItem.fromMap(i))
          .toList(),
      glossary: (map['glossary'] as List? ?? [])
          .map((i) => GlossaryItem.fromMap(i))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'concepts': concepts.map((c) => c.toMap()).toList(),
      'glossary': glossary.map((g) => g.toMap()).toList(),
    };
  }
}

class ConceptItem {
  final String term;
  final String explanation;

  ConceptItem({required this.term, required this.explanation});

  factory ConceptItem.fromMap(Map<String, dynamic> map) {
    return ConceptItem(
      term: map['term'] ?? '',
      explanation: map['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'term': term, 'explanation': explanation};
  }
}

class GlossaryItem {
  final String term;
  final String termLocal;
  final String content;

  GlossaryItem({
    required this.term,
    required this.termLocal,
    required this.content,
  });

  factory GlossaryItem.fromMap(Map<String, dynamic> map) {
    return GlossaryItem(
      term: map['term'] ?? '',
      termLocal: map['term_local'] ?? '',
      content: map['content'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'term': term, 'term_local': termLocal, 'content': content};
  }
}
