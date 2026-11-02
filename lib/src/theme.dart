import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'motion.dart';

ThemeData trustTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B6E4F),
    brightness: brightness,
  );
  return ThemeData(
    fontFamily: 'Tajawal',
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: TrustPageTransitions(),
        TargetPlatform.windows: TrustPageTransitions(),
        TargetPlatform.linux: TrustPageTransitions(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: colors,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101916)
        : const Color(0xFFF7F8F7),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101916) : const Color(0xFFF7F8F7),
      foregroundColor: colors.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? colors.surfaceContainer : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? colors.primary : const Color(0xFF0B6E4F),
        foregroundColor: dark ? colors.onPrimary : Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: dark ? colors.onSurface : const Color(0xFF063D2C),
      ),
      titleLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.65),
    ),
  );
}
