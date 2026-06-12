import re

filepath = r'c:\xampp\htdocs\nusalearn\lib\core\database\database_helper.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix table names in SQL
content = re.sub(r'\bTABLE users\b', 'TABLE pengguna', content)
content = re.sub(r'\bTABLE materials\b', 'TABLE materi', content)
content = re.sub(r'\bTABLE questions\b', 'TABLE soal', content)
content = re.sub(r'\bTABLE student_progress\b', 'TABLE progres_siswa', content)

# Fix remaining columns in CREATE TABLE
content = re.sub(r'\bname TEXT\b', 'nama TEXT', content)
content = re.sub(r'\bcategory TEXT\b', 'kategori TEXT', content)
content = re.sub(r'\bcontent_json TEXT\b', 'konten TEXT', content)

# Also fix the queries that might still use old table names
content = re.sub(r"'users'", "'pengguna'", content)
content = re.sub(r"'materials'", "'materi'", content)
content = re.sub(r"'questions'", "'soal'", content)
content = re.sub(r"'student_progress'", "'progres_siswa'", content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("database_helper.dart fixed")
