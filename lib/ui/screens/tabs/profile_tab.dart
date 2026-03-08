import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/ui/screens/login_screen.dart';

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

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  // --- Variables & State ---
  String _userName = "User";
  String _school = "...";
  File? _localImage;
  String? _serverImageUrl;

  int _currentLevel = 1;
  int _totalXP = 0;

  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper.instance.database;

    setState(() {
      _userName = prefs.getString('user_name') ?? "Siswa";
      _school = prefs.getString('user_school') ?? "Belum ada sekolah";

      String? localPath = prefs.getString('user_image_path');
      if (localPath != null && File(localPath).existsSync()) {
        _localImage = File(localPath);
      } else {
        _localImage = null;
      }

      String? serverUrl = prefs.getString('user_image_url');
      if (serverUrl != null && serverUrl.startsWith('http')) {
        _serverImageUrl = serverUrl;
      } else {
        _serverImageUrl = null;
      }
    });

    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) {
      int userId = userResult.first['id'] as int;
      int calculatedLevel = await AdaptiveService().calculateStudentLevel(
        userId,
      );

      final xpResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM student_progress WHERE user_id = ? AND is_correct = 1',
        [userId],
      );
      int totalXP = xpResult.first['total'] as int? ?? 0;

      setState(() {
        _currentLevel = calculatedLevel;
        _totalXP = totalXP;
      });
    }
  }

  // --- LOGIC: GANTI FOTO ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        setState(() => _isUploadingImage = true);
        await _uploadImageToServer(imageFile);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) _showSnackBar("Gagal mengambil gambar", isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _uploadImageToServer(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;

      FormData formData = FormData.fromMap({
        'name': _userName,
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await ApiClient.getClient().post(
        '/update-profile',
        data: formData,
      );

      if (response.data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();

        if (response.data['data'] != null &&
            response.data['data']['image_url'] != null) {
          String newUrl = response.data['data']['image_url'];
          await prefs.setString('user_image_url', newUrl);
        }

        await prefs.remove('user_image_path');
        _loadUser();

        // ✅ FIXED: Sekarang memanggil Pop Up Sukses, BUKAN SnackBar
        if (mounted) _showSuccessPopup();
      }
    } on DioException catch (e) {
      String err = "Gagal upload foto";
      if (e.response != null) {
        err = e.response?.data['message'] ?? err;
      }
      if (mounted) _showSnackBar(err, isError: true);
    } catch (e) {
      if (mounted) _showSnackBar("Terjadi kesalahan sistem", isError: true);
    }
  }

  // --- HELPER DIALOGS ---

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, double val, child) {
              return Transform.scale(scale: val, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF009688),
                      size: 40,
                    ),
                  ),
                  Text(
                    "Profil Berhasil Diupdate!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Tampilan profilmu sekarang makin keren!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Mantap!",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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

  // --- NAVIGATION ---

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  Future<void> _navigateTo(Widget page) async {
    bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    // ✅ FIXED: Menghilangkan if (page is EditProfileScreen) _showSuccessPopup();
    // Hanya refresh data saja, karena EditProfileScreen sudah punya popup sendiri.
    if (result == true) {
      _loadUser();
    }
  }

  // --- LOGIC SYNC ---
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

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          _buildHeaderBackground(),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Profil Saya",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                _buildProfileCard(),
                const SizedBox(height: 30),
                _buildSectionTitle("Akun & Keamanan"),
                _buildMenuGroup([
                  _buildMenuItem(
                    icon: Icons.person_rounded,
                    title: "Edit Data Diri",
                    color: Colors.blue,
                    bgColor: Colors.blue.shade50,
                    onTap: () => _navigateTo(const EditProfileScreen()),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.lock_rounded,
                    title: "Ganti Kata Sandi",
                    color: Colors.purple,
                    bgColor: Colors.purple.shade50,
                    onTap: () => _navigateTo(const ChangePasswordScreen()),
                  ),
                ]),
                _buildSectionTitle("Umum"),
                _buildMenuGroup([
                  _buildMenuItem(
                    icon: Icons.language_rounded,
                    title: "Bahasa Aplikasi",
                    color: Colors.teal,
                    bgColor: Colors.teal.shade50,
                    onTap: () => _navigateTo(const LanguageScreen()),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.help_rounded,
                    title: "Pusat Bantuan",
                    color: Colors.redAccent,
                    bgColor: Colors.red.shade50,
                    onTap: () => _navigateTo(const HelpCenterScreen()),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle("Developer Zone"),
                _buildMenuGroup([
                  _buildMenuItem(
                    icon: Icons.sync_rounded,
                    title: "Force Delta Sync",
                    color: Colors.orange,
                    bgColor: Colors.orange.shade50,
                    onTap: _handleForceSync,
                  ),
                ]),
                const SizedBox(height: 10),
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER METHODS (Header, Card, dll sama seperti sebelumnya) ---

  Widget _buildHeaderBackground() {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF009688), Color(0xFF00796B)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -50, child: _buildDecoCircle(200)),
          Positioned(top: 100, left: -40, child: _buildDecoCircle(150)),
          Positioned(top: 40, right: 80, child: _buildDecoCircle(80)),
        ],
      ),
    );
  }

  Widget _buildDecoCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 50),
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            children: [
              Text(
                _userName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _school,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildStatBox(
                    icon: Icons.military_tech_rounded,
                    value: "Lv. $_currentLevel",
                    label: "Master",
                    iconColor: Colors.amber,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    icon: Icons.bolt_rounded,
                    value: "$_totalXP",
                    label: "Total XP",
                    iconColor: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    icon: Icons.verified_rounded,
                    value: "12",
                    label: "Selesai",
                    iconColor: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF009688).withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFE0F2F1),
                  backgroundImage: _localImage != null
                      ? FileImage(_localImage!) as ImageProvider
                      : (_serverImageUrl != null
                            ? NetworkImage(_serverImageUrl!)
                            : null),
                  child: (_isUploadingImage)
                      ? const CircularProgressIndicator(
                          color: Color(0xFF009688),
                        )
                      : ((_localImage == null && _serverImageUrl == null)
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xFF009688),
                              )
                            : null),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadImage,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
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
      margin: const EdgeInsets.only(left: 12, bottom: 12, top: 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
      indent: 70,
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      child: TextButton.icon(
        onPressed: _logout,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFECACA)),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
        label: Text(
          "Keluar Aplikasi",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }
}
