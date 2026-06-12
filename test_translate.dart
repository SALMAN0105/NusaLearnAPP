import 'package:flutter/material.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DictionaryService.instance.loadDictionary('tk-1');
  String text = "Budi sedang makan ikan di pasar supaya kalian tahu.";
  print("Original: $text");
  print("Translated: ${DictionaryService.instance.translateSync(text)}");
}
