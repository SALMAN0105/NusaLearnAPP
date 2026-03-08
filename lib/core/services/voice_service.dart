import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ TAMBAH INI

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool get isListening => _isListening;

  // ✅ TAMBAH: Method untuk request permission
  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      // Request permission jika belum dikasih
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      // User menolak permanent, arahkan ke settings
      print("❌ Mic Permission Permanently Denied. Please enable in settings.");
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  Future<void> init() async {
    if (!_isInitialized) {
      try {
        // ✅ FIX: Request permission dulu sebelum initialize
        bool hasPermission = await _requestMicPermission();

        if (!hasPermission) {
          print("❌ Mic permission not granted");
          return;
        }

        bool available = await _speech.initialize(
          onError: (e) => print('Mic Error: $e'),
          onStatus: (status) => print('Speech Status: $status'), // ✅ TAMBAH LOG
        );

        if (!available) {
          print("❌ Speech recognition not available");
          return;
        }

        await _flutterTts.setLanguage("id-ID");
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.5);

        _isInitialized = true;
        print("✅ Voice Service Initialized Successfully");
      } catch (e) {
        print("❌ Init Voice Gagal: $e");
      }
    }
  }

  Future<void> startListening({required Function(String) onResult}) async {
    if (!_isInitialized) await init();

    // ✅ FIX: Cek permission lagi sebelum listen
    bool hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      print("❌ Cannot start listening: No microphone permission");
      return;
    }

    if (!_isListening && _speech.isAvailable) {
      _isListening = true;
      print("🎤 Starting to listen...");

      _speech.listen(
        localeId: "id_ID",
        onResult: (val) {
          print("📝 Recognized: ${val.recognizedWords}");
          onResult(val.recognizedWords);
        },
        listenFor: Duration(seconds: 30), // ✅ TAMBAH: Timeout
        pauseFor: Duration(seconds: 3), // ✅ TAMBAH: Pause detection
      );
    } else {
      print("⚠️ Speech not available or already listening");
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      print("🛑 Stopped listening");
    }
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }
}
