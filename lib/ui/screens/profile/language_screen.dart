import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // State
  bool _useLocalLanguage = false;
  String? _userLanguageCode; // Kode bahasa (misal: 'tolaki')
  String? _userLanguageName; // Nama bahasa (misal: 'Bahasa Tolaki')

  bool _isDictionaryReady = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadLanguageSettings();
  }

  // --- LOGIC: LOAD SETTINGS ---
  Future<void> _loadLanguageSettings() async {
    final db = await DatabaseHelper.instance.database;
    final userList = await db.query('users', limit: 1);
    final user = userList.isNotEmpty ? userList.first : null;

    if (user != null) {
      _userLanguageCode = user['language_code'] as String?;
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

  // Helper untuk mengubah kode menjadi nama yang bagus
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
        return "Bahasa ${code[0].toUpperCase()}${code.substring(1)}"; // Capitalize
    }
  }

  // --- LOGIC: ACTION SWITCH LANGUAGE ---
  Future<void> _switchLanguage(bool useLocal) async {
    // Jika memilih bahasa daerah tapi kamus belum ada, tawarkan download
    if (useLocal && !_isDictionaryReady && _userLanguageCode != null) {
      _showDownloadConfirmation();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.switchLanguage(useLocal);

    if (success) {
      setState(() {
        _useLocalLanguage = useLocal;
      });

      if (mounted) {
        _showSuccessPopup(useLocal); // Tampilkan Pop Up Cantik
      }
    } else {
      _showErrorSnackBar("Gagal mengganti bahasa. Silakan coba lagi.");
    }
  }

  // --- LOGIC: DOWNLOAD DICTIONARY ---
  Future<void> _downloadDictionary() async {
    if (_userLanguageCode == null || _userLanguageCode == 'id') return;

    // Tutup dialog konfirmasi jika ada
    Navigator.of(context).pop();

    setState(() => _isDownloading = true);

    try {
      bool success = await DictionaryService().downloadDictionary(
        _userLanguageCode!,
      );
      await _loadLanguageSettings(); // Refresh status

      if (mounted) {
        if (success) {
          // Setelah download sukses, langsung aktifkan bahasanya
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

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // --- UI: POP UP DIALOGS ---

  void _showDownloadConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Kamus Belum Tersedia",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Anda perlu mengunduh kamus $_userLanguageName terlebih dahulu untuk menggunakannya secara offline.",
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Batal",
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _downloadDictionary,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
            ),
            child: Text(
              "Download Sekarang",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
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
                    color: Colors.black.withOpacity(0.1),
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
                      color: Color(0xFFE0F2F1), // Teal Soft
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: Color(0xFF009688),
                      size: 40,
                    ),
                  ),
                  Text(
                    "Bahasa Diganti!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
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
                        elevation: 0,
                      ),
                      child: Text(
                        "Oke, Mengerti",
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

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Bahasa Aplikasi",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
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
      body: _isDownloading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF009688)),
                  const SizedBox(height: 16),
                  Text(
                    "Sedang mengunduh kamus...",
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: BAHASA UTAMA
                  _buildSectionTitle("Bahasa Utama"),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: _buildLanguageItem(
                      title: "Bahasa Indonesia",
                      subtitle: "Default System",
                      flagWidget: const Text(
                        "🇮🇩",
                        style: TextStyle(fontSize: 24),
                      ),
                      isActive: !_useLocalLanguage,
                      onTap: () => _switchLanguage(false),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: BAHASA DAERAH
                  _buildSectionTitle("Bahasa Daerah (Adaptif)"),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: _buildLanguageItem(
                      // Gunakan Nama Bahasa yang sudah diformat, default 'Bahasa Daerah' jika null
                      title: _userLanguageName ?? "Bahasa Daerah",
                      subtitle: _isDictionaryReady
                          ? "Siap digunakan"
                          : "Perlu diunduh (${_userLanguageCode ?? '-'})",
                      flagWidget: Container(
                        width: 40,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF009688),
                          size: 18,
                        ),
                      ),
                      isActive: _useLocalLanguage,
                      onTap: () => _switchLanguage(true),
                      showDownloadIcon:
                          !_isDictionaryReady &&
                          _userLanguageCode != null &&
                          _userLanguageCode != 'id',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageItem({
    required String title,
    required String subtitle,
    required Widget flagWidget,
    required bool isActive,
    required VoidCallback onTap,
    bool showDownloadIcon = false,
  }) {
    return Material(
      color: isActive
          ? const Color(0xFFE0F2F1)
          : Colors.transparent, // Active BG Color
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isActive
              ? BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF009688).withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Row(
            children: [
              // Flag Box
              Container(
                width: 44,
                height: 36,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                alignment: Alignment.center,
                child: flagWidget,
              ),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF009688)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Icons (Check or Download)
              if (showDownloadIcon)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                )
              else if (isActive)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF009688),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
