import 'package:intl/intl.dart';

class AppFormatters {
  // Configuración regional para Venezuela (miles con punto, decimales con coma)
  static const String _locale = 'es_VE';

  /// Muestra dinero bonito: 1250.5 -> "1.250,50"
  static String money(double amount) {
    // Usamos NumberFormat.currency pero le quitamos el símbolo para ponerlo nosotros si queremos
    final formatter = NumberFormat.currency(
        locale: _locale,
        symbol: '', // Sin símbolo automático para tener control manual
        decimalDigits: 2);
    return formatter.format(amount).trim();
  }

  /// Convierte texto del usuario ("10,50") a número real (10.50) para cálculos
  static double stringToDouble(String value) {
    if (value.isEmpty) return 0.0;

    // 1. Quitamos separadores de miles (puntos) si el usuario los puso
    String clean = value.replaceAll('.', '');

    // 2. Cambiamos la coma decimal por punto (que es lo que entiende Dart/Inglés)
    clean = clean.replaceAll(',', '.');

    return double.tryParse(clean) ?? 0.0;
  }
}
