import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/ui/screens/materi_detail_screen.dart';

class MateriTab extends StatefulWidget {
  const MateriTab({super.key});

  @override
  State<MateriTab> createState() => _MateriTabState();
}

class _MateriTabState extends State<MateriTab> {
  String _school = "Memuat...";
  String _username = "Siswa";
  String _selectedCategory = "Semua";
  final List<String> _categories = ["Semua", "Literasi", "Numerasi", "Budaya"];

  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  int _studentLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadHeaderData();
    _loadMaterials();
  }

  void _loadHeaderData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _school = prefs.getString('user_school') ?? "Sekolah Dasar";
      _username = prefs.getString('user_name') ?? "Siswa";
    });
  }

  void _loadMaterials() async {
    final db = await DatabaseHelper.instance.database;

    // Ambil ID User
    int userId = 0;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) userId = userResult.first['id'] as int;

    // Hitung Level Adaptif
    int calculatedLevel = await AdaptiveService().calculateStudentLevel(userId);

    // Filter Query
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];

    // Filter Kategori
    if (_selectedCategory != "Semua") {
      whereClause += ' AND category LIKE ?';
      whereArgs.add(_selectedCategory);
    }

    // Filter Level (Adaptif)
    whereClause += ' AND level_difficulty <= ?';
    whereArgs.add(calculatedLevel);

    final data = await db.query(
      'materials',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );

    if (mounted) {
      setState(() {
        _materials = data;
        _studentLevel = calculatedLevel;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    _loadMaterials();
  }

  // ✅ FUNGSI POPUP INFORMASI AI (UNTUK DEMO KE DOSEN)
  void _showAdaptiveInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Background Putih
              Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Adaptive Learning System",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Poin-poin penjelasan
                    _buildInfoItem(
                      icon: Icons.analytics_outlined,
                      title: "Analisis Real-time",
                      desc:
                          "Sistem menganalisis jawaban siswa untuk menentukan tingkat pemahaman secara akurat.",
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      icon: Icons.tune_rounded,
                      title: "Penyesuaian Dinamis",
                      desc:
                          "Tingkat kesulitan materi (Level 1-3) disesuaikan otomatis. Jika siswa mahir, level naik.",
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      icon: Icons.person_pin_circle_outlined,
                      title: "Personalisasi",
                      desc:
                          "Setiap siswa mendapatkan rekomendasi materi yang unik sesuai kemampuan masing-masing.",
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Mengerti",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Icon Floating di Atas
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper Widget untuk Item Info Popup
  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.teal, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER (Logo NusaLearn & Badge AI)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo NusaLearn & Sapaan
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo, $_username 👋",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "Nusa",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: "Learn",
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ✅ BADGE ADAPTIF AI (Tekan Lama untuk Info Dosen)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "AI sedang aktif menyesuaikan materimu!",
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.teal,
                          duration: const Duration(milliseconds: 1000),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onLongPress: () {
                      _showAdaptiveInfo(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.teal.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.teal.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Adaptif AI",
                            style: GoogleFonts.poppins(
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.teal,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  slivers: [
                    // 2. KARTU LEVEL & SEKOLAH
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.shade700,
                                Colors.teal.shade400,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Baris Level
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Level Kamu Saat Ini",
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        "Level $_studentLevel",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: Colors.amber,
                                    size: 40,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Container(height: 1, color: Colors.white24),
                              const SizedBox(height: 12),

                              // Baris Sekolah
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.school_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _school,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. SEARCH BAR
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Mau belajar apa hari ini?",
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.teal.shade300,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 4. KATEGORI (CHIPS)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            final isSelected = _selectedCategory == category;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = category;
                                  _isLoading = true;
                                });
                                _loadMaterials();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.teal
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.teal
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    category,
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 5. GRID MATERI
                    _isLoading
                        ? const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            ),
                          )
                        : _materials.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.folder_off_rounded,
                                    size: 60,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Belum ada materi",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        0.72, // Rasio kartu dioptimalkan
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = _materials[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MateriDetailScreen(material: item),
                                      ),
                                    );
                                  },
                                  child: _MaterialCard(item: item),
                                );
                              }, childCount: _materials.length),
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MaterialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    String? localPath = item['local_image_path'];
    bool hasLocalImage = localPath != null && File(localPath).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BAGIAN GAMBAR
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: hasLocalImage
                        ? Image.file(File(localPath), fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 30,
                              color: Colors.orange.shade200,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (item['category'] ?? 'UMUM').toString().toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. BAGIAN TEKS
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title_indo'] ?? 'Tanpa Judul',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.signal_cellular_alt,
                              size: 10,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Lv ${item['level_difficulty']}",
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
