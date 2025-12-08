import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportGenerator {
  /// Genera un Estado de Cuenta detallado con tablas separadas
  static Future<void> generateAccountStatement({
    required String customerName,
    required String customerId,
    required double currentBalance,
    required List<Map<String, dynamic>> movements,
  }) async {
    // 1. Cargar Logo
    pw.MemoryImage? profileImage;
    try {
      final byteData = await rootBundle.load('assets/logo.jpg');
      profileImage = pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      // Ignorar si no hay logo
    }

    // 2. Separar datos y calcular totales
    final sales = movements.where((m) => m['type'] == 'DEBT').toList();
    final payments = movements.where((m) => m['type'] == 'CREDIT').toList();

    double totalSales =
        sales.fold(0.0, (sum, m) => sum + (m['amount'] as num).toDouble());
    double totalPayments =
        payments.fold(0.0, (sum, m) => sum + (m['amount'] as num).toDouble());

    // Formato de fecha
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // 3. Configuración del PDF
    final pdf = pw.Document();

    // Estilos reutilizables
    final titleStyle =
        pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
    final subTitleStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800);
    final headerStyle = pw.TextStyle(
        fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10);
    final cellStyle = const pw.TextStyle(fontSize: 9);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            // --- ENCABEZADO ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("BBT TIENDA DE LICORES", style: titleStyle),
                    pw.Text("Estado de Cuenta",
                        style: const pw.TextStyle(
                            fontSize: 14, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text("Emisión: $dateStr",
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                      height: 50, width: 50, child: pw.Image(profileImage))
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // --- RESUMEN FINANCIERO (Cuadro Gris) ---
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                children: [
                  // Datos Cliente
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("CLIENTE:",
                            style: pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(customerName,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text("ID: $customerId",
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  // Totales
                  pw.Expanded(
                    flex: 3,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        _buildSummaryInfo(
                            "Total Compras", totalSales, PdfColors.black),
                        pw.SizedBox(width: 15),
                        _buildSummaryInfo(
                            "Total Pagado", totalPayments, PdfColors.green700),
                        pw.SizedBox(width: 15),
                        // El saldo se muestra grande
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("SALDO PENDIENTE",
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text("\$${currentBalance.toStringAsFixed(2)}",
                                style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: currentBalance > 0
                                        ? PdfColors.red700
                                        : PdfColors.green700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // --- TABLA 1: VENTAS / PEDIDOS ---
            pw.Text("DETALLE DE VENTAS Y PEDIDOS", style: subTitleStyle),
            pw.SizedBox(height: 5),
            if (sales.isEmpty)
              pw.Text("No hay registros de ventas.",
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
            else
              pw.Table.fromTextArray(
                headers: ['Fecha', 'Descripción de Productos', 'Monto'],
                headerStyle: headerStyle,
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: cellStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FixedColumnWidth(80),
                },
                data: sales.map((m) {
                  final date = DateTime.parse(m['created_at']).toLocal();
                  return [
                    DateFormat('dd/MM/yyyy').format(date),
                    m['description'] ?? '---',
                    "\$${(m['amount'] as num).toStringAsFixed(2)}",
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 20),

            // --- TABLA 2: ABONOS / PAGOS ---
            pw.Text("HISTORIAL DE ABONOS Y PAGOS", style: subTitleStyle),
            pw.SizedBox(height: 5),
            if (payments.isEmpty)
              pw.Text("No hay registros de pagos.",
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
            else
              pw.Table.fromTextArray(
                headers: ['Fecha', 'Detalle', 'Método', 'Monto'],
                headerStyle: headerStyle,
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: cellStyle,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(80),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FixedColumnWidth(80),
                },
                data: payments.map((m) {
                  final date = DateTime.parse(m['created_at']).toLocal();
                  return [
                    DateFormat('dd/MM/yyyy').format(date),
                    m['description'] ?? 'Abono',
                    m['payment_method'] ?? 'N/A',
                    "-\$${(m['amount'] as num).toStringAsFixed(2)}",
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey300),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Generado automáticamente por Sistema BBT Licores",
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ),
          ];
        },
      ),
    );

    // 4. Mostrar PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Estado_Cuenta_${customerName.replaceAll(" ", "_")}.pdf',
    );
  }

  // Widget auxiliar para los totales del resumen
  static pw.Widget _buildSummaryInfo(
      String label, double value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text("\$${value.toStringAsFixed(2)}",
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }
}
