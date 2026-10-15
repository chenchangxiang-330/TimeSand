import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF193A58);
  static const blue = Color(0xFF287AC5);
  static const muted = Color(0xFF4C6981);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
          surface: const Color(0xFFF2F8FC),
        ).copyWith(
          primary: blue,
          onSurface: ink,
          secondary: const Color(0xFF47A9B1),
        );
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xBFFFFFFF)),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['NotoSansSC', 'PingFang SC', 'sans-serif'],
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: ink,
          fontWeight: FontWeight.w500,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(color: ink, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: ink, height: 1.5),
        bodyMedium: TextStyle(color: muted, height: 1.45),
        labelLarge: TextStyle(color: ink, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xA6F1F8FD),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xB8F5FAFE),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFF0F7FC),
        shape: border,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFF0F7FC),
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xEFFFFFFF),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0x66287AC5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x33193A58)),
    );
  }
}
