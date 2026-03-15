import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusalearn/core/database/database_helper.dart';

// --- KONSTANTA NEO-BRUTALISM ---
const Color kLime = Color(0xFFD2F945);
const Color kPurple = Color.fromARGB(255, 156, 132, 242);
const Color kBlack = Color(0xFF000000);
const Color kWhite = Color(0xFFFFFFFF);
const double kBorderWidth = 2.0;

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  int _totalQuestions = 0;
  int _correctAnswers = 0;
  int _totalTimeSeconds = 0;

  // Data Grafik 7 Hari Terakhir
  List<Map<String, dynamic>> _weeklyData = [];

  // Data Per Kategori
  List<Map<String, dynamic>> _categoryData = [];

  AnimationController? _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadProgressData();
  }

  @override
  void dispose() {
    _spinController?.dispose();
    super.dispose();
  }

  // === FASE EKSEKUSI: DEFENSIVE DATA FETCHING ===
  Future<void> _loadProgressData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Ambil ID User Aktif
      final userResult = await db.query('users', limit: 1);
      if (userResult.isEmpty) throw Exception("User tidak ditemukan");
      final int userId = userResult.first['id'] as int;

      // 2. Agregasi Statistik Global ($O(1)$ query aggregation)
      final globalStats = await db.rawQuery(
        '''
        SELECT 
          COUNT(id) as total_q,
          SUM(is_correct) as total_c,
          SUM(time_spent_seconds) as total_t
        FROM student_progress
        WHERE user_id = ?
      ''',
        [userId],
      );

      if (globalStats.isNotEmpty) {
        _totalQuestions = (globalStats.first['total_q'] as int?) ?? 0;
        _correctAnswers = (globalStats.first['total_c'] as int?) ?? 0;
        _totalTimeSeconds = (globalStats.first['total_t'] as int?) ?? 0;
      }

      // 3. Agregasi Grafik 7 Hari Terakhir ($O(N)$ aggregation)
      // Catatan: SQLite membatasi string function, kita gunakan substr untuk aman
      final weeklyStats = await db.rawQuery(
        '''
        SELECT 
          substr(answered_at, 1, 10) as date,
          COUNT(id) as daily_total,
          SUM(is_correct) as daily_correct
        FROM student_progress
        WHERE user_id = ? AND answered_at IS NOT NULL
        GROUP BY date
        ORDER BY date DESC
        LIMIT 7
      ''',
        [userId],
      );

      _weeklyData = List<Map<String, dynamic>>.from(
        weeklyStats.reversed,
      ); // Urutkan kronologis

      // 4. Agregasi Per Kategori (JOIN complexity: Time $O(K)$, Space $O(C)$)
      final categoryStats = await db.rawQuery(
        '''
        SELECT 
          m.category,
          COUNT(sp.id) as total_answered,
          SUM(sp.is_correct) as total_correct
        FROM student_progress sp
        JOIN questions q ON sp.question_id = q.id
        JOIN materials m ON q.material_id = m.id
        WHERE sp.user_id = ?
        GROUP BY m.category
      ''',
        [userId],
      );

      _categoryData = List<Map<String, dynamic>>.from(categoryStats);
    } catch (e) {
      debugPrint("DB Query Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // === UI KOMPONEN: GRAFIK NATIVE (ZERO DEPENDENCY) ===
  Widget _buildBrutalistChart() {
    if (_weeklyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          "Belum ada data grafik.\nMulai kerjakan kuis!",
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kBlack.withOpacity(0.5),
          ),
        ),
      );
    }

    // Kalkulasi nilai maksimum untuk normalisasi tinggi bar
    int maxDaily = 1; // Default hindari division by zero
    for (var day in _weeklyData) {
      int total = (day['daily_total'] as int?) ?? 0;
      if (total > maxDaily) maxDaily = total;
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA), // Light Cyan
        border: Border.all(color: kBlack, width: kBorderWidth),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Aktivitas 7 Hari Terakhir",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: kBlack,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyData.map((data) {
                int total = (data['daily_total'] as int?) ?? 0;
                int correct = (data['daily_correct'] as int?) ?? 0;
                String dateStr = data['date'] as String? ?? "";
                String dayLabel = dateStr.length >= 10
                    ? dateStr.substring(8, 10)
                    : "?";

                // Normalisasi tinggi bar ($O(1)$ calculation)
                double heightFactor = total / maxDaily;
                double accuracy = total > 0 ? (correct / total) : 0;

                // Representasi warna berdasarkan akurasi
                Color barColor = accuracy > 0.7
                    ? kLime
                    : (accuracy > 0.4
                          ? const Color(0xFFFFDEB3)
                          : const Color(0xFFFF4C4C));

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (total > 0)
                      Text(
                        total.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kBlack,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            width: 28,
                            height: constraints.maxHeight * heightFactor,
                            decoration: BoxDecoration(
                              color: barColor,
                              border: Border.all(color: kBlack, width: 1.5),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: kBlack,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // === HELPER UI ===
  Widget _buildStatBox(
    String title,
    String value,
    Color bgColor,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: kBlack, width: kBorderWidth),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: kBlack, offset: Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kBlack, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kBlack.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double accuracy = _totalQuestions > 0
        ? (_correctAnswers / _totalQuestions) * 100
        : 0;
    int minutesSpent = _totalTimeSeconds ~/ 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAE0FF),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "PROGRES BELAJAR",
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: kBlack,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(color: kBlack, height: 2.0),
        ),
      ),
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
          if (!_isLoading)
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATISTIK GLOBAL ---
                  Row(
                    children: [
                      _buildStatBox(
                        "Akurasi",
                        "${accuracy.toStringAsFixed(0)}%",
                        kLime,
                        Icons.track_changes_rounded,
                      ),
                      const SizedBox(width: 16),
                      _buildStatBox(
                        "Total Soal",
                        "$_totalQuestions",
                        const Color(0xFFFFB3D9),
                        Icons.task_alt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kPurple,
                      border: Border.all(color: kBlack, width: kBorderWidth),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: kBlack, offset: Offset(4, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Waktu Belajar",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kBlack,
                              ),
                            ),
                            Text(
                              "$minutesSpent Menit",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: kBlack,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kWhite,
                            border: Border.all(color: kBlack, width: 1.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.timer_rounded, color: kBlack),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- GRAFIK KUSTOM NEO-BRUTALISM ---
                  _buildBrutalistChart(),

                  const SizedBox(height: 32),

                  // --- STATISTIK PER KATEGORI ---
                  Text(
                    "PENGUASAAN KATEGORI",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_categoryData.isEmpty)
                    Text(
                      "Data kategori belum tersedia.",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    ..._categoryData.map((cat) {
                      String categoryName =
                          cat['category'] as String? ?? "Umum";
                      int tAns = (cat['total_answered'] as int?) ?? 0;
                      int tCor = (cat['total_correct'] as int?) ?? 0;
                      double catAcc = tAns > 0 ? tCor / tAns : 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kWhite,
                          border: Border.all(color: kBlack, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(2, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  categoryName.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "${(catAcc * 100).toStringAsFixed(0)}%",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: catAcc >= 0.7
                                        ? Colors.green[700]
                                        : kBlack,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Brutalist Progress Bar
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                border: Border.all(color: kBlack, width: 1.0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: catAcc,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: catAcc >= 0.7
                                        ? kLime
                                        : const Color(0xFFFFDEB3),
                                    border: const Border(
                                      right: BorderSide(
                                        color: kBlack,
                                        width: 1.0,
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 40),
                ],
              ),
            ),

          // --- LOADER OVERLAY ---
          if (_isLoading)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Center(
                    child: RotationTransition(
                      turns: _spinController ?? const AlwaysStoppedAnimation(0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kLime,
                          border: Border.all(color: kBlack, width: 2),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: kBlack, offset: Offset(4, 4)),
                          ],
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: kBlack,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
