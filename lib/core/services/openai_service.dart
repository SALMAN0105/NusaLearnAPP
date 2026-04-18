// lib/core/services/openai_service.dart
// Pengganti GeminiService menggunakan OpenAI-compatible API

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nusalearn/core/config/app_config.dart';

class OpenAIService {
  static String get _apiKey => AppConfig.openAIApiKey;
  static String get _baseUrl => AppConfig.openAIBaseUrl;
  static String get _model => AppConfig.aiModel;

  /// Generate konten menggunakan OpenAI-compatible API
  Future<String> generateContent(String prompt) async {
    if (_apiKey.isEmpty) {
      return 'Error: OPENAI_API_KEY belum dikonfigurasi di AppConfig.';
    }

    // Pastikan baseUrl tidak ada trailing slash
    final baseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;

    final url = Uri.parse('$baseUrl/chat/completions');

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Kamu adalah asisten pembelajaran yang membantu siswa memahami materi pelajaran. '
                      'Jawab hanya berdasarkan konteks materi yang diberikan. '
                      'Gunakan bahasa Indonesia yang mudah dipahami.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.4,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // ✅ FIX: Explicit cast agar tidak error _Map<dynamic, dynamic>
        final rawData = jsonDecode(utf8.decode(response.bodyBytes));
        final data = _castMap(rawData);

        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = _castMap(choices[0])['message'];
          if (message != null) {
            return (_castMap(message)['content'] as String?) ??
                'Maaf, tidak ada respons dari AI.';
          }
        }

        return 'Maaf, AI tidak dapat memberikan jawaban untuk pertanyaan ini.';
      } else {
        final rawError = jsonDecode(response.body);
        final errorData = _castMap(rawError);
        final errorMsg =
            (_castMap(errorData['error'] ?? {}))['message'] ??
            'Status ${response.statusCode}';
        print('❌ OpenAI Error: $errorMsg');
        return 'Error: Gagal menghubungi server AI ($errorMsg)';
      }
    } on http.ClientException catch (e) {
      print('❌ HTTP Client Error: $e');
      return 'Error: Tidak dapat terhubung ke server AI. Periksa koneksi internet.';
    } catch (e) {
      print('❌ OpenAI Exception: $e');
      return 'Error: Terjadi kesalahan saat menghubungi AI - $e';
    }
  }

  /// ✅ Helper: paksa konversi Map<dynamic,dynamic> → Map<String, dynamic>
  Map<String, dynamic> _castMap(dynamic input) {
    if (input == null) return {};
    if (input is Map<String, dynamic>) return input;
    if (input is Map) {
      return input.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }
}
