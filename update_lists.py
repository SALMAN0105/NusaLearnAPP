import re

def update_materi():
    path = r'c:\xampp\htdocs\nusalearn\lib\ui\screens\tabs\materi_tab.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove filtering by calculatedLevel
    content = content.replace(
        "whereClause += ' AND tingkat_kesulitan <= ?';\n    whereArgs.add(calculatedLevel);",
        ""
    )

    # 2. Add isLocked to onTap
    content = re.sub(
        r"final item = _materials\[index\];\n\s*return GestureDetector\(\n\s*onTap: \(\) \{",
        r"final item = _materials[index];\n                                final isLocked = (item['tingkat_kesulitan'] as int) > _studentLevel;\n                                return GestureDetector(\n                                  onTap: isLocked ? () {\n                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Materi ini terkunci! Kumpulkan lebih banyak poin di level sebelumnya.')));\n                                  } : () {",
        content
    )

    # 3. Pass isLocked to _MaterialCard
    content = re.sub(
        r"child: _MaterialCard\(\n\s*item: item,\n\s*index: index,\n\s*\)",
        r"child: _MaterialCard(\n                                    item: item,\n                                    index: index,\n                                    isLocked: isLocked,\n                                  )",
        content
    )

    # 4. Update _MaterialCard class
    content = content.replace(
        "final Map<String, dynamic> item;\n  final int index;\n\n  const _MaterialCard({super.key, required this.item, required this.index});",
        "final Map<String, dynamic> item;\n  final int index;\n  final bool isLocked;\n\n  const _MaterialCard({super.key, required this.item, required this.index, this.isLocked = false});"
    )

    # 5. Add padlock overlay
    overlay = """                  if (isLocked)
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
                    ),"""

    content = re.sub(
        r"(Positioned\(\n\s*top: 10,\n\s*left: 10,)",
        overlay + r"\n                  \1",
        content
    )

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def update_kuis():
    path = r'c:\xampp\htdocs\nusalearn\lib\ui\screens\tabs\kuis_tab.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove filtering by calculatedLevel
    content = content.replace(
        "} else {\n      whereClause += ' AND m.tingkat_kesulitan <= ?';\n      args.add(calculatedLevel);\n    }",
        "} // REMOVED else block so it shows all locked levels"
    )

    # 2. Add isLocked to onTap
    content = re.sub(
        r"final item = _quizList\[index\];\n\s*return GestureDetector\(\n\s*onTap: \(\) async \{",
        r"final item = _quizList[index];\n                                final isLocked = (item['tingkat_kesulitan'] as int) > _studentLevel;\n                                return GestureDetector(\n                                  onTap: isLocked ? () {\n                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kuis ini terkunci! Selesaikan level sebelumnya.')));\n                                  } : () async {",
        content
    )

    # 3. Pass isLocked to _QuizGridCard
    content = re.sub(
        r"child: _QuizGridCard\(\n\s*item: item,\n\s*index: index,\n\s*\)",
        r"child: _QuizGridCard(\n                                    item: item,\n                                    index: index,\n                                    isLocked: isLocked,\n                                  )",
        content
    )

    # 4. Update _QuizGridCard class
    content = content.replace(
        "final Map<String, dynamic> item;\n  final int index;\n\n  const _QuizGridCard({required this.item, required this.index});",
        "final Map<String, dynamic> item;\n  final int index;\n  final bool isLocked;\n\n  const _QuizGridCard({super.key, required this.item, required this.index, this.isLocked = false});"
    )

    # 5. Add padlock overlay
    overlay = """                  if (isLocked)
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
                    ),"""

    content = re.sub(
        r"(Positioned\(\n\s*top: 10,\n\s*left: 10,)",
        overlay + r"\n                  \1",
        content
    )

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

update_materi()
update_kuis()
print("Flutter Lists Updated.")
