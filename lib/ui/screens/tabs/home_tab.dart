import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/dictionary_service.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/materi_detail_screen.dart';
import 'package:nusalearn/core/services/sync_service.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

// Konstanta Warna Neo-Brutalism
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 1.5;

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  // === LOGIKA TIDAK DISENTUH ===
  String _userName = "Sobat Nusa";
  String _school = "Memuat...";
  int _totalRead = 0;
  int _quizCorrect = 0;
  int _currentLevel = 1;
  double _xpProgress = 0.0;
  List<Map<String, dynamic>> _recentMaterials = [];
  bool _isLoading = true;
  bool _showLevelUpOverlay = false;

  late AnimationController _waveController;
  late AnimationController _spinController;
  AudioPlayer? _sfxPlayer;

  @override
  void initState() {
    super.initState();
    _loadAllHomeData();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _spinController.dispose();
    _sfxPlayer?.stop();
    _sfxPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playLevelUpSfx() async {
    try {
      _sfxPlayer ??= AudioPlayer();
      await _sfxPlayer!.play(AssetSource('audio/level-up.mp3'));
    } catch (e) {
      debugPrint("Gagal memutar SFX level up: $e");
    }
  }

  Future<void> _loadAllHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper.instance.database;

    // Nilai awal dari cache
    String name = prefs.getString('user_name') ?? "Siswa";
    String school = prefs.getString('user_school') ?? "-";

    int penggunaId = 0;

    // FETCH SINGLE ROW DARI SQLITE (O(1))
    final userResult = await db.query('pengguna', limit: 1);

    if (userResult.isNotEmpty) {
      final userData = userResult.first;
      penggunaId = userData['id'] as int;

      // 1. DEFENSIVE OVERRIDE: Prioritaskan data SQLite (asal_sekolah)
      final dbSchool = userData['asal_sekolah'] as String?;
      if (dbSchool != null && dbSchool.trim().isNotEmpty && dbSchool != "-") {
        school = dbSchool;
        // Sinkronisasi otomatis ke cache
        await prefs.setString('user_school', school);
      }

      // 2. DEFENSIVE OVERRIDE: Sinkronkan juga nama jika perlu
      final dbName = userData['nama'] as String?;
      if (dbName != null && dbName.trim().isNotEmpty) {
        name = dbName;
        await prefs.setString('user_name', name);
      }
    }

    int level = await AdaptiveService().calculateStudentLevel(penggunaId);
    final countRead = await db.rawQuery(
      'SELECT COUNT(*) as count FROM recent_materials WHERE pengguna_id = ?',
      [penggunaId],
    );
    // Cek progress untuk level saat ini
    final levelProgressQuery = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT sp.soal_id) as correctcount
      FROM progres_siswa sp
      JOIN soal q ON sp.soal_id = q.id
      JOIN materi m ON q.materi_id = m.id
      WHERE sp.pengguna_id = ? AND sp.benar = 1 AND m.tingkat_kesulitan = ?
      ''',
      [penggunaId, level],
    );
    
    // Total keseluruhan jawaban benar (unik) untuk statistik
    final totalQuizQuery = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT sp.soal_id) as count 
      FROM progres_siswa sp 
      WHERE sp.pengguna_id = ? AND sp.benar = 1
      ''',
      [penggunaId],
    );

    final recents = await db.rawQuery(
      '''
      SELECT m.*, r.last_accessed
      FROM recent_materials r
      JOIN materi m ON r.materi_id = m.id
      WHERE r.pengguna_id = ? AND m.is_deleted = 0
      ORDER BY r.last_accessed DESC
      LIMIT 10
    ''',
      [penggunaId],
    );

    if (mounted) {
      setState(() {
        _userName = name;
        _school = school;

        _totalRead = Sqflite.firstIntValue(countRead) ?? 0;
        _quizCorrect = Sqflite.firstIntValue(totalQuizQuery) ?? 0;

        // Gunakan level dari AdaptiveService
        _currentLevel = level;
        
        // Kalkulasi persentase bar (berdasarkan soal unik yang dijawab benar di level ini)
        int correctForLevel = Sqflite.firstIntValue(levelProgressQuery) ?? 0;
        _xpProgress = (correctForLevel / 5.0).clamp(0.0, 1.0);
            
        int lastSeenLevel = prefs.getInt('last_seen_level') ?? _currentLevel;
        if (_currentLevel > lastSeenLevel) {
          _showLevelUpOverlay = true;
          _playLevelUpSfx();
          Future.delayed(const Duration(milliseconds: 4000), () {
            if (mounted) setState(() => _showLevelUpOverlay = false);
          });
        }
        prefs.setInt('last_seen_level', _currentLevel);

        _recentMaterials = recents;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _isLoading = false);
        });
      });
    }
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _loadAllHomeData();
  }

  // RESTORASI: Memanggil class dialog di bawah
  void _showAdaptiveInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AdaptiveInfoDialog(),
    );
  }
  // === AKHIR LOGIKA UTAMA ===

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
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
          CustomPaint(painter: GridPainter(), child: Container()),

          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: kBlack,
                    backgroundColor: kLime,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                            child: Row(
                              children: [
                                Text(
                                  DictionaryService.instance.translateSync("Halo") + ", $_userName",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: kBlack,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                RotationTransition(
                                  turns: Tween(
                                    begin: -0.05,
                                    end: 0.05,
                                  ).animate(_waveController),
                                  child: const Text(
                                    "👋",
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildNeoBrutalHeroCard(),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 20)),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DictionaryService.instance.translateSync("Lanjutkan Belajar"),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: kBlack,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (_recentMaterials.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kWhite,
                                      border: Border.all(
                                        color: kBlack,
                                        width: kBorderWidth,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: kBlack,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.history_rounded,
                                          size: 12,
                                          color: kBlack,
                                        ),
                                        const SizedBox(width: 4),
                                          Text(
                                            DictionaryService.instance.translateSync("TERBARU"),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              color: kBlack,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 6,
                          ),
                          sliver: _recentMaterials.isEmpty && !_isLoading
                              ? const SliverToBoxAdapter(
                                  child: Center(
                                    child: Text("Belum ada riwayat."),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final item = _recentMaterials[index];
                                    return _NeoBrutalCard(
                                      item: item,
                                      index: index,
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MateriDetailScreen(
                                                  material: item,
                                                ),
                                          ),
                                        );
                                        _loadAllHomeData();
                                      },
                                    );
                                  }, childCount: _recentMaterials.length),
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

          if (_isLoading) _buildGlassmorphismLoader(),

          // LEVEL UP OVERLAY
          if (_showLevelUpOverlay)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showLevelUpOverlay = false),
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        "assets/animasi/level-up.json",
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                        repeat: false,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "LEVEL UP!",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: kLime,
                          letterSpacing: 2,
                          shadows: const [Shadow(color: kBlack, offset: Offset(3, 3))],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Kamu sekarang berada di Level $_currentLevel",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kWhite,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Ketuk untuk melanjutkan",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kWhite.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // === WIDGET COMPONENTS ===

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
                      "Memuat Dashboard",
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

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Nusa",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kBlack,
                  letterSpacing: -0.5,
                ),
              ),
              Transform.rotate(
                angle: -0.04,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: kPurple,
                    border: Border.all(color: kBlack, width: kBorderWidth),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: kBlack, offset: Offset(2, 2)),
                    ],
                  ),
                  child: Text(
                    "Learn",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {},
            onLongPress: () => _showAdaptiveInfo(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBlack, width: kBorderWidth),
                boxShadow: const [
                  BoxShadow(color: kBlack, offset: Offset(2, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: kBlack, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    DictionaryService.instance.translateSync("AI AKTIF"),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kBlack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoBrutalHeroCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kPurple,
        border: Border.all(color: kBlack, width: kBorderWidth),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kWhite,
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(2, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 12,
                              color: kBlack,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _school,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: kBlack,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DictionaryService.instance.translateSync("LEVEL SAAT INI"),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kBlack,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Lv. $_currentLevel",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: kBlack,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: kLime,
                          border: Border.all(
                            color: kBlack,
                            width: kBorderWidth,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentLevel < 3 ? "Terus tingkatkan!" : "Master!",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kWhite,
                      border: Border.all(color: kBlack, width: kBorderWidth),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _xpProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kLime,
                          border: Border(
                            right: BorderSide(
                              color: kBlack,
                              width: kBorderWidth,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      border: Border.all(color: kBlack, width: kBorderWidth),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                color: kBlack,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$_totalRead",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: kBlack,
                                    ),
                                  ),
                                  Text(
                                    "MATERI",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: kBlack,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1.5, height: 26, color: kBlack),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: kBlack,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$_quizCorrect",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: kBlack,
                                    ),
                                  ),
                                  Text(
                                    "POIN KUIS",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEO-BRUTALISM CARD LIST ---
class _NeoBrutalCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onTap;

  const _NeoBrutalCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String? localPath = item['local_image_path'];
    bool hasLocalImage = localPath != null && File(localPath).existsSync();

    String title = DictionaryService.instance.translateSync(
      item['judul'] ?? 'Tanpa Judul',
    );
    String category = (item['kategori'] ?? 'UMUM').toString().toUpperCase();

    List<Color> boxColors = [
      const Color(0xFFFFDEB3),
      const Color(0xFFB3E5FF),
      const Color(0xFFFFB3D9),
    ];
    List<IconData> icons = [
      Icons.menu_book_rounded,
      Icons.science_rounded,
      Icons.calculate_rounded,
    ];

    Color currentBoxColor = boxColors[index % boxColors.length];
    IconData currentIcon = icons[index % icons.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kWhite,
          border: Border.all(color: kBlack, width: kBorderWidth),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: currentBoxColor,
                border: Border.all(color: kBlack, width: kBorderWidth),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasLocalImage
                    ? Image.file(File(localPath), fit: BoxFit.cover)
                    : Icon(currentIcon, size: 28, color: kBlack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: currentBoxColor,
                      border: Border.all(color: kBlack, width: 1.0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: kBlack,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: kBlack,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_toggle_off,
                        size: 12,
                        color: Color(0xFF6B6B6B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Lanjutkan membaca",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kWhite,
                border: Border.all(color: kBlack, width: kBorderWidth),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: kBlack, offset: Offset(2, 2)),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: kBlack,
                size: 18,
              ),
            ),
          ],
        ),
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

// --- RESTORASI: DIALOG INFO NEO-BRUTALISM ---
class _AdaptiveInfoDialog extends StatelessWidget {
  const _AdaptiveInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.auto_awesome, color: kBlack, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "Dashboard Pintar",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kBlack,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Tampilan ini beradaptasi dengan kemajuanmu. Semakin rajin kamu belajar, semakin tinggi levelmu!",
              style: GoogleFonts.plusJakartaSans(
                color: kBlack.withOpacity(0.7),
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
  }
}
