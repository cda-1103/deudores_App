import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SalesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Registra una venta, divide la cuenta y crea el log de auditoría
  Future<void> processSaleWithCustomSplit({
    required Map<String, double> splitData, 
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? note,
    DateTime? customDate,
  }) async {
    if (splitData.isEmpty) throw Exception("Debe seleccionar al menos un cliente.");

    final String dateToSave = (customDate ?? DateTime.now()).toUtc().toIso8601String();

    // Generar resumen para la descripción
    String itemsSummary = items.map((i) => "${i['qty']}x ${i['item_name']}").join(", ");
    if (itemsSummary.length > 150) {
      itemsSummary = "${itemsSummary.substring(0, 147)}...";
    }

    try {
      // 1. Cabecera de Venta
      final saleResponse = await _supabase.from('sales').insert({
        'total_amount': totalAmount,
        'note': note,
        'created_at': dateToSave,
      }).select().single();

      final String saleId = saleResponse['id'];
      final int correlative = saleResponse['correlative_id'];

      // 2. Items
      if (items.isNotEmpty) {
        final List<Map<String, dynamic>> saleItemsPayload = items.map((item) {
          return {
            'sale_id': saleId,
            'item_name': item['name'],
            'product_id': item['productId'],
            'quantity': item['qty'],
            'unit_price': item['price'],
            'total': (item['price'] as double) * (item['qty'] as int),
          };
        }).toList();
        await _supabase.from('sale_items').insert(saleItemsPayload);
      }

      // 3. Movimientos (Deuda)
      String clientNames = ""; // Para el log
      
      for (var entry in splitData.entries) {
        final customerId = entry.key;
        final amountToPay = entry.value;

        await _supabase.from('movements').insert({
          'customer_id': customerId,
          'sale_id': saleId,
          'type': 'DEBT',
          'amount': amountToPay, 
          'payment_method': 'Cuenta',
          'description': 'Venta #$correlative: $itemsSummary', 
          'created_at': dateToSave,
        });
        
        // (Opcional: Obtener nombre para el log, aunque consume más recursos)
        // clientNames += "$customerId "; 
      }

      // 4. AUDITORÍA (LOG)
      final user = _supabase.auth.currentUser;
      final userEmail = user?.email ?? 'Desconocido';
      final nowStr = DateFormat('dd/MM HH:mm').format(DateTime.now());
      
      await _supabase.from('action_logs').insert({
        'user_email': userEmail,
        'action': 'Nueva Venta',
        'details': 'Venta #$correlative por \$$totalAmount ($nowStr)',
        'created_at': DateTime.now().toUtc().toIso8601String() // Fecha real del sistema
      });

    } catch (e) {
      print('Error procesando venta: $e');
      rethrow;
    }
  }
}