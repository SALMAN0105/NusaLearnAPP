import 'package:flutter/services.dart';

class BertTokenizer {
  static const int maxSeqLength = 384;
  static const String padToken = "[PAD]";
  static const String clsToken = "[CLS]";
  static const String sepToken = "[SEP]";
  static const String unkToken = "[UNK]";

  Map<String, int> _vocab = {};
  bool _isLoaded = false;

  Future<void> loadVocab() async {
    if (_isLoaded) return;

    try {
      String vocabContent = await rootBundle.loadString(
        'assets/models/vocab.txt',
      );
      List<String> lines = vocabContent.split('\n');

      for (int i = 0; i < lines.length; i++) {
        String token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab[token] = i;
        }
      }

      _isLoaded = true;
      print("✅ Vocab loaded: ${_vocab.length} tokens");
    } catch (e) {
      print("❌ Error loading vocab: $e");
    }
  }

  List<int> encode(String text) {
    if (!_isLoaded) {
      print("⚠️ Vocab belum di-load!");
      return [];
    }

    List<String> tokens = _tokenize(text.toLowerCase());
    List<int> ids = [];
    for (String token in tokens) {
      ids.addAll(_tokenToIds(token));
    }

    return ids;
  }

  List<int> _tokenToIds(String token) {
    if (_vocab.containsKey(token)) {
      return [_vocab[token]!];
    }

    List<int> subwordIds = [];
    int start = 0;
    bool isBad = false;

    while (start < token.length) {
      int end = token.length;
      String? curSubstr;

      while (start < end) {
        String substr = token.substring(start, end);
        if (start > 0) {
          substr = "##$substr";
        }

        if (_vocab.containsKey(substr)) {
          curSubstr = substr;
          break;
        }
        end--;
      }

      if (curSubstr == null) {
        isBad = true;
        break;
      }

      subwordIds.add(_vocab[curSubstr]!);
      start = end;
    }

    if (isBad) {
      return [_vocab[unkToken]!];
    }

    return subwordIds;
  }

  List<String> _tokenize(String text) {
    text = text.replaceAllMapped(
      RegExp(r'([.,!?;:])'),
      (match) => ' ${match.group(0)} ',
    );

    return text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// ✅ FIX: Gunakan growable list, bukan fixed-length
  Map<String, List<int>> encodeQA(String question, String context) {
    List<int> questionIds = encode(question);
    List<int> contextIds = encode(context);

    // ✅ FIX: Pakai List<int>[] (growable) bukan List.filled
    List<int> inputIds = <int>[];
    inputIds.add(_vocab[clsToken]!);
    inputIds.addAll(questionIds);
    inputIds.add(_vocab[sepToken]!);
    inputIds.addAll(contextIds);
    inputIds.add(_vocab[sepToken]!);

    // Truncate jika melebihi max length
    if (inputIds.length > maxSeqLength) {
      inputIds = inputIds.sublist(0, maxSeqLength - 1);
      inputIds.add(_vocab[sepToken]!);
    }

    // ✅ FIX: Buat attention mask & token type IDs dengan growable list
    List<int> attentionMask = <int>[];
    List<int> tokenTypeIds = <int>[];

    // Token Type IDs: 0 untuk question, 1 untuk context
    int sepCount = 0;
    for (int id in inputIds) {
      if (id == _vocab[sepToken]) sepCount++;
      attentionMask.add(1);
      tokenTypeIds.add(sepCount >= 1 ? 1 : 0);
    }

    // Padding
    int paddingLength = maxSeqLength - inputIds.length;
    for (int i = 0; i < paddingLength; i++) {
      inputIds.add(_vocab[padToken]!);
      attentionMask.add(0);
      tokenTypeIds.add(0);
    }

    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
      'token_type_ids': tokenTypeIds,
    };
  }

  String decode(List<int> ids) {
    Map<int, String> reverseVocab = _vocab.map((k, v) => MapEntry(v, k));

    List<String> tokens = ids
        .map((id) => reverseVocab[id] ?? unkToken)
        .where((t) => t != padToken && t != clsToken && t != sepToken)
        .toList();

    String result = tokens.join(' ').replaceAll(' ##', '');
    return result;
  }
}
