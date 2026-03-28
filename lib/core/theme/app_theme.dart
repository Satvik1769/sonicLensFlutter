import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF0D6EFD);
  static const _accent = Color(0xFF00D4FF);
  static const _bg = Color(0xFF080C14);
  static const _surface = Color(0xFF111827);
  static const _surfaceVariant = Color(0xFF1E293B);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          secondary: _accent,
          surface: _surface,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          color: _surfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surface,
          selectedItemColor: _accent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      );

  // Radar/pulse colors for the home screen animation
  static const radarInner = Color(0xFF0D6EFD);
  static const radarMiddle = Color(0x660D6EFD);
  static const radarOuter = Color(0x220D6EFD);
  static const radarGlow = Color(0xFF00D4FF);
}