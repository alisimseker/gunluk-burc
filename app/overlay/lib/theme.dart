import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0E0B1A);
  static const bg2 = Color(0xFF17122B);
  static const card = Color(0xFF1C1633);
  static const cardHi = Color(0xFF261E44);
  static const line = Color(0x26E8C77B);
  static const gold = Color(0xFFE8C77B);
  static const goldSoft = Color(0xFFF3DFAE);
  static const text = Color(0xFFF4F1FA);
  static const muted = Color(0xFFA59EC2);
  static const violet = Color(0xFF8B6CF0);

  static const fire = Color(0xFFF08A5D);
  static const earth = Color(0xFF8CC084);
  static const air = Color(0xFF7FB7F0);
  static const water = Color(0xFF6E8BF0);

  static Color element(String e) => switch (e) {
        'Ateş' => fire,
        'Toprak' => earth,
        'Hava' => air,
        _ => water,
      };
}

class AppText {
  static TextStyle display(double size, {Color color = AppColors.text, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.getFont('Cormorant Garamond', fontSize: size, color: color, fontWeight: w, height: 1.15);

  static TextStyle body(double size,
          {Color color = AppColors.text, FontWeight w = FontWeight.w400, double height = 1.5, double spacing = 0}) =>
      GoogleFonts.getFont('Manrope', fontSize: size, color: color, fontWeight: w, height: height, letterSpacing: spacing);

  static TextStyle label(double size, {Color color = AppColors.gold}) =>
      GoogleFonts.getFont('Manrope', fontSize: size, color: color, fontWeight: FontWeight.w700, letterSpacing: 1.6);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
      surface: AppColors.bg,
      primary: AppColors.gold,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.getFont('Manrope').fontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.display(24),
      foregroundColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.gold)),
      labelStyle: AppText.body(14, color: AppColors.muted),
      hintStyle: AppText.body(14, color: AppColors.muted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardHi,
      contentTextStyle: AppText.body(14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Altın kenarlı yumuşak kart
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double radius;
  const GlassCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.gradient,
      this.onTap,
      this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.card : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: box),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  const GoldButton({super.key, required this.text, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: onPressed == null
              ? null
              : const LinearGradient(colors: [Color(0xFFF3DFAE), Color(0xFFD9B25F)]),
          color: onPressed == null ? AppColors.card : null,
          boxShadow: onPressed == null
              ? null
              : [BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
              foregroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: loading
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.bg))
              : Text(text,
                  style: AppText.body(16,
                      color: onPressed == null ? AppColors.muted : AppColors.bg, w: FontWeight.w700)),
        ),
      ),
    );
  }
}
