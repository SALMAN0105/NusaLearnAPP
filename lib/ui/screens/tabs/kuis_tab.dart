import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nusalearn/core/database/database_helper.dart';
import 'package:nusalearn/core/services/adaptive_service.dart';
import 'package:nusalearn/logic/providers/auth_provider.dart';
import 'package:nusalearn/ui/screens/quiz_screen.dart';

class KuisTab extends StatefulWidget {
  const KuisTab({super.key});

  @override
  State<KuisTab> createState() => _KuisTabState();
}

class _KuisTabState extends State<KuisTab> {
  String _school = "Memuat...";
  String _username = "Siswa";
  List<Map<String, dynamic>> _quizList = [];
  bool _isLoading = true;
  int _studentLevel = 1;

  String _selectedCategory = "Semua";
  final List<String> _categories = ["Semua", "Literasi", "Numerasi", "Budaya"];

  int _selectedLevel = 0;
  final List<int> _levels = [0, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _loadHeaderData();
    _loadAvailableQuizzesWithProgress();
  }

  void _loadHeaderData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _school = prefs.getString('user_school') ?? "Sekolah Dasar";
      _username = prefs.getString('user_name') ?? "Siswa";
    });
  }

  // ✅ FUNGSI POPUP INFO AI
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
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.teal,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Kuis Adaptif",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Soal kuis ini disesuaikan dengan level pemahamanmu. Selesaikan kuis untuk menaikkan level dan membuka tantangan baru!",
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Siap!",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  void _loadAvailableQuizzesWithProgress() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    int userId = 0;
    final userResult = await db.query('users', limit: 1);
    if (userResult.isNotEmpty) userId = userResult.first['id'] as int;

    int calculatedLevel = await AdaptiveService().calculateStudentLevel(userId);

    String whereClause = 'm.is_deleted = 0 AND q.is_deleted = 0';
    List<dynamic> args = [];

    if (_selectedCategory != "Semua") {
      whereClause += ' AND m.category LIKE ?';
      args.add(_selectedCategory);
    }

    if (_selectedLevel != 0) {
      whereClause += ' AND m.level_difficulty = ?';
      args.add(_selectedLevel);
    } else {
      whereClause += ' AND m.level_difficulty <= ?';
      args.add(calculatedLevel);
    }

    final data = await db.rawQuery(
      '''
      SELECT 
        m.id, 
        m.title_indo, 
        m.category, 
        m.level_difficulty, 
        m.local_image_path,
        COUNT(DISTINCT CASE WHEN q.difficulty_weight <= ? THEN q.id END) as total_questions,
        COUNT(DISTINCT CASE WHEN q.difficulty_weight <= ? THEN sp.question_id END) as answered_questions
      FROM materials m
      JOIN questions q ON m.id = q.material_id AND q.is_deleted = 0
      LEFT JOIN student_progress sp ON q.id = sp.question_id AND sp.user_id = ?
      WHERE $whereClause
      GROUP BY m.id
      HAVING total_questions > 0
      ORDER BY m.id DESC
    ''',
      [calculatedLevel, calculatedLevel, userId, ...args],
    );

    if (mounted) {
      setState(() {
        _quizList = data;
        _studentLevel = calculatedLevel;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                              text: "Quiz",
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

                  // BADGE AI
                  GestureDetector(
                    onTap: () {},
                    onLongPress: () => _showAdaptiveInfo(context),
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
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  _loadAvailableQuizzesWithProgress();
                },
                color: Colors.teal,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  slivers: [
                    // 2. KARTU LEVEL (Info Level & Sekolah)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          10,
                          24,
                          10,
                        ), // Padding bawah dikurangi
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Level Kuis Kamu",
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
                                    Icons.emoji_events_rounded,
                                    color: Colors.amber,
                                    size: 40,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Container(height: 1, color: Colors.white24),
                              const SizedBox(height: 12),
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

                    // 3. FILTER (Level & Kategori)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Level Selector
                          Container(
                            height: 40,
                            margin: const EdgeInsets.only(top: 20),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _levels.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(width: 8),
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
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.teal
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      lvl == 0 ? "Auto" : "Lv $lvl",
                                      style: GoogleFonts.poppins(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Category Selector
                          Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(vertical: 12),
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
                                    margin: const EdgeInsets.only(right: 20),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          category,
                                          style: GoogleFonts.poppins(
                                            color: isSelected
                                                ? Colors.black87
                                                : Colors.grey.shade400,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isSelected)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: Colors.teal,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. GRID KUIS
                    _isLoading
                        ? const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            ),
                          )
                        : _quizList.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_late_outlined,
                                    size: 60,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Tidak ada kuis tersedia",
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
                                    childAspectRatio: 0.70,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = _quizList[index];
                                return GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizScreen(
                                          materialId: item['id'],
                                          materialTitle: item['title_indo'],
                                        ),
                                      ),
                                    );
                                    _loadAvailableQuizzesWithProgress();
                                  },
                                  child: _QuizGridCard(item: item),
                                );
                              }, childCount: _quizList.length),
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

// CARD KUIS (GRID DESIGN + PROGRESS BAR)
class _QuizGridCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _QuizGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    String? localPath = item['local_image_path'];
    bool hasLocalImage = localPath != null && File(localPath).existsSync();

    // Hitung Progress
    int total = item['total_questions'] as int? ?? 0;
    int answered = item['answered_questions'] as int? ?? 0;
    double progress = total == 0 ? 0 : answered / total;
    if (progress > 1.0) progress = 1.0;
    bool isCompleted = progress == 1.0;

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
        border: isCompleted
            ? Border.all(color: Colors.amber.shade300, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GAMBAR
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
                              Icons.quiz_rounded,
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
                if (isCompleted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // INFO
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title_indo'] ?? 'Kuis',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isCompleted ? "Selesai" : "$answered/$total",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.amber : Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade100,
                          color: isCompleted ? Colors.amber : Colors.teal,
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
