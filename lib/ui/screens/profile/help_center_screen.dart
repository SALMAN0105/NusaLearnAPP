import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Pastikan package ini ada di pubspec.yaml

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // --- LOGIC: URL LAUNCHER ---
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  void _contactWhatsApp() {
    // Ganti nomor ini dengan nomor Admin Anda
    _launchUrl(
      "https://wa.me/6282346274572?text=Halo%20Admin%20NusaLearn,%20saya%20butuh%20bantuan.",
    );
  }

  void _contactEmail() {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'NusaLearn@gmail.com',
      queryParameters: {
        'subject': 'Bantuan NusaLearn',
        'body': 'Halo Tim Support, saya mengalami kendala...',
      },
    );
    _launchUrl(emailLaunchUri.toString());
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Pusat Bantuan",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FAQ SECTION (Langsung masuk ke sini)
            Text(
              "Sering Ditanyakan",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),

            _buildFaqItem(
              "Bagaimana cara menaikkan level?",
              "Kamu bisa mendapatkan XP dengan menyelesaikan kuis dan materi pelajaran. Semakin tinggi nilaimu, semakin cepat levelmu naik!",
            ),
            _buildFaqItem(
              "Apakah aplikasi bisa offline?",
              "Tentu saja! Materi dan kuis yang sudah kamu download (ikon awan) bisa dibuka kapan saja tanpa kuota internet.",
            ),
            _buildFaqItem(
              "Lupa kata sandi akun",
              "Jika kamu lupa sandi, silakan hubungi admin melalui WhatsApp atau Email di bawah ini untuk reset password.",
            ),
            _buildFaqItem(
              "Bagaimana mengganti bahasa?",
              "Masuk ke menu Profil > Bahasa Aplikasi. Kamu bisa memilih Bahasa Indonesia atau Bahasa Daerah yang tersedia.",
            ),

            const SizedBox(height: 32),

            // 2. CONTACT SUPPORT BOX
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Masih butuh bantuan?",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tim support NusaLearn siap membantumu 24/7.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // WhatsApp Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _contactWhatsApp,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                      label: Text(
                        "Chat WhatsApp",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // WA Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        shadowColor: const Color(0xFF25D366).withOpacity(0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Email Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _contactEmail,
                      icon: const Icon(
                        Icons.email_rounded,
                        size: 20,
                        color: Color(0xFFEA4335),
                      ), // Gmail Red
                      label: Text(
                        "NusaLearn@gmail.com",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGET ---
  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      // Menggunakan Builder agar context tersedia untuk Theme
      child: Builder(
        builder: (context) {
          return Theme(
            // Menghilangkan garis divider bawaan ExpansionTile
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                question,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              collapsedIconColor: const Color(
                0xFF94A3B8,
              ), // Abu-abu saat tertutup
              iconColor: const Color(0xFF009688), // Teal saat terbuka
              children: [
                Text(
                  answer,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
