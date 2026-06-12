import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/quiz_screen.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 1.5;

class KuisTab extends StatefulWidget {
  const KuisTab({super.key});

  @override
  State<KuisTab> createState() => _KuisTabState();
}

class _KuisTabState extends State<KuisTab> with TickerProviderStateMixin {
  // === LOGIKA INTI (TIDAK DISENTUH) ===
  String _school = "Memuat...";
  String _username = "Siswa";
  List<Map<String, dynamic>> _quizList = [];
  bool _isLoading = true;
  int _studentLevel = 1;

  String _selectedCategory = "Semua";
  final List<String> _categories = ["Semua", "Literasi", "Numerasi", "Budaya"];

  int _selectedLevel = 0;
  final List<int> _levels = [0, 1, 2, 3];

  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadHeaderData();
    _loadAvailableQuizzesWithProgress();
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

  void _loadAvailableQuizzesWithProgress() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    int penggunaId = 0;
    final userResult = await db.query('pengguna', limit: 1);
    if (userResult.isNotEmpty) penggunaId = userResult.first['id'] as int;

    int calculatedLevel = await AdaptiveService().calculateStudentLevel(penggunaId);

    String whereClause = 'm.is_deleted = 0 AND q.is_deleted = 0';
    List<dynamic> args = [];

    if (_selectedCategory != "Semua") {
      whereClause += ' AND m.kategori LIKE ?';
      args.add(_selectedCategory);
    }

    if (_selectedLevel != 0) {
      whereClause += ' AND m.tingkat_kesulitan = ?';
      args.add(_selectedLevel);
    } // REMOVED else block so it shows all locked levels

    final data = await db.rawQuery(
      '''
      SELECT 
        m.id, 
        m.judul, 
        m.kategori, 
        m.tingkat_kesulitan, 
        m.local_image_path,
        COUNT(DISTINCT CASE WHEN q.bobot_kesulitan <= ? THEN q.id END) as total_questions,
        COUNT(DISTINCT CASE WHEN q.bobot_kesulitan <= ? THEN sp.soal_id END) as answered_questions
      FROM materi m
      JOIN soal q ON m.id = q.materi_id AND q.is_deleted = 0
      LEFT JOIN progres_siswa sp ON q.id = sp.soal_id AND sp.pengguna_id = ?
      WHERE $whereClause
      GROUP BY m.id
      HAVING total_questions > 0
      ORDER BY m.id DESC
    ''',
      [calculatedLevel, calculatedLevel, penggunaId, ...args],
    );

    if (mounted) {
      setState(() {
        _quizList = data;
        _studentLevel = calculatedLevel;
        _isLoading = false;
      });
    }
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
                  "Kuis Adaptif AI",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kBlack,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Soal kuis disesuaikan dengan level pemahamanmu secara otomatis. Selesaikan kuis untuk menaikkan level!",
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
                        "Siap!",
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

  // === UI UPDATE: LOADER (GLASSMORPHISM) ===
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
                      child: const Icon(
                        Icons.videogame_asset_rounded,
                        color: kBlack,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Memuat Kuis",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
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
    Provider.of<AuthProvider>(context);

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
          CustomPaint(painter: GridPainter(), child: Container()),

          SafeArea(
            child: Column(
              children: [
                // 1. APP BAR
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
                                    "Quiz",
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
                          const SizedBox(height: 6),
                          Text(
                            "Halo, $_username 👋",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kBlack,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onLongPress: () => _showAdaptiveInfo(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
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
                                "AI AKTIF",
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
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                      _loadAvailableQuizzesWithProgress();
                    },
                    color: kBlack,
                    backgroundColor: kLime,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 2. HERO CARD (Rotated Trophy)
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "LEVEL KUIS KAMU",
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
                                              fontSize: 40,
                                              fontWeight: FontWeight.w900,
                                              color: kBlack,
                                              height: 1,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Transform.rotate(
                                        angle: 0.17, // Sekitar 10 derajat
                                        child: const Icon(
                                          Icons.emoji_events_rounded,
                                          color: Color(0xFFFFC107),
                                          size: 48,
                                          shadows: [
                                            Shadow(
                                              color: kBlack,
                                              offset: Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
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
                            ),
                          ),
                        ),

                        // 3. FILTERS (Level & Kategori)
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Level Buttons
                              Container(
                                height: 40,
                                margin: const EdgeInsets.only(bottom: 20),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  itemCount: _levels.length,
                                  separatorBuilder: (c, i) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final lvl = _levels[index];
                                    final isSelected = _selectedLevel == lvl;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedLevel = lvl);
                                        _loadAvailableQuizzesWithProgress();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected ? kLime : kWhite,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                        child: Text(
                                          lvl == 0 ? "Auto Mode" : "Level $lvl",
                                          style: GoogleFonts.plusJakartaSans(
                                            color: kBlack,
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w900
                                                : FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Category Pills
                              Container(
                                height: 32,
                                margin: const EdgeInsets.only(bottom: 20),
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
                                        _loadAvailableQuizzesWithProgress();
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? kWhite.withOpacity(0.5)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected
                                                ? kBlack
                                                : Colors.transparent,
                                            width: kBorderWidth,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: isSelected
                                                ? kBlack
                                                : const Color(0xFF6B6B6B),
                                            fontWeight: isSelected
                                                ? FontWeight.w900
                                                : FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. GRID KUIS ATAU EMPTY STATE
                        if (!_isLoading && _quizList.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 40),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  border: Border.all(
                                    color: kBlack,
                                    width: 2,
                                  ), // Solid border as dashed replacement in mobile
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kBlack.withOpacity(0.1),
                                      offset: const Offset(4, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.assignment_late_rounded,
                                      size: 48,
                                      color: kBlack.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "BELUM ADA KUIS",
                                      style: GoogleFonts.plusJakartaSans(
                                        color: kBlack.withOpacity(0.6),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (!_isLoading && _quizList.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.70,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = _quizList[index];
                                final isLocked = (item['tingkat_kesulitan'] as int) > _studentLevel;
                                return GestureDetector(
                                  onTap: isLocked ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kuis ini terkunci! Selesaikan level sebelumnya.')));
                                  } : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizScreen(
                                          materiId: item['id'],
                                          materialTitle: item['judul'],
                                        ),
                                      ),
                                    );
                                    _loadAvailableQuizzesWithProgress();
                                  },
                                  child: _QuizGridCard(
                                    item: item,
                                    index: index,
                                    isLocked: isLocked,
                                  ),
                                );
                              }, childCount: _quizList.length),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading) _buildGlassmorphismLoader(),
        ],
      ),
    );
  }
}

// --- CARD KUIS NEO-BRUTALISM ---
class _QuizGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isLocked;

  const _QuizGridCard({super.key, required this.item, required this.index, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    String? localPath = item['local_image_path'];
    bool hasLocalImage = localPath != null && File(localPath).existsSync();

    int total = item['total_questions'] as int? ?? 0;
    int answered = item['answered_questions'] as int? ?? 0;
    double progress = total == 0 ? 0 : answered / total;
    if (progress > 1.0) progress = 1.0;
    bool isCompleted = progress == 1.0;

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
          // 1. BAGIAN GAMBAR
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
                                Icons.videogame_asset_rounded,
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
                  if (isCompleted)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kLime,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: kBlack,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 2. BAGIAN TEKS DAN PROGRESS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Defensive flex
              children: [
                Text(
                  DictionaryService.instance.translateSync(
                    item['judul'] ?? 'Kuis',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.3,
                    color: kBlack,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCompleted ? "Selesai" : "$answered/$total Soal",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kBlack.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Custom Neo-Brutalist Progress Bar
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kWhite,
                    border: Border.all(color: kBlack, width: 1.0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? kLime : kPurple,
                        border: progress > 0
                            ? const Border(
                                right: BorderSide(color: kBlack, width: 1.0),
                              )
                            : null,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(3),
                        ),
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
