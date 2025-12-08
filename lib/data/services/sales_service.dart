import 'package:supabase_flutter/supabase_flutter.dart';

class SalesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lógica anterior (Mantenemos por compatibilidad)
  Future<void> processSale({
    required List<String> selectedCustomerIds,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? note,
    DateTime? customDate,
  }) async {
    Map<String, double> splitData = {};
    double perPerson = totalAmount / selectedCustomerIds.length;
    for (var id in selectedCustomerIds) {
      splitData[id] = perPerson;
    }

    await processSaleWithCustomSplit(
        splitData: splitData,
        items: items,
        totalAmount: totalAmount,
        note: note,
        customDate: customDate);
  }

  /// NUEVA FUNCIÓN MAESTRA
  Future<void> processSaleWithCustomSplit({
    required Map<String, double> splitData,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? note,
    DateTime? customDate,
  }) async {
    if (splitData.isEmpty)
      throw Exception("Debe seleccionar al menos un cliente.");

    final String dateToSave = (customDate ?? DateTime.now()).toIso8601String();

    // 1. GENERAR RESUMEN (Ej: "2x Ron, 1x Hielo")
    String itemsSummary =
        items.map((i) => "${i['qty']}x ${i['name']}").join(", ");
    // Cortamos si es muy largo para que quepa en la base de datos
    if (itemsSummary.length > 100) {
      itemsSummary = "${itemsSummary.substring(0, 97)}...";
    }

    try {
      // A. Insertar Cabecera de Venta
      final saleResponse = await _supabase
          .from('sales')
          .insert({
            'total_amount': totalAmount,
            'note': note,
            'created_at': dateToSave,
          })
          .select()
          .single();

      final String saleId = saleResponse['id'];
      final int correlative = saleResponse['correlative_id'];

      // B. Insertar Items
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

      // C. INSERTAR MOVIMIENTOS CON MEJOR DESCRIPCIÓN
      for (var entry in splitData.entries) {
        final customerId = entry.key;
        final amountToPay = entry.value;

        await _supabase.from('movements').insert({
          'customer_id': customerId,
          'sale_id': saleId,
          'type': 'DEBT',
          'amount': amountToPay,
          'payment_method': 'Cuenta',
          // AQUÍ ESTÁ EL CAMBIO: Usamos el resumen de items en lugar de texto genérico
          'description': 'Venta #$correlative: $itemsSummary',
          'created_at': dateToSave,
        });
      }
    } catch (e) {
      print('Error procesando venta: $e');
      rethrow;
    }
  }
}
