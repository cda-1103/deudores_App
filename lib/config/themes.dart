import 'package:flutter/material.dart';

class AppTheme {
  // --- PALETA DE COLORES "DARK SLATE" ---
  // Fondo principal (Azul muy oscuro, casi negro)
  static const Color background = Color(0xFF0F172A); 
  
  // Superficies (Tarjetas, Sidebar, AppBars - Slate 800)
  static const Color surface = Color(0xFF1E293B); 
  
  // Acento Principal (Azul brillante - Blue 500)
  static const Color primary = Color(0xFF3B82F6); 
  
  // Texto Secundario (Gris azulado - Slate 400)
  static const Color secondary = Color(0xFF94A3B8); 
  
  // Colores semánticos
  static const Color accentGreen = Color(0xFF10B981); // Emerald 500
  static const Color accentRed = Color(0xFFEF4444);   // Red 500
  static const Color textWhite = Color(0xFFF8FAFC);   // Slate 50
  
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      
      // Esquema de colores
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentGreen,
        surface: surface,
        background: background,
        error: accentRed,
      ),

      // --- TIPOGRAFÍA ---
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textWhite),
        bodyMedium: TextStyle(color: secondary),
      ),

      // --- TARJETAS (CARDS) ---
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),

      // --- APP BAR ---
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20, 
          fontWeight: FontWeight.bold, 
          color: textWhite,
          letterSpacing: 0.5
        ),
        iconTheme: IconThemeData(color: textWhite),
      ),

      // --- BOTONES ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      // --- CAMPOS DE TEXTO ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary)),
        hintStyle: const TextStyle(color: secondary),
        labelStyle: const TextStyle(color: secondary),
        prefixIconColor: secondary,
      ),

      // --- DIÁLOGOS ---
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),

      // --- NAVIGATION BAR (MÓVIL) ---
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary)
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: secondary);
        }),
      ),
    );
  }
}