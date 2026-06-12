import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusalearn/ui/screens/tabs/home_tab.dart';
import 'package:nusalearn/ui/screens/tabs/materi_tab.dart';
import 'package:nusalearn/ui/screens/tabs/kuis_tab.dart';
import 'package:nusalearn/ui/screens/tabs/profile_tab.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';

// Gunakan warna ungu muda yang sama di sini untuk konsistensi
const Color kPurpleMudaNavbar = Color(0xFFFFD6C7FF);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const MateriTab(),
    const KuisTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // ✅ Listener untuk rebuild saat bahasa berubah
    Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17), // Warna background luar frame
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 70, // REVISI: Tinggi navbar dikurangi
        decoration: const BoxDecoration(
          color: Colors.white,
          // REVISI: Border hanya di atas, borderRadius DIHAPUS
          border: Border(
            top: BorderSide(color: Colors.black, width: 1.5),
          ), // REVISI: Border lebih tipis
          borderRadius: BorderRadius.zero, // REVISI: Lengkungan dihapus
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ), // REVISI: Vertical padding dikurangi
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, DictionaryService.instance.translateSync('Home')),
            _buildNavItem(1, Icons.menu_book_rounded, DictionaryService.instance.translateSync('Materi')),
            _buildNavItem(2, Icons.videogame_asset_rounded, DictionaryService.instance.translateSync('Kuis')),
            _buildNavItem(3, Icons.person_rounded, DictionaryService.instance.translateSync('Profil')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool aktif = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ), // REVISI: Padding internal dikurangi
        decoration: BoxDecoration(
          color: aktif ? const Color(0xFFD2F945) : Colors.transparent,
          // REVISI: Border lebih tipis (1.5)
          border: aktif
              ? Border.all(color: Colors.black, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(
            12,
          ), // Lengkungan internal tombol tetap ada untuk kontras
          boxShadow: aktif
              ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2))]
              : [],
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.only(
            bottom: aktif ? 3.0 : 0.0,
          ), // Efek terangkat (translateY) diperkecil
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.black.withOpacity(aktif ? 1.0 : 0.5),
                size: 20, // REVISI: Ukuran ikon diperkecil
              ),
              const SizedBox(height: 1), // REVISI: Spacing diperkecil
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: aktif ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 10, // REVISI: Ukuran teks diperkecil
                  color: Colors.black.withOpacity(aktif ? 1.0 : 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
