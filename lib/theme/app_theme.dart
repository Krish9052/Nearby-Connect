import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF1769E0);
  static const Color background = Color(0xFFF7F9FC);
  static const Color textDark = Color(0xFF172B4D);
  static const Color textGrey = Color(0xFF718096);
  static const Color cardWhite = Colors.white;
  static const Color onlineGreen = Color(0xFF18A66A);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    scaffoldBackgroundColor: background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textDark,
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: textDark,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: textDark,
      ),
      bodyMedium: TextStyle(
        color: textGrey,
      ),
    ),

    cardTheme: CardThemeData(
      color: cardWhite,
      elevation: 3,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    ),
  );
}