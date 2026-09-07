import 'package:flutter/material.dart';

import '../models/bootstrap_data.dart';
import '../ui/neizami_ui.dart';

ThemeData buildAppTheme(Branding branding) {
  final ui = NeizamiUiTokens.fromBranding(branding);
  final scheme = ColorScheme.fromSeed(
    seedColor: branding.primary,
    primary: branding.primary,
    secondary: branding.secondary,
    surface: branding.surface,
    error: branding.danger,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: branding.background,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[ui],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: branding.surface,
      foregroundColor: branding.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: branding.text,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
      shape: Border(bottom: BorderSide(color: branding.border)),
    ),
    cardTheme: CardThemeData(
      color: branding.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radius),
        side: BorderSide(color: branding.border),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: branding.border,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: branding.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      hintStyle: TextStyle(color: branding.muted, fontWeight: FontWeight.w500),
      labelStyle: TextStyle(color: branding.muted, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ui.radius - 2),
        borderSide: BorderSide(color: branding.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ui.radius - 2),
        borderSide: BorderSide(color: branding.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ui.radius - 2),
        borderSide: BorderSide(color: branding.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ui.radius - 2),
        borderSide: BorderSide(color: branding.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ui.radius - 2),
        borderSide: BorderSide(color: branding.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: branding.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radius - 2),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: branding.primary,
        side: BorderSide(color: branding.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radius - 2),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: branding.surface,
      selectedColor: ui.primarySoft,
      side: BorderSide(color: branding.border),
      labelStyle: TextStyle(color: branding.text, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(color: branding.primary, fontWeight: FontWeight.w900),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: branding.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ui.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) ? branding.primary : branding.muted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? branding.primary : branding.muted,
        );
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: branding.primary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
