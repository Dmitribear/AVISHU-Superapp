import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get brutalistTheme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.white,
      primaryColor: AppColors.black,
      colorScheme: const ColorScheme.light(
        primary: AppColors.black,
        secondary: AppColors.white,
        surface: AppColors.white,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.black,
        thickness: 1,
        space: 1,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.black, width: 1),
          shape: const BeveledRectangleBorder(), // brutalist square edges
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.black,
          shape: const BeveledRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
}
