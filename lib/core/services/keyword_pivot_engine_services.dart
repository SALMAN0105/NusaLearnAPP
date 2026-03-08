// lib/core/services/keyword_pivot_engine_services.dart

import 'package:nusalearn/models/material_model.dart';

class KeywordPivotEngineService {
  /// Melakukan substitusi istilah lokal (Tolaki/Daerah) ke Bahasa Indonesia.
  /// Strategi: Longest-Match-First untuk akurasi frase majemuk.
  static String process(String input, List<GlossaryItem> glossary) {
    if (glossary.isEmpty || input.isEmpty) return input;

    String processedText = input.toLowerCase();

    // Sortir glosarium berdasarkan panjang term (descending) O(N log N)
    // untuk memprioritaskan frase panjang daripada kata tunggal.
    final sortedGlossary = List<GlossaryItem>.from(glossary)
      ..sort((a, b) => b.termLocal.length.compareTo(a.termLocal.length));

    for (var item in sortedGlossary) {
      if (item.termLocal.isEmpty) continue;

      // Escape karakter spesial regex dan gunakan word boundary
      final pattern = RegExp(
        r'\b' + RegExp.escape(item.termLocal.toLowerCase()) + r'\b',
        caseSensitive: false,
      );

      if (pattern.hasMatch(processedText)) {
        processedText = processedText.replaceAll(
          pattern,
          item.term.toLowerCase(),
        );
      }
    }

    return processedText;
  }
}
