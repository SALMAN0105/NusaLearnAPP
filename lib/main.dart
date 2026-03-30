import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/core/services/network_sync_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/login_screen.dart';
import 'package:nusalearn/ui/screens/dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nusalearn/core/services/tflite_service.dart';
// Hapus import splash_screen.dart terpisah, kita buat terintegrasi di sini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NetworkAwareSyncManager().initialize();
  await TFLiteService().loadModel();
  var micStatus = await Permission.microphone.status;
  print("🎤 Microphone Permission: $micStatus");
  runApp(const NusaLearn());
}

class NusaLearn extends StatelessWidget {
  const NusaLearn({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'NusaLearn',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        // AuthChecker sekarang akan berfungsi sekaligus sebagai Splash Screen
        home: const AuthChecker(),
      ),
    );
  }
}

// =========================================================
// AUTH CHECKER SEKALIGUS SPLASH SCREEN
// =========================================================
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Future<bool> _loginCheckFuture;

  @override
  void initState() {
    super.initState();
    // 1. Setup Animasi Pulse untuk Logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Mulai proses pengecekan (Logika Asli Anda dipertahankan)
    _loginCheckFuture = _checkLoginStatusAndDelay();
  }

  // Modifikasi fungsi asli Anda dengan penambahan delay visual agar animasi terlihat
  Future<bool> _checkLoginStatusAndDelay() async {
    // Memberikan waktu minimum 2 detik agar splash screen terlihat
    final minDelay = Future.delayed(const Duration(seconds: 2));

    // Logika asli Anda
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final hasToken = prefs.getString('auth_token') != null;

    if (hasToken && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initUserLanguage();
    }

    // Tunggu animasi minimum selesai, atau proses pengecekan selesai (mana yang lebih lama)
    await minDelay;
    return hasToken;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loginCheckFuture,
      builder: (context, snapshot) {
        // TAMPILAN SPLASH SCREEN SAAT PROSES INISIALISASI
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF121221), // Primary Dark
            body: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Color(0xFFD4FF5B), // Accent Lime
                ),
              ),
            ),
          );
        }

        // TAMPILAN JIKA TERJADI ERROR PADA FUTURE
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text("Terjadi kesalahan inisialisasi: ${snapshot.error}"),
            ),
          );
        }

        // ROUTING BERDASARKAN HASIL PENGECEKAN (Logika Asli Anda)
        if (snapshot.data == true) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
