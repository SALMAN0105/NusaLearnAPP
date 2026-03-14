import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/ui/screens/login_screen.dart';
import 'package:path_provider/path_provider.dart';

// Import Core & API
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/sync_service.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';

// Import Screens Lain
import 'package:nusalearn/ui/screens/profile/edit_profile_screen.dart';
import 'package:nusalearn/ui/screens/profile/change_password_screen.dart';
import 'package:nusalearn/ui/screens/profile/language_screen.dart';
import 'package:nusalearn/ui/screens/profile/help_center_screen.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0; // Ketebalan border tegas khas brutalism

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with TickerProviderStateMixin {
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  String _userName = "Memuat...";
  String _school = "...";
  File? _localImage;
  String? _serverImageUrl;

  int _currentLevel = 1;
  int _totalXP = 0;

  bool _isUploadingImage = false;
  bool _isLoadingData = true;

  AnimationController? _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadUser();
  }

  @override
  void dispose() {
    _spinController?.dispose();
    super.dispose();
  }

  void _loadUser() async {
    final db = await DatabaseHelper.instance.database;
    final userResult = await db.query('users', limit: 1);

    if (userResult.isNotEmpty) {
      final user = userResult.first;
      setState(() {
        // ✅ FIX: Tambahkan 'as String?' agar tipe data sesuai
        _userName = (user['name'] as String?) ?? "Siswa";
        _school = (user['school_origin'] as String?) ?? "Belum ada sekolah";

        String? localPath = user['local_image_path'] as String?;
        if (localPath != null && File(localPath).existsSync()) {
          _localImage = File(localPath);
        }

        _serverImageUrl = user['image_url'] as String?;
      });

      // Hitung Level & XP
      int? userId = user['id'] as int?;
      if (userId != null) {
        int calculatedLevel = await AdaptiveService().calculateStudentLevel(
          userId,
        );
        final xpResult = await db.rawQuery(
          'SELECT COUNT(*) as total FROM student_progress WHERE user_id = ? AND is_correct = 1',
          [userId],
        );
        setState(() {
          _currentLevel = calculatedLevel;
          _totalXP = xpResult.first['total'] as int? ?? 0;
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isLoadingData = false);
  }

  // Ganti fungsi _pickAndUploadImage dengan ini:
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      // 1. Cek dulu, kalau user batal pilih, jangan lakukan apa-apa
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      // 2. HAPUS FILE LAMA (Hanya jika user sudah pilih foto baru)
      // Ini penting agar memori HP siswa SD tidak penuh karena sampah foto lama
      if (_localImage != null && await _localImage!.exists()) {
        try {
          await _localImage!.delete();
        } catch (e) {
          /* ignore */
        }
      }

      // 3. SIMPAN PERMANEN KE DOKUMEN APLIKASI
      final dir = await getApplicationDocumentsDirectory();
      final fileName = "profile_${DateTime.now().millisecondsSinceEpoch}.png";
      final permanentFile = await File(
        pickedFile.path,
      ).copy('${dir.path}/$fileName');

      // 4. UPDATE SQLITE (Data Utama)
      final db = await DatabaseHelper.instance.database;
      await db.update('users', {
        'local_image_path': permanentFile.path,
        'is_synced': 0, // Tandai butuh upload
      }, where: 'id IS NOT NULL');

      // 5. UPDATE UI INSTAN
      setState(() {
        _localImage = permanentFile;
      });

      // 6. SYNC BACKGROUND (Tanpa await, biar UI tidak freeze)
      SyncService().syncPendingProfile();

      _showSnackBar("Profil disimpan offline & sedang menyinkronkan...");
    } catch (e) {
      _showSnackBar("Gagal memproses foto", isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: isError ? Colors.white : kBlack,
          ),
        ),
        backgroundColor: isError ? const Color(0xFFFF4C4C) : kLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: kBlack, width: kBorderWidth),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _logout() async {
    if (mounted) setState(() => _isLoadingData = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_id');
      await prefs.remove('is_logged_in');

      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        await txn.delete('users');
        await txn.delete('student_progress');
        await txn.delete('recent_materials');
      });

      _localImage = null;
      _serverImageUrl = null;

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        _showSnackBar("Gagal membersihkan memori logout: $e", isError: true);
      }
    }
  }

  Future<void> _navigateTo(Widget page) async {
    bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    if (result == true) {
      _loadUser();
    }
  }

  Future<void> _handleForceSync() async {
    _showSnackBar("🔄 Memaksa Full Sync...");
    try {
      final db = await DatabaseHelper.instance.database;
      final userList = await db.query('users', limit: 1);
      final user = userList.isNotEmpty ? userList.first : null;
      String userLang = user?['language_code'] as String? ?? 'id';

      await SyncService().syncAll(userLang, force: true);

      if (mounted) _showSnackBar("✅ Full Sync Selesai!");
    } catch (e) {
      if (mounted) _showSnackBar("❌ Error: $e", isError: true);
    }
  }
  // === AKHIR LOGIKA INTI ===

  // === UI UPDATE: LOADER (GLASSMORPHISM) ===
  Widget _buildGlassmorphismLoader() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kLime,
                  border: Border.all(color: kBlack, width: kBorderWidth),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: kBlack, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _spinController ?? const AlwaysStoppedAnimation(0),
                      child: const Icon(Icons.face_rounded, color: kBlack),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Memuat Profil",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: kBlack,
                      ),
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

  // === UI UPDATE: DIALOG SUCCESS NEO-BRUTALISM ===
  void _showSuccessPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, double val, child) {
              return Transform.scale(scale: val, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(
                  32,
                ), // Border Radius yang lebih besar dari HTML
                border: Border.all(color: kBlack, width: kBorderWidth),
                boxShadow: const [
                  BoxShadow(color: kBlack, offset: Offset(8, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: kLime, // Accent Lime
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBlack, width: kBorderWidth),
                      boxShadow: const [
                        BoxShadow(color: kBlack, offset: Offset(4, 4)),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: kBlack,
                      size: 40,
                    ),
                  ),
                  Text(
                    "Berhasil Diupdate!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Data dirimu sudah kami simpan. Sekarang tampilan profilmu makin mantap!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6B6B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: kPurple,
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(4, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "OKE, SIAP!",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: kBlack,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // === UI BUILD ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      body: Stack(
        children: [
          // Background Gradient Neo-Brutalism
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAE0FF), Color(0xFFD8C3FF)],
              ),
            ),
          ),
          CustomPaint(painter: GridPainter(), child: Container()),

          SafeArea(
            child: Column(
              children: [
                // HEADER TITLE
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                  child: Center(
                    child: Text(
                      "Profil Saya",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: kBlack,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(
                          height: 10,
                        ), // Spacing after profile card

                        _buildSectionTitle("Akun & Keamanan"),
                        _buildMenuItem(
                          icon: Icons.person_rounded,
                          title: "Edit Data Diri",
                          bgColor: const Color(0xFFB3E5FF), // Blue
                          onTap: () => _navigateTo(const EditProfileScreen()),
                        ),
                        _buildMenuItem(
                          icon: Icons.lock_rounded,
                          title: "Ganti Kata Sandi",
                          bgColor: kPurple, // Purple
                          onTap: () =>
                              _navigateTo(const ChangePasswordScreen()),
                        ),

                        _buildSectionTitle("Umum"),
                        _buildMenuItem(
                          icon: Icons.language_rounded,
                          title: "Bahasa Aplikasi",
                          bgColor: kLime, // Teal/Lime
                          onTap: () => _navigateTo(const LanguageScreen()),
                        ),
                        _buildMenuItem(
                          icon: Icons.help_rounded,
                          title: "Pusat Bantuan",
                          bgColor: const Color(0xFFFFB3D9), // Pink
                          onTap: () => _navigateTo(const HelpCenterScreen()),
                        ),

                        _buildSectionTitle("Developer Zone"),
                        _buildMenuItem(
                          icon: Icons.sync_rounded,
                          title: "Force Delta Sync",
                          bgColor: const Color(0xFFFFDEB3), // Orange
                          onTap: _handleForceSync,
                        ),

                        const SizedBox(height: 20),
                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoadingData) _buildGlassmorphismLoader(),
        ],
      ),
    );
  }

  // === WIDGET HELPER METHODS (Neo-Brutalism) ===

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.only(top: 45, bottom: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: BoxDecoration(
              color: kPurple,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kBlack, width: kBorderWidth),
              boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
            ),
            child: Column(
              children: [
                Text(
                  _userName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kBlack,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _school,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kBlack.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildStatBox(
                      icon: Icons.military_tech_rounded,
                      iconColor: const Color(0xFFFFC107),
                      value: "Lv. $_currentLevel",
                      label: "Master",
                    ),
                    const SizedBox(width: 12),
                    _buildStatBox(
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      value: "$_totalXP",
                      label: "Total XP",
                    ),
                    const SizedBox(width: 12),
                    _buildStatBox(
                      icon: Icons.verified_rounded,
                      iconColor: const Color(0xFF2196F3),
                      value: "12", // Data statis atau sesuaikan variabel
                      label: "Selesai",
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Avatar Menumpuk (Overlapping)
          Positioned(
            top: -45,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(
                      24,
                    ), // Sesuai dengan referensi HTML HTML border-radius: 24px
                    border: Border.all(color: kBlack, width: kBorderWidth),
                    boxShadow: const [
                      BoxShadow(color: kBlack, offset: Offset(4, 4)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _localImage != null
                        ? Image.file(_localImage!, fit: BoxFit.cover)
                        : (_serverImageUrl != null
                              ? Image.network(
                                  _serverImageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 56,
                                  color: kBlack.withOpacity(0.8),
                                )),
                  ),
                ),
                if (_isUploadingImage)
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: kBlack,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: -10,
                  right: -10,
                  child: GestureDetector(
                    onTap: _isUploadingImage ? null : _pickAndUploadImage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBlack, width: kBorderWidth),
                        boxShadow: const [
                          BoxShadow(color: kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: kBlack,
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

  Widget _buildStatBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBlack, width: kBorderWidth),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(2, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: kBlack.withOpacity(0.7),
                textStyle: const TextStyle(
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 4, bottom: 16, top: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: kBlack,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlack, width: kBorderWidth),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBlack, width: kBorderWidth),
              ),
              child: Icon(icon, color: kBlack, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kBlack,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kBlack, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4C4C), // Merah terang
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlack, width: kBorderWidth),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: kWhite, size: 20),
            const SizedBox(width: 8),
            Text(
              "KELUAR APLIKASI",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: kWhite,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- BACKGROUND GRID PAINTER ---
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    const double step = 32.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += step) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
