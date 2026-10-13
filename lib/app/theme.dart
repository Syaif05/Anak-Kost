import 'package:flutter/material.dart';

/// Design System Aplikasi (Mengadaptasi Bahasa Visual Modern & Clean)
/// Karakteristik:
/// - Primary: Deep Dark Teal (#062F3B)
/// - Background: Soft Clean Off-White (#FAFBFC)
/// - Surface: Pure White (#FFFFFF) & Surface Secondary (#F1F3F4)
/// - Text: Primary (#172B33), Secondary (#68777D)
/// - Border: Fine Clean Outline (#E6EBED)
/// - Radius: Card 20-24, Button/Input 14-16, Nav Capsule 36
abstract class AppTheme {
  // Brand Color Palette
  static const Color primaryTeal = Color(0xFF062F3B);
  static const Color primaryTealLight = Color(0xFF0B4657);
  static const Color primaryTealContainer = Color(0xFFE5F1F5);
  
  static const Color background = Color(0xFFFAFBFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F3F4);
  
  static const Color textPrimary = Color(0xFF172B33);
  static const Color textSecondary = Color(0xFF68777D);
  static const Color textTertiary = Color(0xFF9AA8AF);
  
  static const Color borderColor = Color(0xFFE6EBED);
  
  // Status Colors
  static const Color success = Color(0xFF1B8755);
  static const Color successContainer = Color(0xFFE8F6EE);
  
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  
  static const Color error = Color(0xFFD32F2F);
  static const Color errorContainer = Color(0xFFFDE8E8);
  static const Color danger = error;
  static const Color dangerContainer = errorContainer;

  // Dark/Amoled Support
  static const Color darkBackground = Color(0xFF0C1317);
  static const Color amoledBlack = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF131D22);
  static const Color darkSurfaceSecondary = Color(0xFF1B272D);
  static const Color darkBorder = Color(0xFF263840);

  // Spacing Constants (4/8-point grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Corner Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusButton = 14.0;
  static const double radiusLarge = 16.0;
  static const double radiusCard = 22.0;
  static const double radiusPill = 999.0;

  static ThemeData lightTheme() {
    final colorScheme = const ColorScheme.light(
      primary: primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: primaryTealContainer,
      onPrimaryContainer: primaryTeal,
      secondary: primaryTealLight,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: error,
      onError: Colors.white,
      outline: borderColor,
      outlineVariant: surfaceSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTeal,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: error, width: 1),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryTeal,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryTeal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.white.withAlpha(40),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData darkTheme({bool isAmoled = true}) {
    final bgColor = isAmoled ? amoledBlack : darkBackground;
    final surfaceColor = isAmoled ? const Color(0xFF10161A) : darkSurface;
    final surfaceSec = isAmoled ? const Color(0xFF182025) : darkSurfaceSecondary;

    final colorScheme = ColorScheme.dark(
      primary: const Color(0xFF5BA4B8),
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF163C46),
      onPrimaryContainer: Colors.white,
      secondary: const Color(0xFF75B8C9),
      onSecondary: Colors.black,
      surface: surfaceColor,
      onSurface: Colors.white,
      error: const Color(0xFFEF5350),
      onError: Colors.black,
      outline: darkBorder,
      outlineVariant: surfaceSec,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSec,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
