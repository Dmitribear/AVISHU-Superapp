import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTypography {
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme().copyWith(
      displayLarge: _display(54),
      displayMedium: _display(40),
      headlineLarge: _headline(28),
      headlineMedium: _headline(22),
      titleLarge: _title(18),
      titleMedium: _title(16, weight: FontWeight.w700),
      bodyLarge: _body(16),
      bodyMedium: _body(14),
      bodySmall: _body(12, color: AppColors.secondary, height: 1.55),
      labelLarge: _label(13),
      labelMedium: _label(11),
      labelSmall: _label(10, color: AppColors.outline),
    );
  }

  static TextStyle get brandMark => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 7,
    height: 1,
    color: AppColors.black,
  );

  static TextStyle get eyebrow => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.8,
    color: AppColors.outline,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.8,
    color: AppColors.black,
  );

  static TextStyle get metricValue => GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    color: AppColors.black,
    height: 1,
  );

  static TextStyle get code => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.secondary,
  );

  static TextStyle _display(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 5,
    height: 0.94,
    color: AppColors.black,
  );

  static TextStyle _headline(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
    height: 1.02,
    color: AppColors.black,
  );

  static TextStyle _title(double size, {FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.4,
        height: 1.1,
        color: AppColors.black,
      );

  static TextStyle _body(
    double size, {
    Color color = AppColors.black,
    double height = 1.6,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: height,
    color: color,
  );

  static TextStyle _label(double size, {Color color = AppColors.black}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        height: 1.2,
        color: color,
      );
}
