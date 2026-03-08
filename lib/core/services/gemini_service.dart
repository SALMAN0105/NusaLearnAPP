// lib/services/gemini_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Ganti dengan API Key Anda dari Google AI Studio
  static const String _apiKey = const String.fromEnvironment(
    'AIzaSyBBWYZYiiurK3lYoT_19CfhE1upOAVzvq0',
  );
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  /// Generate content menggunakan Gemini API
  Future<String> generateContent(String prompt) async {
    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.4,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final text = data['candidates'][0]['content']['parts'][0]['text'];
          return text ?? 'Maaf, tidak ada respons dari AI.';
        } else {
          return 'Maaf, AI tidak dapat memberikan jawaban untuk pertanyaan ini.';
        }
      } else {
        return 'Error: Gagal menghubungi server AI (Status: ${response.statusCode})';
      }
    } catch (e) {
      return 'Error: Terjadi kesalahan saat menghubungi AI - $e';
    }
  }
}
