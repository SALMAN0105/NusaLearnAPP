import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/dashboard_screen.dart';
import 'package:nusalearn/ui/screens/register_screen.dart';
import 'package:nusalearn/ui/widgets/custom_widgets.dart';

// ← TAMBAH DI SINI, setelah semua import
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kLime = Color(0xFFD2F945);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controller untuk animasi utama (Masuk/Entrance)
  late AnimationController _entranceController;
  late Animation<double> _fadeHeaderAnim;
  late Animation<Offset> _slideHeaderAnim;
  late Animation<double> _fadeImageAnim;
  late Animation<Offset> _slideImageAnim;
  late Animation<Offset> _slideSheetAnim;
  late Animation<double> _fadeFormAnim;

  // Controller untuk animasi melayang (Vektor)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // 1. SETUP ANIMASI MELAYANG (VEKTOR)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 2. SETUP ANIMASI MASUK (SMOOTH STAGGERED ENTRANCE)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Header (Logo & Judul) muncul & turun sedikit
    _fadeHeaderAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4),
      ),
    );
    _slideHeaderAnim =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
          ),
        );

    // Gambar Vektor muncul & naik sedikit
    _fadeImageAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6),
      ),
    );
    _slideImageAnim =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    // Bottom Sheet meluncur tinggi dari bawah layar
    _slideSheetAnim =
        Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
          ),
        );

    // Form elemen di dalam bottom sheet muncul perlahan
    _fadeFormAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0),
      ),
    );

    // Mulai animasi masuk saat layar dibuka
    _entranceController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _isDownloading = false;
  List<Map<String, dynamic>> _downloadSteps = [];
  double _overallProgress = 0.0;
  StreamSubscription? _progressSub;

  void _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty)
      return;

    // Subscribe ke stream progress SEBELUM login dipanggil
    _progressSub = authProvider.loginProgressStream.listen((data) {
      if (mounted) {
        setState(() {
          _overallProgress = data['progress'];

          // Update atau tambah step
          final idx = _downloadSteps.indexWhere(
            (s) => s['step'].toString().startsWith(
              data['status'] == 'loading' ? '' : data['step'].toString(),
            ),
          );

          if (data['status'] == 'loading') {
            // Tampilkan step yang sedang berjalan
            _downloadSteps = [
              ..._downloadSteps,
              {'step': data['step'], 'status': 'loading'},
            ];
          } else {
            // Update status step terakhir jadi success/error
            if (_downloadSteps.isNotEmpty) {
              final last = Map<String, dynamic>.from(_downloadSteps.last);
              last['step'] = data['step'];
              last['status'] = data['status'];
              _downloadSteps = [
                ..._downloadSteps.sublist(0, _downloadSteps.length - 1),
                last,
              ];
            }
          }
        });
      }
    });

    setState(() {
      _isDownloading = false;
      _downloadSteps = [];
      _overallProgress = 0.0;
    });

    bool success = await authProvider.login(
      _usernameController.text,
      _passwordController.text,
    );

    await _progressSub?.cancel();

    if (success && mounted) {
      showCustomSnackbar(context, "Login berhasil! Selamat belajar 🎉");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      // Penting: biarkan keyboard mendorong UI jika diperlukan, tapi kita atasi dengan SingleChildScrollView
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background Gradient & Grid
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFD6F5), Color(0xFFE6E0FF)],
              ),
            ),
          ),
          CustomPaint(size: Size.infinite, painter: GridPainter()),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ==========================================
                // BAGIAN ATAS (HEADER & VEKTOR) -> 42% LAYAR
                // ==========================================
                SizedBox(
                  height: screenHeight * 0.42,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. App Bar (Tombol Back, Logo, Teks)
                      FadeTransition(
                        opacity: _fadeHeaderAnim,
                        child: SlideTransition(
                          position: _slideHeaderAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            // GANTI DARI SINI (Baris 248 - 290)
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Tombol Back tetap di kiri
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),

                                // Logo dan Teks di Tengah (DIPERBAIKI)
                                // Berikan padding horizontal agar tidak menabrak tombol back
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width:
                                            40, // Ukuran disesuaikan agar proporsional
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryDark,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.school_rounded,
                                            color: AppColors.accentLime,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Flexible adalah kunci agar teks mau mengalah jika layar sempit
                                      Flexible(
                                        child: RichText(
                                          overflow: TextOverflow
                                              .ellipsis, // Tambahan keamanan
                                          text: TextSpan(
                                            text: 'NusaLearn',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w900,
                                              fontSize:
                                                  24, // Diturunkan ke 24 agar lebih aman
                                              color: AppColors.primaryDark,
                                              letterSpacing: -0.5,
                                            ),
                                            children: const [
                                              TextSpan(
                                                text: '.',
                                                style: TextStyle(
                                                  color: AppColors.brandPurple,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // SAMPAI SINI
                          ),
                        ),
                      ),

                      // 2. Gambar Vektor Melayang
                      FadeTransition(
                        opacity: _fadeImageAnim,
                        child: SlideTransition(
                          position: _slideImageAnim,
                          child: AnimatedBuilder(
                            animation: _floatAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatAnimation.value),
                                child: SizedBox(
                                  height: 160,
                                  child: Image.asset(
                                    'assets/images/a.png',
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              size: 80,
                                              color: AppColors.primaryDark,
                                            ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 3. Subtitle
                      FadeTransition(
                        opacity: _fadeImageAnim,
                        child: Text(
                          "Platform edukasi masa depan.",
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // BAGIAN BAWAH (BOTTOM SHEET FORM) -> SISA LAYAR
                // ==========================================
                Expanded(
                  child: SlideTransition(
                    position: _slideSheetAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 32,
                        left: 32,
                        right: 32,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, -10),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: 50,
                        ), // Ruang ekstra saat keyboard muncul
                        child: FadeTransition(
                          opacity: _fadeFormAnim,
                          child: Column(
                            children: [
                              // INPUT USERNAME (Dengan Placeholder Baru)
                              ModernTextField(
                                controller: _usernameController,
                                label: "Username",
                                hint: "Masukkan Username",
                                icon: Icons.alternate_email_rounded,
                              ),

                              // INPUT PASSWORD (Dengan Placeholder Baru)
                              ModernTextField(
                                controller: _passwordController,
                                label: "Password",
                                hint: "Masukkan Password",
                                icon: Icons.lock_rounded,
                                isPassword: true,
                              ),
                              const SizedBox(height: 10),

                              // TOMBOL MASUK
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return BouncyButton(
                                    text: "MASUK",
                                    isLoading: auth.isLoading,
                                    onPressed: auth.isLoading
                                        ? null
                                        : _handleLogin,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),

                              // LINK DAFTAR
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Belum memiliki akun? ",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    ),
                                    child: Text(
                                      "Daftar Sekarang",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.brandPurple,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 35),

                              // LOGO SPONSOR (ANTI OVERFLOW MENGGUNAKAN WRAP)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 20, // Jarak horizontal antar logo
                                runSpacing:
                                    10, // Jarak vertikal jika terpaksa turun baris
                                children: [
                                  _buildSponsorLogo('assets/images/stikom.jpg'),
                                  _buildSponsorLogo(
                                    'assets/images/diristek.png',
                                  ),
                                  _buildSponsorLogo(
                                    'assets/images/berdampak.png',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (authProvider.isLoading) _buildDownloadOverlay(),
        ],
      ),
    );
  }

  Widget _buildDownloadOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kWhite,
                  border: Border.all(color: kBlack, width: 1.5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: kBlack, offset: Offset(5, 5)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    // Header di dalam Download Overlay
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPurple,
                            border: Border.all(color: kBlack, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: kBlack,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // KUNCI PERBAIKAN: Bungkus Column teks dengan Expanded
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize
                                .min, // Tambahkan ini agar hemat ruang
                            children: [
                              Text(
                                "Menyiapkan Materi",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: kBlack,
                                ),
                                softWrap:
                                    true, // Pastikan teks bisa pindah baris
                              ),
                              Text(
                                "Hanya dilakukan sekali saat login pertama",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                                softWrap: true, // Tambahkan ini juga
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Overall Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _overallProgress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(kLime),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${(_overallProgress * 100).toInt()}%",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kBlack,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Step List
                    if (_downloadSteps.isEmpty)
                      _buildStepTile("Menghubungkan ke server...", "loading")
                    else
                      ..._downloadSteps.map(
                        (s) => _buildStepTile(s['step'], s['status']),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTile(String label, String status) {
    Widget icon;
    if (status == 'loading') {
      icon = const SizedBox(
        // Tambah const biar efisien
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: kBlack),
      );
    } else if (status == 'success') {
      icon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.green,
        size: 16,
      );
    } else {
      icon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 16);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment
            .start, // Agar icon tetap di atas jika teks berbaris-baris
        children: [
          icon,
          const SizedBox(width: 10),
          // KUNCI PERBAIKAN: Gunakan Expanded agar teks tidak "nendang" keluar layar
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status == 'error' ? Colors.red[700] : kBlack,
              ),
              // Jika masih kepanjangan, teks akan turun ke baris baru secara otomatis
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi helper untuk merender logo sponsor
  Widget _buildSponsorLogo(String path) {
    return SizedBox(
      height: 35, // Ukuran distabilkan agar sejajar rata
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.corporate_fare_rounded,
          color: Colors.grey,
          size: 30,
        ),
      ),
    );
  }
}
