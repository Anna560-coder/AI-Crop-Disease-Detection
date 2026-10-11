import 'package:flutter/material.dart';

/// App name and tagline in one place so they are easy to change.
class AppStrings {
  static const String appName = "Crop Doctor";
  static const String tagline =
      "AI crop disease detection for small-scale farmers";
}

/// Agriculture-inspired colour palette: leaf greens, harvest gold and soil
/// brown, with clear red/orange/green for disease status.
class AppColors {
  static const Color primary = Color(0xFF2E7D32); // leaf green
  static const Color primaryDark = Color(0xFF1B5E20); // deep forest green
  static const Color primaryLight = Color(0xFFE8F5E9); // young leaf
  static const Color accent = Color(0xFFF9A825); // harvest gold
  static const Color soil = Color(0xFF6D4C41); // soil brown
  static const Color background = Color(0xFFF4F7EF); // light field
  static const Color textDark = Color(0xFF1F2A1F);
  static const Color textMuted = Color(0xFF5F6B5F);

  static const Color healthy = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
      error: AppColors.danger,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      // Slightly larger text than default: easier to read outdoors.
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(fontSize: 17, color: AppColors.textDark),
        bodyMedium: TextStyle(fontSize: 15.5, color: AppColors.textDark),
        bodySmall: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Big buttons (56px tall) are easy to tap, even with work gloves.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 56),
          shape: buttonShape,
          textStyle: buttonText,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        prefixIconColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCFD8CC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCFD8CC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black26,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        contentTextStyle: const TextStyle(fontSize: 15.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
