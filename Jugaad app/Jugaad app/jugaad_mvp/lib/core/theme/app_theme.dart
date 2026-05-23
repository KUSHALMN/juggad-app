import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Common Text Theme Base
  static TextTheme _baseTextTheme(Color primaryColor, Color secondaryColor) {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w500, color: primaryColor),
      headlineMedium: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w500, color: primaryColor),
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: primaryColor),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: primaryColor),
      labelLarge: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: primaryColor),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w400, color: secondaryColor),
      bodySmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w400, color: secondaryColor),
    );
  }

  // Base Theme configurations
  static ThemeData _buildBaseTheme({
    required Color primary,
    required Color primaryLight,
    required ColorScheme colorScheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.kBackground,
      textTheme: _baseTextTheme(AppColors.kTextPrimary, AppColors.kTextSecond),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.kBorder, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.kDanger),
        ),
        labelStyle: const TextStyle(color: AppColors.kTextSecond),
        hintStyle: const TextStyle(color: AppColors.kTextTertiary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.kBackground,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.kBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }

  // User Theme
  static ThemeData userTheme() {
    return _buildBaseTheme(
      primary: AppColors.kUserPrimary,
      primaryLight: AppColors.kUserPrimaryLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.kUserPrimary,
        secondary: AppColors.kUserPrimaryLight,
        error: AppColors.kDanger,
        surface: AppColors.kSurface,
      ),
    );
  }

  // Worker Theme
  static ThemeData workerTheme() {
    return _buildBaseTheme(
      primary: AppColors.kWorkerPrimary,
      primaryLight: AppColors.kWorkerPrimaryLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.kWorkerPrimary,
        secondary: AppColors.kWorkerPrimaryLight,
        error: AppColors.kDanger,
        surface: AppColors.kSurface,
      ),
    );
  }
}
