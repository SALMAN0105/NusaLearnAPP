import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:nusalearn/core/api/api_client.dart';

class DictionaryService {
  // ✅ SINGLETON PATTERN
  static final DictionaryService instance = DictionaryService._internal();

  factory DictionaryService() => instance;

  DictionaryService._internal();

  final Dio _dio = ApiClient.getClient();
  Map<String, String> dictionaryCache = {};
  bool isLoaded = false;

  /// Download kamus
  Future<bool> downloadDictionary(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/dictionary_$languageCode.json';

      if (await File(savePath).exists()) {
        print('✅ DICT: Kamus $languageCode sudah ada di HP.');
        await loadDictionary(languageCode);
        return true;
      }

      print('📥 DICT: Mendownload kamus $languageCode...');

      String serverPath = 'dictionaries/kamus_$languageCode.json';
      final baseUrl = ApiClient.baseUrl.replaceAll('api', 'storage');
      final fullUrl = '$baseUrl/$serverPath';

      await _dio.download(fullUrl, savePath);

      if (await File(savePath).exists()) {
        print('✅ DICT: Kamus berhasil didownload: $savePath');
        await loadDictionary(languageCode);
        return true;
      } else {
        print('❌ DICT: File gagal disimpan');
        return false;
      }
    } catch (e) {
      print('❌ DICT: Gagal download kamus: $e');
      return false;
    }
  }

  Future<bool> isDictionaryDownloaded(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$languageCode.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> loadDictionary(String languageCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/dictionary_$languageCode.json');

      if (!await file.exists()) {
        print('⚠️ DICT: Kamus $languageCode belum didownload.');
        dictionaryCache.clear();
        isLoaded = false;
        return false;
      }

      String content = await file.readAsString();
      dynamic jsonData = jsonDecode(content);

      if (jsonData is Map<String, dynamic>) {
        dictionaryCache = jsonData.map(
          (key, value) => MapEntry(key.toLowerCase(), value.toString()),
        );
        isLoaded = true;
        print('✅ DICT: Kamus dimuat: ${dictionaryCache.length} kata');
        return true;
      }

      print('❌ DICT: Format kamus salah!');
      dictionaryCache.clear();
      isLoaded = false;
      return false;
    } catch (e) {
      print('❌ DICT: Error load kamus: $e');
      dictionaryCache.clear();
      isLoaded = false;
      return false;
    }
  }

  String translate(String text) {
    if (!isLoaded || dictionaryCache.isEmpty) return text;

    List<String> words = text.split(' ');
    List<String> translatedWords = [];

    for (String word in words) {
      String cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
      if (dictionaryCache.containsKey(cleanWord)) {
        translatedWords.add(dictionaryCache[cleanWord]!);
      } else {
        translatedWords.add(word);
      }
    }

    return translatedWords.join(' ');
  }

  String translateToIndo(String text) {
    if (!isLoaded || dictionaryCache.isEmpty) return text;

    Map<String, String> reverseDict = {};
    dictionaryCache.forEach((indo, daerah) {
      reverseDict[daerah.toLowerCase()] = indo;
    });

    List<String> words = text.split(' ');
    List<String> translatedWords = [];

    for (String word in words) {
      String cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
      if (reverseDict.containsKey(cleanWord)) {
        translatedWords.add(reverseDict[cleanWord]!);
      } else {
        translatedWords.add(word);
      }
    }

    return translatedWords.join(' ');
  }

  String translateToLocal(String text) => translate(text);
}
