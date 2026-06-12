import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Pastikan package ini ada di pubspec.yaml

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0;

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // === LOGIC: URL LAUNCHER (TIDAK DISENTUH) ===
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
  // === AKHIR LOGIC ===

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
                        "Pusat Bantuan",
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

                // Body Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. FAQ SECTION
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kBlack,
                              width: kBorderWidth,
                            ),
                          ),
                          child: Text(
                            "SERING DITANYAKAN",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: kBlack,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

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
                          "Jika kamu lupa sandi, silakan hubungi admin melalui WhatsApp atau Email di bawah ini untuk reset kata_sandi.",
                        ),
                        _buildFaqItem(
                          "Bagaimana mengganti bahasa?",
                          "Masuk ke menu Profil > Bahasa Aplikasi. Kamu bisa memilih Bahasa Indonesia atau Bahasa Daerah yang tersedia.",
                        ),

                        const SizedBox(height: 40),

                        // 2. CONTACT SUPPORT BOX (Neo-Brutalism)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: kBlack,
                              width: kBorderWidth,
                            ),
                            boxShadow: const [
                              BoxShadow(color: kBlack, offset: Offset(8, 8)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                "MASIH BUTUH BANTUAN?",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: kBlack,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tim support NusaLearn siap membantumu 24/7. Jangan ragu untuk menghubungi kami.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kBlack.withOpacity(0.7),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // WhatsApp Button Custom
                              GestureDetector(
                                onTap: _contactWhatsApp,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366), // WA Green
                                    borderRadius: BorderRadius.circular(16),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.chat_bubble_rounded,
                                        color: kBlack,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "CHAT WHATSAPP",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: kBlack,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Email Button Custom
                              GestureDetector(
                                onTap: _contactEmail,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kWhite,
                                    borderRadius: BorderRadius.circular(16),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.email_rounded,
                                        color: Color(0xFFEA4335), // Red Gmail
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "NusaLearn@gmail.com",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: kBlack,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGET NEO-BRUTALISM ---
  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBlack, width: kBorderWidth),
        boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
      ),
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
                  fontWeight: FontWeight.w800,
                  color: kBlack,
                ),
              ),
              collapsedIconColor: kBlack,
              iconColor: kPurple, // Warna saat ekspansi terbuka
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kBlack.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBlack.withOpacity(0.1)),
                  ),
                  child: Text(
                    answer,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kBlack.withOpacity(0.8),
                      height: 1.5,
                    ),
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
