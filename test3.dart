void main() {
  String text = "Budi sedang makan ikan di pasar supaya kalian tahu.";
  Map<String, String> _syncCache = {
    "makan": "manga",
    "manga": "makan",
    "ikan": "ika",
    "ika": "ikan",
    "supaya kalian": "ai",
    "ai": "supaya kalian"
  };
  List<String> _sortedKeys = _syncCache.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  
  String result = text;
  for (String key in _sortedKeys) {
    if (result.toLowerCase().contains(key)) {
      final translated = _syncCache[key]!;
      result = result.replaceAllMapped(
          RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false), 
          (match) {
        String original = match.group(0)!;
        return translated;
      });
    }
  }
  print(result);
}
