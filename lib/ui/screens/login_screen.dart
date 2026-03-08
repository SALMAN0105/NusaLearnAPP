import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/dashboard_screen.dart';
import 'package:nusalearn/ui/screens/register_screen.dart';
import 'package:nusalearn/ui/widgets/custom_widgets.dart';

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

  // ==========================================
  // LOGIKA ASLI ANDA (TIDAK DISENTUH)
  // ==========================================
  void _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      showCustomSnackbar(
        context,
        "Isi username & password dulu ya!",
        isError: true,
      );
      return;
    }

    bool success = await authProvider.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      showCustomSnackbar(context, "Selamat Datang Kembali!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      if (mounted) {
        showCustomSnackbar(
          context,
          "Username atau Password salah nih.",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Tombol Back di Kiri
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
                                // Logo dan Teks di Tengah (DIJAMIN TIDAK AKAN MELIPAT)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryDark,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.school_rounded,
                                          color: AppColors.accentLime,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    RichText(
                                      text: TextSpan(
                                        text: 'NusaLearn',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 28,
                                          color: AppColors.primaryDark,
                                          letterSpacing: -0.5,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '.',
                                            style: TextStyle(
                                              color: AppColors.brandPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
