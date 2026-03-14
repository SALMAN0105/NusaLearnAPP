import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusalearn/core/api/api_client.dart';
import 'package:nusalearn/ui/screens/login_screen.dart'; // Import Login Screen

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0;

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // State Variables
  bool _isLoading = false;

  // Visibility States
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // === LOGIC API GANTI PASSWORD (TIDAK DISENTUH) ===
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi manual: Konfirmasi password harus sama
    if (_newPassController.text != _confirmPassController.text) {
      _showErrorSnackBar(
        "Konfirmasi password tidak cocok dengan password baru.",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.getClient().post(
        '/change-password',
        data: {
          'current_password': _oldPassController.text,
          'new_password': _newPassController.text,
          'new_password_confirmation': _confirmPassController.text,
        },
      );

      if (response.data['status'] == 'success') {
        if (mounted) {
          _showSuccessDialog();
        }
      }
    } on DioException catch (e) {
      String err = "Gagal mengganti password";
      if (e.response != null) {
        // Ambil pesan error spesifik dari backend (misal: password lama salah)
        err = e.response?.data['message'] ?? err;
      }
      if (mounted) _showErrorSnackBar(err);
    } catch (e) {
      if (mounted) _showErrorSnackBar("Terjadi kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // === AKHIR LOGIC ===

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
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User harus klik tombol Login Ulang
      builder: (context) {
        return PopScope(
          canPop: false, // Mencegah tombol back
          child: Dialog(
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
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 24,
                ),
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
                        Icons.lock_reset_rounded,
                        color: kBlack,
                        size: 40,
                      ),
                    ),
                    Text(
                      "Sandi Berhasil Diganti!",
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
                      "Akunmu sudah aman sekarang. Silakan login ulang dengan kata sandi baru.",
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
                          // Logika navigasi tidak diubah
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
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
                            "LOGIN ULANG",
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
                // Custom App Bar Neo-Brutalism
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
                        "Ganti Kata Sandi",
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

                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Helper Text (Info Box Neo-Brutalism)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: kBlack,
                                width: kBorderWidth,
                              ),
                              boxShadow: const [
                                BoxShadow(color: kBlack, offset: Offset(4, 4)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: kBlack,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Gunakan minimal 8 karakter dengan kombinasi huruf dan angka agar akunmu lebih aman.",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: kBlack,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          _buildPasswordField(
                            controller: _oldPassController,
                            label: "KATA SANDI LAMA",
                            hint: "Masukkan sandi saat ini",
                            obscureText: _obscureOld,
                            onToggleVisibility: () =>
                                setState(() => _obscureOld = !_obscureOld),
                          ),

                          _buildPasswordField(
                            controller: _newPassController,
                            label: "KATA SANDI BARU",
                            hint: "Buat sandi baru yang kuat",
                            obscureText: _obscureNew,
                            onToggleVisibility: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),

                          _buildPasswordField(
                            controller: _confirmPassController,
                            label: "KONFIRMASI SANDI BARU",
                            hint: "Ulangi sandi baru",
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return "Tidak boleh kosong";
                              }
                              if (val != _newPassController.text) {
                                return "Sandi tidak cocok";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Submit Button Neo-Brutalism
                          GestureDetector(
                            onTap: _isLoading ? null : _submit,
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
                                    ? [] // Hilangkan shadow saat disable/loading
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
                                      Icons.lock_rounded,
                                      color: kBlack,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "UPDATE PASSWORD",
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
                          const SizedBox(height: 40), // Ruang ekstra di bawah
                        ],
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

  // --- WIDGET HELPER ---
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
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
            obscureText: obscureText,
            validator:
                validator ??
                (value) => value!.isEmpty ? "Tidak boleh kosong" : null,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: kBlack,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                color: kBlack.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: kWhite,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFFF4C4C), // Merah brutal
                  width: kBorderWidth,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFFF4C4C),
                  width: 3.0,
                ),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: kBlack,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
