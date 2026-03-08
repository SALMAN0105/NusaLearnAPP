import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/widgets/custom_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// MENGGUNAKAN TickerProviderStateMixin KARENA ADA 2 ANIMASI BERSAMAAN
class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Animasi Melayang (Vektor)
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Animasi Masuk (Slide Up Bottom Sheet & Fade Header)
  late AnimationController _entranceController;
  late Animation<Offset> _sheetSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Animasi Vektor Melayang
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 2. Setup Animasi Masuk (Entrance)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Bottom sheet meluncur dari bawah (Offset Y = 1.0) ke posisi normal (Offset Y = 0.0)
    _sheetSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Header perlahan muncul (Fade In)
    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    // Jalankan animasi masuk saat halaman dibuka
    _entranceController.forward();

    // Memanggil API daftar sekolah saat halaman dibuka
    Future.microtask(
      () => Provider.of<AuthProvider>(context, listen: false).fetchSchools(),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _checkRegion() {
    if (_postalCodeController.text.length < 5) {
      showCustomSnackbar(
        context,
        "Kode Pos kurang lengkap nih!",
        isError: true,
      );
      return;
    }
    Provider.of<AuthProvider>(
      context,
      listen: false,
    ).checkRegion(_postalCodeController.text);
  }

  void _handleRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Validasi Wilayah
    if (auth.detectedDistrict == null) {
      showCustomSnackbar(context, "Cek Kode Pos Dulu yah!", isError: true);
      return;
    }

    // Validasi Sekolah
    if (_schoolController.text.isEmpty) {
      showCustomSnackbar(context, "Pilih asal sekolahmu dulu!", isError: true);
      return;
    }

    final data = {
      'name': _nameController.text,
      'username': _usernameController.text,
      'password': _passwordController.text,
      'school_origin': _schoolController.text,
      'postal_code': _postalCodeController.text,
    };

    bool success = await auth.register(data);

    if (success && mounted) {
      showCustomSnackbar(
        context,
        "Hore! Berhasil Daftar. Yuk Login!",
        isError: false,
      );
      Navigator.pop(context); // Kembali ke Login
    } else {
      if (mounted) {
        showCustomSnackbar(
          context,
          "Yah, Gagal Daftar. Coba username lain!",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // Background Gradient & Grid Neo-Brutalism
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAE0FF), Color(0xFFD8C3FF)],
              ),
            ),
          ),
          CustomPaint(size: Size.infinite, painter: GridPainter()),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // App Bar Custom Neo-Brutalism
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        "NusaLearn",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                      ), // Balancing agar title tetap di tengah
                    ],
                  ),
                ),

                // Header Content DIBUNGKUS FADE TRANSITION
                FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 26,
                                      color: AppColors.primaryDark,
                                      height: 1.1,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        'Teman ',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 26,
                                          color: AppColors.primaryDark,
                                          height: 1.1,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        color: AppColors.accentLime,
                                        child: Text(
                                          'Baru!',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 26,
                                            color: AppColors.primaryDark,
                                            height: 1.1,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Isi data dirimu biar kita bisa belajar bareng di NusaLearn.",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark.withOpacity(0.8),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Animasi Gambar Vektor Melayang
                        AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatAnimation.value),
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Image.asset(
                                  'assets/images/a.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: AppColors.primaryDark,
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Sheet DIBUNGKUS SLIDE TRANSITION (Meluncur Keren dari bawah)
                Expanded(
                  child: SlideTransition(
                    position: _sheetSlideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 32,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: AppColors.primaryDark,
                            width: 2,
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ModernTextField(
                              controller: _nameController,
                              label: "Nama Lengkap",
                              icon: Icons.face_rounded,
                            ),
                            ModernTextField(
                              controller: _usernameController,
                              label: "Username",
                              icon: Icons.alternate_email_rounded,
                            ),
                            ModernTextField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_rounded,
                              isPassword: true,
                            ),

                            // Dropdown Sekolah Neo-Brutalism
                            Text(
                              "ASAL SEKOLAH",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primaryDark,
                                      width: 2,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _schoolController.text.isEmpty
                                        ? null
                                        : _schoolController.text,
                                    hint: Text(
                                      "Pilih Asal Sekolah",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.textMuted,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_drop_down_circle_outlined,
                                      color: AppColors.brandPurple,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                        Icons.location_city_rounded,
                                        color: AppColors.brandPurple,
                                      ),
                                    ),
                                    isExpanded: true,
                                    items: auth.schoolList.map((String school) {
                                      return DropdownMenuItem<String>(
                                        value: school,
                                        child: Text(
                                          school,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _schoolController.text = newValue ?? "";
                                      });
                                    },
                                  ),
                                );
                              },
                            ),

                            // Region Checker Neo-Brutalism
                            Text(
                              "VALIDASI WILAYAH",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                final bool isSuccess =
                                    auth.detectedDistrict != null;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(16),
                                  transform: Matrix4.translationValues(
                                    isSuccess ? -2 : 0,
                                    isSuccess ? -2 : 0,
                                    0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSuccess
                                        ? AppColors.accentLime
                                        : const Color(0xFFF4F0FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primaryDark,
                                      width: 2,
                                    ),
                                    boxShadow: isSuccess
                                        ? const [
                                            BoxShadow(
                                              color: AppColors.primaryDark,
                                              offset: Offset(4, 4),
                                              blurRadius: 0,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSuccess
                                            ? "Lokasi Terverifikasi!"
                                            : "Cek Area Sekolahmu",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: AppColors.white,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: AppColors.primaryDark,
                                                  width: 2,
                                                ),
                                              ),
                                              child: TextField(
                                                controller:
                                                    _postalCodeController,
                                                keyboardType:
                                                    TextInputType.number,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  hintText:
                                                      "Kode Pos (Cth: 93575)",
                                                  hintStyle:
                                                      GoogleFonts.plusJakartaSans(
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: _checkRegion,
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: isSuccess
                                                    ? AppColors.white
                                                    : AppColors.brandPurple,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: AppColors.primaryDark,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color:
                                                        AppColors.primaryDark,
                                                    offset: Offset(2, 2),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                isSuccess
                                                    ? Icons.check_rounded
                                                    : Icons.search_rounded,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (auth.isLoading &&
                                          auth.detectedDistrict == null)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          height: 6,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.primaryDark,
                                              width: 2,
                                            ),
                                          ),
                                          child: const LinearProgressIndicator(
                                            color: AppColors.brandPurple,
                                            backgroundColor: Colors.transparent,
                                          ),
                                        ),
                                      if (isSuccess)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            top: 15,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: AppColors.primaryDark,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.verified_rounded,
                                                color: AppColors.primaryDark,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Wilayah: ${auth.detectedDistrict}",
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: AppColors
                                                                .primaryDark,
                                                          ),
                                                    ),
                                                    Text(
                                                      "Bahasa: ${auth.detectedLanguage}",
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .textMuted,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 30),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) => BouncyButton(
                                text: "DAFTAR SEKARANG",
                                isLoading: auth.isLoading,
                                onPressed:
                                    (auth.isLoading ||
                                        auth.detectedDistrict == null)
                                    ? null
                                    : _handleRegister,
                              ),
                            ),
                          ],
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
}
