import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/ui/screens/materi_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 1.5;

class MateriTab extends StatefulWidget {
  const MateriTab({super.key});

  @override
  State<MateriTab> createState() => _MateriTabState();
}

class _MateriTabState extends State<MateriTab> with TickerProviderStateMixin {
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  String _school = "Memuat...";
  String _username = "Siswa";
  String _selectedCategory = "Semua";
  final List<String> _categories = ["Semua", "Literasi", "Numerasi", "Budaya"];

  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  int _studentLevel = 1;

  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller untuk animasi loader
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadHeaderData();
    _loadMaterials();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
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
    int penggunaId = 0;
    final userResult = await db.query('pengguna', limit: 1);
    if (userResult.isNotEmpty) penggunaId = userResult.first['id'] as int;

    // Hitung Level Adaptif
    int calculatedLevel = await AdaptiveService().calculateStudentLevel(penggunaId);

    // Filter Query
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];

    // Filter Kategori
    if (_selectedCategory != "Semua") {
      whereClause += ' AND kategori LIKE ?';
      whereArgs.add(_selectedCategory);
    }

    // Filter Level (Adaptif)
    

    final data = await db.query(
      'materi',
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
  // === AKHIR LOGIKA INTI ===

  // === UI UPDATE: DIALOG INFO AI ADAPTIF (NEO-BRUTALISM) ===
  void _showAdaptiveInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border.all(color: kBlack, width: kBorderWidth),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPurple,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBlack, width: kBorderWidth),
                    boxShadow: const [
                      BoxShadow(color: kBlack, offset: Offset(2, 2)),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: kBlack,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Adaptive Learning",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kBlack,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Materi disesuaikan otomatis dengan kemampuanmu (Level $_studentLevel). Sistem menganalisis perkembanganmu secara real-time!",
                  style: GoogleFonts.plusJakartaSans(
                    color: kBlack.withOpacity(0.8),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kLime,
                        border: Border.all(color: kBlack, width: kBorderWidth),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Mengerti",
                        style: GoogleFonts.plusJakartaSans(
                          color: kBlack,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // === UI UPDATE: LOADER (NEO-BRUTALISM) ===
  Widget _buildGlassmorphismLoader() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kLime,
                  border: Border.all(color: kBlack, width: kBorderWidth),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: kBlack, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _spinController,
                      child: const Icon(Icons.autorenew_rounded, color: kBlack),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Memuat Materi",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Tambahkan listener agar widget rebuild saat bahasa diganti
    Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17), // Base dark frame if needed
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 238, 233, 249),
                  Color.fromARGB(255, 181, 161, 239),
                ],
              ),
            ),
          ),

          // Background Grid Pattern
          CustomPaint(painter: GridPainter(), child: Container()),

          SafeArea(
            child: Column(
              children: [
                // 1. APP BAR (Neo-Brutalism)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Nusa",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: kBlack,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                              Transform.rotate(
                                angle: -0.04,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kPurple,
                                    border: Border.all(
                                      color: kBlack,
                                      width: kBorderWidth,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: kBlack,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    "Learn",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: kBlack,
                                      letterSpacing: -0.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DictionaryService.instance.translateSync("Halo") + ", $_username 👋",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kBlack,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "AI sedang aktif menyesuaikan materimu!",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: kBlack,
                                ),
                              ),
                              backgroundColor: kLime,
                              duration: const Duration(milliseconds: 1000),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: kBlack, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _showAdaptiveInfo(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kBlack,
                              width: kBorderWidth,
                            ),
                            boxShadow: const [
                              BoxShadow(color: kBlack, offset: Offset(2, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: kBlack,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DictionaryService.instance.translateSync("AI AKTIF"),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: kBlack,
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
                    color: kBlack,
                    backgroundColor: kLime,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 2. HERO CARD (Level & Sekolah)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: kPurple,
                                border: Border.all(
                                  color: kBlack,
                                  width: kBorderWidth,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: kBlack,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Positioned(
                                    top: -10,
                                    right: -10,
                                    child: Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Color(0xFFFFC107),
                                      size: 50,
                                      shadows: [
                                        Shadow(
                                          color: kBlack,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DictionaryService.instance.translateSync("LEVEL KAMU SAAT INI"),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: kBlack,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Level $_studentLevel",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: kBlack,
                                          height: 1.1,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        height: 2,
                                        color: kBlack,
                                        width: double.infinity,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: kWhite,
                                              border: Border.all(
                                                color: kBlack,
                                                width: kBorderWidth,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: kBlack,
                                                  offset: Offset(2, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.school_rounded,
                                              color: kBlack,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _school,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: kBlack,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
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
                              height: 56,
                              decoration: BoxDecoration(
                                color: kWhite,
                                border: Border.all(
                                  color: kBlack,
                                  width: kBorderWidth,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: kBlack,
                                    offset: Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: kBlack,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Mau belajar apa hari ini?",
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF6B6B6B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: kBlack,
                                    size: 24,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 4. KATEGORI (CHIPS)
                        SliverToBoxAdapter(
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(vertical: 24),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final isSelected =
                                    _selectedCategory == category;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                      _isLoading = true;
                                    });
                                    _loadMaterials();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? kLime : kWhite,
                                      border: Border.all(
                                        color: kBlack,
                                        width: kBorderWidth,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: isSelected
                                          ? const [
                                              BoxShadow(
                                                color: kBlack,
                                                offset: Offset(2, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      category,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isSelected
                                            ? kBlack
                                            : const Color(0xFF6B6B6B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // 5. GRID MATERI
                        if (!_isLoading && _materials.isEmpty)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.folder_off_rounded,
                                    size: 60,
                                    color: kBlack,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Belum ada materi",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: kBlack,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (!_isLoading && _materials.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio:
                                        0.75, // Disesuaikan dengan desain card
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = _materials[index];
                                final isLocked = (item['tingkat_kesulitan'] as int) > _studentLevel;
                                return GestureDetector(
                                  onTap: isLocked ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Materi ini terkunci! Kumpulkan lebih banyak poin di level sebelumnya.')));
                                  } : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MateriDetailScreen(material: item),
                                      ),
                                    );
                                  },
                                  child: _MaterialCard(
                                    item: item,
                                    index: index,
                                    isLocked: isLocked,
                                  ),
                                );
                              }, childCount: _materials.length),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Memanggil Glassmorphism Loader dari animasi state
          if (_isLoading) _buildGlassmorphismLoader(),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isLocked;

  const _MaterialCard({super.key, required this.item, required this.index, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    String? localPath = item['local_image_path'];
    bool hasLocalImage = localPath != null && File(localPath).existsSync();

    // Rotasi warna box untuk variasi visual seperti di desain HTML
    List<Color> boxColors = [
      const Color(0xFFFFDEB3),
      const Color(0xFFB3E5FF),
      const Color(0xFFFFB3D9),
      const Color(0xFFE0F7FA),
    ];
    Color imageBgColor = boxColors[index % boxColors.length];

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBlack, width: kBorderWidth),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. BAGIAN GAMBAR (Expanded murni untuk fleksibilitas sisa ruang)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: imageBgColor,
                border: const Border(
                  bottom: BorderSide(color: kBlack, width: kBorderWidth),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: hasLocalImage
                          ? Image.file(File(localPath), fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 40,
                                color: kBlack.withOpacity(0.5),
                              ),
                            ),
                    ),
                  ),
                                    if (isLocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: kBlack.withOpacity(0.6),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: const Center(
                          child: Icon(Icons.lock_rounded, color: kWhite, size: 48),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite,
                        border: Border.all(color: kBlack, width: kBorderWidth),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      child: Text(
                        (item['kategori'] ?? 'UMUM').toString().toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: kBlack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. BAGIAN TEKS (Bebas constraint flex, ukuran menyesuaikan konten)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Kunci utama mencegah overflow
              children: [
                Text(
                  DictionaryService.instance.translateSync(
                    item['judul'] ?? 'Tanpa Judul',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.3,
                    color: kBlack,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(
                  height: 12,
                ), // Jarak pasti tanpa fluktuasi spaceBetween
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F0FF),
                        border: Border.all(color: kBlack, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.signal_cellular_alt,
                            size: 12,
                            color: kBlack,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Lv ${item['tingkat_kesulitan'] ?? 1}",
                            style: GoogleFonts.plusJakartaSans(
                              color: kBlack,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kLime,
                        border: Border.all(color: kBlack, width: kBorderWidth),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: kBlack, offset: Offset(2, 2)),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- BACKGROUND GRID PAINTER ---
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    const double step = 32.0;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += step) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
