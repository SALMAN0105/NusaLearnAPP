void main() {
  String text = "Budi sedang makan ikan di pasar supaya kalian tahu.";
  Map<String, String> _syncCache = {
    "makan": "manga",
    "ikan": "ika",
    "supaya kalian": "ai"
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
        if (original.isNotEmpty && original[0] == original[0].toUpperCase()) {
          if (translated.length > 1) {
            return translated[0].toUpperCase() + translated.substring(1);
          } else {
            return translated.toUpperCase();
          }
        }
        return translated;
      });
    }
  }
  print(result);
}
