import 'package:flutter/material.dart';

import '../models/bootstrap_data.dart';

ThemeData buildAppTheme(Branding branding) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: branding.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: branding.primary,
      primary: branding.primary,
      secondary: branding.secondary,
      surface: branding.surface,
      error: branding.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: branding.surface,
      foregroundColor: branding.text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: branding.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(branding.radius),
        side: BorderSide(color: branding.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: branding.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(branding.radius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(branding.radius),
        ),
      ),
    ),
  );
}
