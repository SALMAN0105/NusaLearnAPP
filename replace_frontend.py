import os
import re

base_dir = r'c:\xampp\htdocs\nusalearn\lib'

snake_fields = {
    'image_url': 'url_gambar',
    'username': 'nama_pengguna',
    'password': 'kata_sandi',
    'access_code': 'kode_akses',
    'postal_code': 'kode_pos',
    'language_code': 'kode_bahasa',
    'school_origin': 'asal_sekolah',
    'is_active': 'aktif',
    'remember_token': 'token_ingat',
    'created_at': 'dibuat_pada',
    'updated_at': 'diperbarui_pada',
    'deleted_at': 'dihapus_pada',
    'title_indo': 'judul',
    'content_indo': 'konten',
    'ai_status': 'status_ai',
    'ai_processed_at': 'ai_diproses_pada',
    'level_difficulty': 'tingkat_kesulitan',
    'material_id': 'materi_id',
    'question_text_indo': 'teks_soal',
    'options_json': 'opsi_json',
    'correct_answer_key': 'kunci_jawaban',
    'difficulty_weight': 'bobot_kesulitan',
    'template_type': 'tipe_template',
    'question_data': 'data_soal',
    'assets_required': 'aset_diperlukan',
    'user_id': 'pengguna_id',
    'question_id': 'soal_id',
    'student_answer': 'jawaban_siswa',
    'student_answer_json': 'jawaban_siswa_json',
    'answer_data': 'data_jawaban',
    'is_correct': 'benar',
    'points_earned': 'poin_diperoleh',
    'time_spent_seconds': 'waktu_detik',
    'is_synced': 'sinkron',
    'synced_at': 'disinkron_pada',
    'answered_at': 'dijawab_pada',
    'district_name': 'nama_kecamatan',
}

camel_fields = {
    'imageUrl': 'urlGambar',
    'username': 'namaPengguna',
    'password': 'kataSandi',
    'accessCode': 'kodeAkses',
    'postalCode': 'kodePos',
    'languageCode': 'kodeBahasa',
    'schoolOrigin': 'asalSekolah',
    'isActive': 'aktif',
    'rememberToken': 'tokenIngat',
    'createdAt': 'dibuatPada',
    'updatedAt': 'diperbaruiPada',
    'deletedAt': 'dihapusPada',
    'titleIndo': 'judul',
    'contentIndo': 'konten',
    'aiStatus': 'statusAi',
    'aiProcessedAt': 'aiDiprosesPada',
    'levelDifficulty': 'tingkatKesulitan',
    'materialId': 'materiId',
    'questionTextIndo': 'teksSoal',
    'optionsJson': 'opsiJson',
    'correctAnswerKey': 'kunciJawaban',
    'difficultyWeight': 'bobotKesulitan',
    'templateType': 'tipeTemplate',
    'questionData': 'dataSoal',
    'assetsRequired': 'asetDiperlukan',
    'userId': 'penggunaId',
    'questionId': 'soalId',
    'studentAnswer': 'jawabanSiswa',
    'studentAnswerJson': 'jawabanSiswaJson',
    'answerData': 'dataJawaban',
    'isCorrect': 'benar',
    'pointsEarned': 'poinDiperoleh',
    'timeSpentSeconds': 'waktuDetik',
    'isSynced': 'sinkron',
    'syncedAt': 'disinkronPada',
    'answeredAt': 'dijawabPada',
    'districtName': 'namaKecamatan',
}

table_names = {
    'materials': 'materi',
    'questions': 'soal',
    'student_progress': 'progres_siswa',
    'users': 'pengguna',
}

# Add role, category, name separately to avoid collisions
standalone_replacements = [
    (r"\['name'\]", "['nama']"),
    (r"\['role'\]", "['peran']"),
    (r"\['category'\]", "['kategori']"),
    (r"\['points'\]", "['poin']"),
]

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content

    # 1. Snake case (keys in maps, DB queries)
    # usually surrounded by quotes
    for old, new in snake_fields.items():
        content = re.sub(r"'" + old + r"'", f"'{new}'", content)
        content = re.sub(r'"' + old + r'"', f'"{new}"', content)
        # Also handle word boundary for unquoted (like SQL strings without quotes)
        content = re.sub(r'\b' + old + r'\b', new, content)

    # 2. Camel case (Dart variables, named parameters, class properties)
    for old, new in camel_fields.items():
        content = re.sub(r'\b' + old + r'\b', new, content)
        
    # 3. Table names
    for old, new in table_names.items():
        content = re.sub(r"'" + old + r"'", f"'{new}'", content)
        content = re.sub(r'"' + old + r'"', f'"{new}"', content)

    # 4. Standalone dictionary
    for old_regex, new_val in standalone_replacements:
        content = re.sub(old_regex, new_val, content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated: {filepath}")

for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            process_file(filepath)

print("Frontend replacement complete.")
