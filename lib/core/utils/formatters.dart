import 'package:intl/intl.dart';

class AppFormatters {
  
  // Usamos 'en_US' para que el separador de miles sea ',' y el decimal '.'
  static const String _locale = 'en_US';

  /// Muestra dinero: 1250.5 -> "1,250.50" (Formato Dólar estándar)
  static String money(double amount) {
    final formatter = NumberFormat.currency(
      locale: _locale, 
      symbol: '', 
      decimalDigits: 2
    );
    return formatter.format(amount).trim();
  }

  /// PARSER HÍBRIDO: Soluciona el problema del teclado en Español
  /// Si el usuario escribe "10,50" lo convierte a 10.50 para que Dart lo entienda.
  static double stringToDouble(String value) {
    if (value.isEmpty) return 0.0;
    
    // Reemplazamos la coma por punto (para teclados latinos)
    String clean = value.replaceAll(',', '.');
    
    // Eliminamos caracteres no numéricos excepto el punto
    clean = clean.replaceAll(RegExp(r'[^0-9.]'), '');
    
    return double.tryParse(clean) ?? 0.0;
  }
}