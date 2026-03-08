import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/core/database/database_helper.dart';

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

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, double val, child) =>
                Transform.scale(scale: val, child: child),
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
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFFF8FAFC), width: 4),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF009688),
                      size: 40,
                    ),
                  ),
                  Text(
                    "Berhasil Disimpan!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Perubahan data profilmu sudah kami update ke sistem.",
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
                      onPressed: () {
                        Navigator.pop(context); // Tutup Dialog
                        Navigator.pop(context, true); // Kembali ke Profile Tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFF009688).withOpacity(0.3),
                      ),
                      child: Text(
                        "Oke, Lanjut",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.highlight_off_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Edit Data Diri",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF1E293B),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
                  ),
                  image: _localImageDisplay != null
                      ? DecorationImage(
                          image: FileImage(_localImageDisplay!),
                          fit: BoxFit.cover,
                        )
                      : (_serverImageUrlDisplay != null
                            ? DecorationImage(
                                image: NetworkImage(_serverImageUrlDisplay!),
                                fit: BoxFit.cover,
                              )
                            : null),
                ),
                child:
                    (_localImageDisplay == null &&
                        _serverImageUrlDisplay == null)
                    ? const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: Color(0xFF009688),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            _buildInputGroup(
              label: "Nama Lengkap",
              controller: _nameController,
            ),
            _buildInputGroup(
              label: "Username",
              controller: _usernameController,
            ),
            _buildReadOnlyInputGroup(
              label: "Asal Sekolah",
              controller: _schoolController,
            ),
            _buildReadOnlyInputGroup(
              label: "Kode Pos (Wilayah)",
              controller: _zipCodeController,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: _isLoading ? 0 : 4,
                  shadowColor: const Color(0xFF009688).withOpacity(0.2),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Simpan Perubahan",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF009688),
                  width: 1.5,
                ),
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
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F5F9).withOpacity(0.7),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
