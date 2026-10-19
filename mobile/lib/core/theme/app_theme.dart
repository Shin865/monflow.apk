import 'package:flutter/material.dart';

/// App color palette — dark theme optimized for financial apps.
class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Backgrounds
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B); // Slate 800
  static const Color surfaceLight = Color(0xFF334155); // Slate 700
  static const Color card = Color(0xFF1E293B);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Semantic
  static const Color income = Color(0xFF10B981); // Emerald 500
  static const Color incomeBg = Color(0xFF064E3B); // Emerald 900
  static const Color expense = Color(0xFFEF4444); // Red 500
  static const Color expenseBg = Color(0xFF7F1D1D); // Red 900
  static const Color transfer = Color(0xFF3B82F6); // Blue 500
  static const Color transferBg = Color(0xFF1E3A5F);
  static const Color refund = Color(0xFFF59E0B); // Amber 500
  static const Color refundBg = Color(0xFF78350F); // Amber 900
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // Borders
  static const Color border = Color(0xFF334155); // Slate 700
  static const Color divider = Color(0xFF1E293B);
}

/// App typography and theme.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        displayMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        displaySmall:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineLarge:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        headlineSmall:
            TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        titleSmall: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
        bodyMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        bodySmall: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
        labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        labelMedium:
            TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        labelSmall: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
      ),
    );
  }
}
