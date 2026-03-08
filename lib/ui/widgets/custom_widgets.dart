import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =========================================================
// DESIGN TOKENS (Neo-Brutalism Palette)
// =========================================================
class AppColors {
  static const Color primaryDark = Color(0xFF000000);
  static const Color accentLime = Color(0xFFD1FF27);
  static const Color brandPurple = Color(0xFFC299FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color errorColor = Color(0xFFFF4C4C);
  static const Color errorBg = Color(0xFFFFE5E5);
}

// =========================================================
// GRID BACKGROUND PAINTER (Efisiensi O(N))
// =========================================================
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryDark.withOpacity(0.06)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 32) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 32) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =========================================================
// 1. INPUT TEXT MODERN (NEO-BRUTALISM)
// =========================================================
// =========================================================
// 1. INPUT TEXT MODERN (DENGAN FITUR MATA / SHOW PASSWORD)
// =========================================================
class ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint; // <-- INI TAMBAHAN BARU UNTUK PLACEHOLDER
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint, // <-- INI TAMBAHAN BARU
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  bool _isObscured = true;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(
            _isFocused ? -2 : 0,
            _isFocused ? -2 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryDark, width: 2),
            boxShadow: [
              if (_isFocused)
                const BoxShadow(
                  color: AppColors.primaryDark,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword ? _isObscured : false,
            keyboardType: widget.keyboardType,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              hintText:
                  widget.hint ??
                  widget.label, // <-- INI MENGGUNAKAN PLACEHOLDER BARU
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppColors.textMuted,
              ),
              prefixIcon: Icon(widget.icon, color: AppColors.brandPurple),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _isObscured ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _isObscured = !_isObscured),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =========================================================
// 2. BOUNCY BUTTON (NEO-BRUTALISM)
// =========================================================
class BouncyButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;

  const BouncyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = AppColors.accentLime,
    this.isLoading = false,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 60,
        transform: Matrix4.translationValues(
          _isPressed && !isDisabled ? 2 : 0,
          _isPressed && !isDisabled ? 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFFE0E0E0) : widget.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDisabled ? Colors.transparent : AppColors.primaryDark,
            width: 2,
          ),
          boxShadow: [
            if (!isDisabled && !_isPressed)
              const BoxShadow(
                color: AppColors.primaryDark,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            if (!isDisabled && _isPressed)
              const BoxShadow(
                color: AppColors.primaryDark,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
          ],
        ),
        child: Center(
          child: widget.isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "LOADING...",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDark,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.text,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.east_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =========================================================
// 3. SNACKBAR NEO-BRUTALISM
// =========================================================
void showCustomSnackbar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
      content: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? AppColors.errorColor : AppColors.accentLime,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryDark, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.primaryDark,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryDark, width: 2),
              ),
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: isError ? AppColors.errorColor : AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? "Ups, Gagal" : "Mantap!",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isError ? AppColors.white : AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isError ? AppColors.white : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
