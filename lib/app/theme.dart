import 'package:flutter/material.dart';

/// Tema Aplikasi Anak Kost (Material 3)
/// Sesuai PRD GAMINI.md Bagian 5.3:
/// - Warna aksen utama: Indigo / Teal netral
/// - Mode Terang, Gelap, dan AMOLED Dark (Galaxy S24+ optimized)
/// - Kontras tinggi & whitespace bersih
abstract class AppTheme {
  static const Color primarySeed = Color(0xFF3F51B5); // Indigo
  static const Color accentTeal = Color(0xFF009688); // Teal
  static const Color darkBackground = Color(0xFF121212);
  static const Color amoledBlack = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF141416);

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      primary: primarySeed,
      secondary: accentTeal,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: primarySeed.withAlpha(40),
      ),
    );
  }

  static ThemeData darkTheme({bool isAmoled = true}) {
    final bgColor = isAmoled ? amoledBlack : darkBackground;
    final surfaceColor = isAmoled ? amoledSurface : const Color(0xFF1E1E1E);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
      surface: surfaceColor,
      primary: const Color(0xFF7986CB),
      secondary: const Color(0xFF4DB6AC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: bgColor,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: const Color(0xFF7986CB).withAlpha(60),
      ),
    );
  }
}
