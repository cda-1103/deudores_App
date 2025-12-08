import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/client_pdf.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double initialBalance;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.initialBalance,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient _supabase = Supabase.instance.client;
  late Stream<Map<String, dynamic>> _customerStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshCustomerData();
  }

  void _refreshCustomerData() {
    setState(() {
      _customerStream = _supabase
          .from('customers')
          .stream(primaryKey: ['id']).map((list) => list.firstWhere(
              (element) => element['id'] == widget.customerId,
              orElse: () => {}));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- GENERAR REPORTE PDF ---
  Future<void> _exportToPdf(double currentBalance) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await _supabase
          .from('movements')
          .select()
          .eq('customer_id', widget.customerId)
          .order('created_at', ascending: false);

      final movements = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        Navigator.pop(context);

        if (movements.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("No hay datos para generar el reporte")));
          return;
        }

        await ReportGenerator.generateAccountStatement(
          customerName: widget.customerName,
          customerId: widget.customerId,
          currentBalance: currentBalance,
          movements: movements,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error PDF: $e")));
      }
    }
  }

  // --- BORRAR CLIENTE ---
  Future<void> _deleteThisCustomer() async {
    final passwordCtrl = TextEditingController();
    bool? authorized = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("ELIMINAR CLIENTE",
                  style: TextStyle(color: AppTheme.accentRed)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("Se eliminará todo.",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: "Contraseña",
                        filled: true,
                        fillColor: Colors.black26),
                    style: const TextStyle(color: Colors.white))
              ]),
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed),
                    onPressed: () => passwordCtrl.text == '102030'
                        ? Navigator.pop(ctx, true)
                        : null,
                    child: const Text("CONFIRMAR"))
              ],
            ));
    if (authorized == true) {
      await _supabase
          .from('movements')
          .delete()
          .eq('customer_id', widget.customerId);
      await _supabase.from('customers').delete().eq('id', widget.customerId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _deleteMovement(String id) async {
    await _supabase.from('movements').delete().eq('id', id);
    _refreshCustomerData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Perfil del Cliente"),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: "Exportar Historial PDF",
            onPressed: () => _exportToPdf(widget.initialBalance),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _customerStream,
        builder: (context, snapshot) {
          final customerData = snapshot.data;
          final currentBalance =
              (customerData != null && customerData.isNotEmpty)
                  ? (customerData['current_balance'] as num).toDouble()
                  : widget.initialBalance;
          final phone = customerData?['phone'] as String?;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                color: AppTheme.surface,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                            radius: 35,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                                widget.customerName.isNotEmpty
                                    ? widget.customerName[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                    fontSize: 32, color: Colors.white))),
                        const SizedBox(width: 20),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(widget.customerName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  "ID: ...${widget.customerId.substring(0, 6)}",
                                  style: const TextStyle(color: Colors.grey))
                            ])),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Saldo Actual",
                                      style: TextStyle(color: Colors.grey)),
                                  Text("\$${currentBalance.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: currentBalance > 0
                                              ? AppTheme.accentRed
                                              : AppTheme.accentGreen)),
                                  Text(provider.toBs(currentBalance),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12))
                                ]),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(children: [
                          ElevatedButton.icon(
                              onPressed: () =>
                                  _showPaymentDialog(context, currentBalance),
                              icon: const Icon(Icons.attach_money),
                              label: const Text("Abonar"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size(140, 45))),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                              onPressed: () => _launchWhatsApp(
                                  phone, currentBalance, provider),
                              icon: const Icon(Icons.message, size: 18),
                              label: const Text("WhatsApp"),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  fixedSize: const Size(140, 45))),
                        ])
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                            onPressed: _deleteThisCustomer,
                            icon: const Icon(Icons.delete_forever,
                                color: AppTheme.accentRed),
                            label: const Text("Eliminar Cliente y Datos",
                                style: TextStyle(color: AppTheme.accentRed)),
                            style: TextButton.styleFrom(
                                backgroundColor:
                                    AppTheme.accentRed.withOpacity(0.1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12)))),
                    Builder(builder: (c) {
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
              Expanded(
                child: Column(children: [
                  Container(
                      color: AppTheme.surface,
                      child: TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: AppTheme.primary,
                          tabs: const [
                            Tab(text: "Pedidos"),
                            Tab(text: "Abonos")
                          ])),
                  Expanded(
                      child: TabBarView(controller: _tabController, children: [
                    _buildMovementList('DEBT'),
                    _buildMovementList('CREDIT')
                  ])),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMovementList(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('movements')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data
              .where((mov) =>
                  mov['customer_id'] == widget.customerId &&
                  mov['type'] == type)
              .toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final movements = snapshot.data!;
        if (movements.isEmpty)
          return const Center(
              child:
                  Text("Sin registros.", style: TextStyle(color: Colors.grey)));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
          itemBuilder: (context, index) {
            final mov = movements[index];
            final dateStr = DateFormat('dd/MM/yyyy')
                .format(DateTime.parse(mov['created_at']).toLocal());
            return ListTile(
              // Click para ver detalle
              onTap: (type == 'DEBT' && mov['sale_id'] != null)
                  ? () => _showSaleDetail(mov['sale_id'], dateStr)
                  : null,
              title: Text(mov['description'] ?? 'Movimiento',
                  style: const TextStyle(color: Colors.white)),
              subtitle:
                  Text(dateStr, style: const TextStyle(color: Colors.grey)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("\$${mov['amount']}",
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 10),
                IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _deleteMovement(mov['id'].toString()))
              ]),
            );
          },
        );
      },
    );
  }

  // --- MOSTRAR DETALLE DE VENTA RESTAURADO ---
  void _showSaleDetail(String saleId, String dateStr) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final items =
          await _supabase.from('sale_items').select().eq('sale_id', saleId);

      if (mounted) {
        Navigator.pop(context);

        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Detalle de Compra",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.grey))
                  ],
                ),
                Text(dateStr, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text("${item['quantity']}x ",
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                                child: Text(item['item_name'],
                                    style:
                                        const TextStyle(color: Colors.white))),
                            Text("\$${item['total']}",
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error cargando detalles: $e")));
      }
    }
  }

  // --- REGISTRAR ABONO (FUNCIONANDO AL 100%) ---
  void _showPaymentDialog(BuildContext context, double currentBalance) {
    final amountCtrl = TextEditingController();
    String? selectedMethod;
    // Buscamos los métodos en BD
    final paymentMethodsFuture =
        _supabase.from('payment_methods').select().order('name');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text("Registrar Abono",
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Deuda actual: \$${currentBalance.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),

                // Selector de Forma de Pago
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: paymentMethodsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(
                          child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)));
                    final methods = snapshot.data!;

                    if (selectedMethod == null && methods.isNotEmpty) {
                      selectedMethod = methods.first['name'];
                    }

                    return DropdownButtonFormField<String>(
                      value: selectedMethod,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: "Forma de Pago",
                          prefixIcon: Icon(Icons.payment, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black26),
                      items: methods
                          .map((m) => DropdownMenuItem<String>(
                              value: m['name'], child: Text(m['name'])))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedMethod = val),
                    );
                  },
                ),

                const SizedBox(height: 15),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Monto a abonar (\$)",
                      prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                      filled: true,
                      fillColor: Colors.black26),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount != null && amount > 0 && selectedMethod != null) {
                  try {
                    await _supabase.from('movements').insert({
                      'customer_id': widget.customerId,
                      'type': 'CREDIT',
                      'amount': amount,
                      'description': 'Abono ($selectedMethod)',
                      'payment_method': selectedMethod,
                    });

                    _refreshCustomerData(); // Refrescar UI
                    if (mounted) Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
              child: const Text("Confirmar"),
            )
          ],
        ),
      ),
    );
  }

  void _launchWhatsApp(
      String? phone, double amount, AppStateProvider provider) async {
    if (phone == null || phone.length < 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Teléfono inválido")));
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('58')) cleanPhone = '58$cleanPhone';

    final bsAmount = provider.toBs(amount);
    final rateStr = provider.activeRate.toStringAsFixed(2);
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final message = """
Hola ${widget.customerName}, le escribimos de BBT Licores.

Fecha: $dateStr
Tasa: $rateStr Bs/\$

Su saldo pendiente es de: \$$amount ($bsAmount).

*Formas de Pago*

*Transferencia:*
0108-0372-13-0100303675
Provincial

*Pago Móvil*
28205583
Provincial
04247476273

*Zelle*
bbtiendadelicores@gmail.com

Agradecemos su pago.""";

    final url = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se pudo abrir WhatsApp")));
    }
  }
}
