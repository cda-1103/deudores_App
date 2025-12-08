import 'package:flutter/material.dart';

class AppTheme {
  // Paleta extraída de tus referencias (Estilo Dark Slate)
  static const Color background =
      Color(0xFF0F172A); // Fondo muy oscuro (Slate 900)
  static const Color surface =
      Color(0xFF1E293B); // Tarjetas/Sidebar (Slate 800)
  static const Color primary = Color(0xFF3B82F6); // Azul Brillante (Blue 500)
  static const Color secondary =
      Color(0xFF64748B); // Texto secundario (Slate 500)
  static const Color accentGreen = Color(0xFF10B981); // Verdes (Pagos)
  static const Color accentRed = Color(0xFFEF4444); // Rojos (Deudas)
  static const Color textWhite = Color(0xFFF1F5F9); // Texto principal

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentGreen,
        surface: surface,
        background: background,
        error: accentRed,
      ),
      // CORRECCIÓN 1: Usamos CardThemeData en lugar de CardTheme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: textWhite),
        iconTheme: IconThemeData(color: textWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        hintStyle: const TextStyle(color: secondary),
        labelStyle: const TextStyle(color: textWhite),
      ),
      textTheme: const TextTheme(
        headlineMedium:
            TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textWhite),
        bodyMedium: TextStyle(color: Colors.grey),
      ),
      // CORRECCIÓN 2: Usamos DialogThemeData en lugar de DialogTheme
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }
}
