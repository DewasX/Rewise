import 'package:flutter/material.dart';

class AppColors {
  // Background & Surface
  static const Color background = Color(0xFF0F0F1A); // Darker almost black
  static const Color surface = Color(0xFF1B1B2F);    // High-fidelity navy card
  static const Color surfaceLight = Color(0xFF2E2E48);
  
  // Light Mode Colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLightMode = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Brand Colors
  static const Color primary = Color(0xFF6366F1);    // Indigo
  static const Color accent = Color(0xFFFACC15);     // Yellow for streaks/memory
  
  // Status Colors
  static const Color strong = Color(0xFF10B981);
  static const Color fading = Color(0xFFF59E0B);
  static const Color urgent = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Text
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
}

class AppDesign {
  static const double radius = 24.0;
  static const double padding = 20.0;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.primary,
      useMaterial3: true,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surfaceLightMode,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.urgent,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      dividerTheme: DividerThemeData(color: AppColors.textPrimaryLight.withValues(alpha: 0.1)),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLightMode,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radius),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimaryLight,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
      useMaterial3: true,
      fontFamily: 'Outfit',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.urgent,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.1)),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radius),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
