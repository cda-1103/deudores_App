import 'dart:io';
import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class MigrationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Borra TODOS los datos y carga el Excel desde cero
  Future<void> resetAndMigrate(Uint8List fileBytes) async {
    try {
      debugPrint('--- INICIANDO REINICIO TOTAL ---');
      
      // 1. Borrar todos los movimientos primero (por la llave foránea)
      // Usamos un filtro que siempre sea verdadero para borrar todo
      await _supabase.from('movements').delete().neq('amount', -999999);
      
      // 2. Borrar todos los clientes
      await _supabase.from('customers').delete().neq('name', '___NONE___');
      
      debugPrint('Base de datos limpia. Iniciando carga...');

      // 3. Ejecutar la migración normal
      await migrateExcel(fileBytes);
      
    } catch (e) {
      debugPrint('Error en el reinicio: $e');
      rethrow;
    }
  }

  /// Procesa el archivo Excel y sincroniza con Supabase
  Future<void> migrateExcel(Uint8List fileBytes) async {
    var excel = Excel.decodeBytes(fileBytes);

    for (var table in excel.tables.keys) {
      String sheetName = table.toUpperCase();
      if (sheetName.contains('BUSCADOR') || 
          sheetName.contains('TOTAL') || 
          sheetName.contains('RESUMEN')) continue;

      var sheet = excel.tables[table]!;
      
      String? customerName;
      try {
        var cellValue = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value;
        customerName = cellValue?.toString().trim();
      } catch (e) {
        debugPrint('Error nombre en $table: $e');
      }

      if (customerName == null || customerName.isEmpty || customerName.toLowerCase() == 'nombre:') {
        customerName = table.trim();
      }

      try {
        final customerResult = await _supabase.from('customers').upsert({
          'name': customerName,
        }).select().single();

        String customerId = customerResult['id'];

        for (int i = 2; i < sheet.maxRows; i++) {
          // Procesar Deudas
          await _processRow(
            sheet: sheet,
            rowIdx: i,
            dateCol: 0,
            descCol: 2,
            amountCol: 3,
            customerId: customerId,
            type: 'DEBT',
            prefix: ''
          );

          // Procesar Abonos
          await _processRow(
            sheet: sheet,
            rowIdx: i,
            dateCol: 5,
            descCol: 6,
            amountCol: 7,
            customerId: customerId,
            type: 'CREDIT',
            prefix: 'Abono: '
          );
        }
        
        await _recalculateCustomerBalance(customerId);

      } catch (e) {
        debugPrint('Error en cliente $customerName: $e');
      }
    }
  }

  Future<void> _processRow({
    required Sheet sheet,
    required int rowIdx,
    required int dateCol,
    required int descCol,
    required int amountCol,
    required String customerId,
    required String type,
    required String prefix,
  }) async {
    try {
      var amountVal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: amountCol, rowIndex: rowIdx)).value;
      if (amountVal != null) {
        String rawAmount = amountVal.toString().replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        double? amount = double.tryParse(rawAmount);

        if (amount != null && amount > 0) {
          var dateVal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: dateCol, rowIndex: rowIdx)).value;
          var descVal = sheet.cell(CellIndex.indexByColumnRow(columnIndex: descCol, rowIndex: rowIdx)).value;
          
          await _supabase.from('movements').insert({
            'customer_id': customerId,
            'amount': amount,
            'type': type,
            'description': prefix + (descVal?.toString().trim() ?? (type == 'DEBT' ? 'Compra' : 'Abono')),
            'created_at': _parseDate(dateVal?.toString()),
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _recalculateCustomerBalance(String customerId) async {
    final res = await _supabase.from('movements').select('amount, type').eq('customer_id', customerId);
    double total = 0;
    for (var m in res) {
      double amt = (m['amount'] as num).toDouble();
      if (m['type'] == 'DEBT') total += amt;
      else total -= amt;
    }
    await _supabase.from('customers').update({'current_balance': total}).eq('id', customerId);
  }

  String _parseDate(String? input) {
    if (input == null || input.isEmpty || input.toLowerCase().contains('fecha')) {
      return DateTime.now().toIso8601String();
    }
    try {
      return DateTime.parse(input).toIso8601String();
    } catch (e) {
      return DateTime.now().toIso8601String();
    }
  }
}