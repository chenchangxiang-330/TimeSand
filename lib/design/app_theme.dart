import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _ink = Color(0xFF29251F);
  static const _sand = Color(0xFFE8C98D);
  static const _canvas = Color(0xFFF7F3EC);
  static const _muted = Color(0xFF766F65);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _sand,
      brightness: Brightness.light,
      surface: _canvas,
    );

    return ThemeData(
      colorScheme: colorScheme.copyWith(
        onSurface: _ink,
        primary: _ink,
        secondary: _sand,
      ),
      scaffoldBackgroundColor: _canvas,
      useMaterial3: true,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
        ),
        headlineSmall: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: _ink,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: _muted,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white.withOpacity(0.72),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
