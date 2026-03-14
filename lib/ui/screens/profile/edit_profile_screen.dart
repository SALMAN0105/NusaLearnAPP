import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  File? _localImageDisplay;
  String? _serverImageUrlDisplay;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _schoolController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  // === LOGIC INTI (TIDAK DISENTUH) ===
  void _loadCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper.instance.database;

    setState(() {
      String? localPath = prefs.getString('user_image_path');
      if (localPath != null && File(localPath).existsSync()) {
        _localImageDisplay = File(localPath);
      }
      _serverImageUrlDisplay = prefs.getString('user_image_url');
    });

    final List<Map<String, dynamic>> maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      final user = maps.first;
      setState(() {
        _nameController.text = user['name'] as String? ?? "";
        _usernameController.text = user['username'] as String? ?? "";
        _schoolController.text =
            user['school_origin'] as String? ?? "Belum terdaftar";
        _zipCodeController.text = user['postal_code'] as String? ?? "-";
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      FormData formData = FormData.fromMap({
        'name': _nameController.text,
        'username': _usernameController.text,
      });

      final response = await ApiClient.getClient().post(
        '/update-profile',
        data: formData,
      );

      if (response.data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final db = await DatabaseHelper.instance.database;

        await prefs.setString('user_name', _nameController.text);
        await prefs.setString('user_username', _usernameController.text);

        await db.update(
          'users',
          {'name': _nameController.text, 'username': _usernameController.text},
          where: 'id = ?',
          whereArgs: [1],
        );

        if (mounted) _showSuccessPopup();
      }
    } on DioException catch (e) {
      String err = "Gagal mengupdate profil";
      if (e.response != null) {
        err = e.response?.data['message'] ?? err;
        if (e.response?.data['errors'] != null) {
          var errors = e.response?.data['errors'];
          if (errors['username'] != null) err = errors['username'][0];
        }
      }
      if (mounted) _showErrorSnackBar(err);
    } catch (e) {
      if (mounted) _showErrorSnackBar("Terjadi kesalahan sistem: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // === AKHIR LOGIC INTI ===

  // === UI UPDATE: SNACKBAR NEO-BRUTALISM ===
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: kWhite, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: kWhite,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF4C4C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBlack, width: kBorderWidth),
        ),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  // === UI UPDATE: DIALOG SUCCESS NEO-BRUTALISM ===
  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, double val, child) =>
                Transform.scale(scale: val, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(32),
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
                      color: kLime,
                      shape: BoxShape.circle,
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
                    "Berhasil Disimpan!",
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
                    "Perubahan data profilmu sudah kami update ke sistem.",
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
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: kPurple,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(4, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "OKE, LANJUT",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAE0FF), Color(0xFFD8C3FF)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kBlack,
                              width: kBorderWidth,
                            ),
                            boxShadow: const [
                              BoxShadow(color: kBlack, offset: Offset(2, 2)),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: kBlack,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Edit Data Diri",
                        style: GoogleFonts.plusJakartaSans(
                          color: kBlack,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: kBlack,
                                    width: kBorderWidth,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: kBlack,
                                      offset: Offset(4, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: _localImageDisplay != null
                                      ? Image.file(
                                          _localImageDisplay!,
                                          fit: BoxFit.cover,
                                        )
                                      : (_serverImageUrlDisplay != null
                                            ? Image.network(
                                                _serverImageUrlDisplay!,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.person_rounded,
                                                size: 48,
                                                color: kBlack.withOpacity(0.5),
                                              )),
                                ),
                              ),
                              Positioned(
                                bottom: -10,
                                right: -10,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: kPurple,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: kBlack,
                                      width: kBorderWidth,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: kBlack,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 20,
                                    color: kBlack,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        _buildInputGroup(
                          label: "NAMA LENGKAP",
                          controller: _nameController,
                        ),
                        _buildInputGroup(
                          label: "USERNAME",
                          controller: _usernameController,
                        ),

                        _buildReadOnlyInputGroup(
                          label: "ASAL SEKOLAH",
                          controller: _schoolController,
                        ),
                        _buildReadOnlyInputGroup(
                          label: "KODE POS",
                          controller: _zipCodeController,
                        ),

                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _isLoading ? null : _saveProfile,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: _isLoading ? kWhite : kLime,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: kBlack,
                                width: kBorderWidth,
                              ),
                              boxShadow: _isLoading
                                  ? []
                                  : const [
                                      BoxShadow(
                                        color: kBlack,
                                        offset: Offset(4, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading)
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: kBlack,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                else ...[
                                  const Icon(
                                    Icons.save_rounded,
                                    color: kBlack,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "SIMPAN PERUBAHAN",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: kBlack,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildInputGroup({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: kBlack,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: kBlack,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: kWhite,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: kBlack,
                  width: kBorderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kBlack, width: 3.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyInputGroup({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kBlack,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "*Locked",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF4C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: kBlack.withOpacity(0.5),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: kWhite.withOpacity(0.5), // Semi transparent
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: kBlack.withOpacity(0.3),
                  width: kBorderWidth,
                  style: BorderStyle.solid,
                ), // Dashed effect can't be native, so we use opacity
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: kBlack.withOpacity(0.3),
                  width: kBorderWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
