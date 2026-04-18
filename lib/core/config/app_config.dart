// lib/core/config/app_config.dart
// ⚠️ Jangan di-commit ke Git! Tambahkan file ini ke .gitignore

class AppConfig {
  // Ganti dengan API key kamu yang sebenarnya
  static const String openAIApiKey =
      'sk-o44DmAnE8ceq5OWSqECLINUi1ugCeTbWAdGYsPyh1QjBmXou';

  // Base URL dari .env Laravel kamu (OPENAI_BASE_URL)
  static const String openAIBaseUrl = 'https://api.chatanywhere.tech/v1';

  // Model yang dipakai — ganti jika provider kamu pakai nama lain
  static const String aiModel = 'gpt-4o-mini';
}
