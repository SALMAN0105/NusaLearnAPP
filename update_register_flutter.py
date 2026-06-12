import re

# Update register_screen.dart
path_register = r'c:\xampp\htdocs\nusalearn\lib\ui\screens\register_screen.dart'
with open(path_register, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _kelasController
content = re.sub(
    r'final _schoolController = TextEditingController\(\);',
    'final _schoolController = TextEditingController();\n  final _kelasController = TextEditingController();',
    content
)

# Add validation for kelas
content = re.sub(
    r'final data = \{',
    r'''if (_kelasController.text.isEmpty) {
      showCustomSnackbar(context, "Pilih kelasmu dulu!", isError: true);
      return;
    }

    final data = {''',
    content
)

# Add kelas to data
content = re.sub(
    r"'kode_pos': _postalCodeController\.text,",
    "'kode_pos': _postalCodeController.text,\n      'kelas': int.tryParse(_kelasController.text) ?? 1,",
    content
)

# Add UI for Kelas Dropdown
kelas_dropdown = """
                            // Dropdown Kelas Neo-Brutalism
                            const SizedBox(height: 16),
                            Text(
                              "KELAS",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryDark,
                                  width: 2,
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _kelasController.text.isEmpty ? null : _kelasController.text,
                                hint: Text(
                                  "Pilih Kelasmu",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down_circle_outlined,
                                  color: AppColors.brandPurple,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(
                                    Icons.school_rounded,
                                    color: AppColors.brandPurple,
                                  ),
                                ),
                                isExpanded: true,
                                items: ["1", "2", "3", "4", "5", "6"].map((String cls) {
                                  return DropdownMenuItem<String>(
                                    value: cls,
                                    child: Text(
                                      "Kelas $cls",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _kelasController.text = newValue ?? "";
                                  });
                                },
                              ),
                            ),
"""

# Insert the Dropdown after _passwordController
content = content.replace(
    '''                            ModernTextField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_rounded,
                              isPassword: true,
                            ),''',
    '''                            ModernTextField(
                              controller: _passwordController,
                              label: "Password",
                              icon: Icons.lock_rounded,
                              isPassword: true,
                            ),''' + kelas_dropdown
)

# Also fix the data passed to provider to use nama not name in register_screen
content = content.replace("'name': _nameController.text,", "'nama': _nameController.text,")

with open(path_register, 'w', encoding='utf-8') as f:
    f.write(content)

# Update auth_provider.dart
path_auth = r'c:\xampp\htdocs\nusalearn\lib\logic\providers\auth_provider.dart'
with open(path_auth, 'r', encoding='utf-8') as f:
    auth_content = f.read()

auth_content = re.sub(
    r"'name': data\['nama'\],",
    "'nama': data['nama'],",
    auth_content
)

auth_content = re.sub(
    r"'kode_pos': data\['kode_pos'\],",
    "'kode_pos': data['kode_pos'],\n          'kelas': data['kelas'],",
    auth_content
)

with open(path_auth, 'w', encoding='utf-8') as f:
    f.write(auth_content)

print("Flutter Auth and Register Screen Updated.")
