import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0;

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // === LOGIC INTI (TIDAK DISENTUH) ===
  bool _useLocalLanguage = false;
  String? _userLanguageCode;
  String? _userLanguageName;

  bool _isDictionaryReady = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadLanguageSettings();
  }

  Future<void> _loadLanguageSettings() async {
    final db = await DatabaseHelper.instance.database;
    final userList = await db.query('pengguna', limit: 1);
    final user = userList.isNotEmpty ? userList.first : null;

    if (user != null) {
      _userLanguageCode = user['kode_bahasa'] as String?;
      _userLanguageName = _getLanguageName(_userLanguageCode);

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      String? savedPref = prefs.getString('pref_language');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String effectiveLang = authProvider.activeLanguage;
      if (effectiveLang == 'id' && savedPref != null && savedPref != 'id') {
        await authProvider.initUserLanguage();
        effectiveLang = authProvider.activeLanguage;
      }

      _useLocalLanguage = (effectiveLang != 'id');

      if (_userLanguageCode != null && _userLanguageCode != 'id') {
        _isDictionaryReady = await DictionaryService().isDictionaryDownloaded(
          _userLanguageCode!,
        );
      }
    }
    if (mounted) setState(() {});
  }

  String _getLanguageName(String? code) {
    if (code == null) return "Bahasa Daerah";
    switch (code.toLowerCase()) {
      case 'tolaki':
        return "Bahasa Tolaki";
      case 'bugis':
        return "Bahasa Bugis";
      case 'muna':
        return "Bahasa Muna";
      case 'jav':
        return "Bahasa Jawa";
      case 'sun':
        return "Bahasa Sunda";
      default:
        return "Bahasa ${code[0].toUpperCase()}${code.substring(1)}";
    }
  }

  Future<void> _switchLanguage(bool useLocal) async {
    if (useLocal && !_isDictionaryReady && _userLanguageCode != null) {
      _showDownloadConfirmation();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.switchLanguage(useLocal);

    if (success) {
      setState(() => _useLocalLanguage = useLocal);
      if (mounted) _showSuccessPopup(useLocal);
    } else {
      _showErrorSnackBar("Gagal mengganti bahasa. Silakan coba lagi.");
    }
  }

  Future<void> _downloadDictionary() async {
    if (_userLanguageCode == null || _userLanguageCode == 'id') return;

    Navigator.of(context).pop();
    setState(() => _isDownloading = true);

    try {
      bool success = await DictionaryService().downloadDictionary(
        _userLanguageCode!,
      );
      await _loadLanguageSettings();

      if (mounted) {
        if (success) {
          _switchLanguage(true);
        } else {
          _showErrorSnackBar("Gagal mengunduh kamus.");
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
  // === AKHIR LOGIC INTI ===

  // === UI UPDATE: SNACKBAR NEO-BRUTALISM ===
  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kWhite,
          ),
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

  // === UI UPDATE: DIALOGS NEO-BRUTALISM ===
  void _showDownloadConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBlack, width: kBorderWidth),
            boxShadow: const [BoxShadow(color: kBlack, offset: Offset(8, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDEB3), // Orange pastel
                  shape: BoxShape.circle,
                  border: Border.all(color: kBlack, width: kBorderWidth),
                  boxShadow: const [
                    BoxShadow(color: kBlack, offset: Offset(4, 4)),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_download_rounded,
                  color: kBlack,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Kamus Belum Tersedia",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kBlack,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Anda perlu mengunduh kamus $_userLanguageName terlebih dahulu untuk menggunakannya secara offline.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kBlack.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(2, 2)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Batal",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            color: kBlack,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _downloadDictionary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(2, 2)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Download",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            color: kBlack,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessPopup(bool isLocal) {
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBlack, width: kBorderWidth),
                      boxShadow: const [
                        BoxShadow(color: kBlack, offset: Offset(4, 4)),
                      ],
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: kBlack,
                      size: 40,
                    ),
                  ),
                  Text(
                    "Bahasa Diubah!",
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
                    isLocal
                        ? "Aplikasi sekarang menggunakan $_userLanguageName."
                        : "Aplikasi kembali menggunakan Bahasa Indonesia.",
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
                          "OKE, MENGERTI",
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
                        "Bahasa Aplikasi",
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
                  child: _isDownloading
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: kWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: kBlack,
                                width: kBorderWidth,
                              ),
                              boxShadow: const [
                                BoxShadow(color: kBlack, offset: Offset(4, 4)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: kBlack,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Mengunduh Kamus...",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: kBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("BAHASA UTAMA"),
                              _buildLanguageItem(
                                title: "Bahasa Indonesia",
                                subtitle: "Default System",
                                flagWidget: const Text(
                                  "🇮🇩",
                                  style: TextStyle(fontSize: 24),
                                ),
                                aktif: !_useLocalLanguage,
                                onTap: () => _switchLanguage(false),
                              ),
                              const SizedBox(height: 32),

                              _buildSectionTitle("BAHASA DAERAH (ADAPTIF AI)"),
                              _buildLanguageItem(
                                title: _userLanguageName ?? "Bahasa Daerah",
                                subtitle: _isDictionaryReady
                                    ? "Siap digunakan"
                                    : "Perlu diunduh (${_userLanguageCode ?? '-'})",
                                flagWidget: const Icon(
                                  Icons.my_location_rounded,
                                  color: kBlack,
                                  size: 20,
                                ),
                                flagBg: kPurple,
                                aktif: _useLocalLanguage,
                                onTap: () => _switchLanguage(true),
                                showDownloadIcon:
                                    !_isDictionaryReady &&
                                    _userLanguageCode != null &&
                                    _userLanguageCode != 'id',
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: kBlack,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageItem({
    required String title,
    required String subtitle,
    required Widget flagWidget,
    Color flagBg = kWhite,
    required bool aktif,
    required VoidCallback onTap,
    bool showDownloadIcon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: aktif ? kLime : kWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlack, width: kBorderWidth),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 42,
              decoration: BoxDecoration(
                color: flagBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBlack, width: 1.5),
              ),
              alignment: Alignment.center,
              child: flagWidget,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kBlack.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (showDownloadIcon)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDEB3), // Orange paste
                  shape: BoxShape.circle,
                  border: Border.all(color: kBlack, width: 1.5),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: kBlack,
                  size: 20,
                ),
              )
            else
              Icon(
                Icons.check_circle_rounded,
                color: aktif ? kBlack : Colors.transparent,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
