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

  // Recarga el stream del cliente para obtener saldo fresco
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

  // --- 1. ABRIR EDITOR DE VENTA AVANZADO ---
  void _openSaleEditor(String saleId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ocupa pantalla completa si es necesario
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditSaleSheet(
          saleId: saleId,
          customerId: widget.customerId,
          onSave: _refreshCustomerData, // Al guardar, refrescamos el saldo
        ),
      ),
    );
  }

  // --- 2. ABRIR EDITOR DE ABONO ---
  void _openPaymentEditor(Map<String, dynamic> movement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditPaymentSheet(
          movement: movement,
          onSave: _refreshCustomerData,
        ),
      ),
    );
  }

  // --- 3. ELIMINAR MOVIMIENTO (Con Clave) ---
  Future<void> _deleteMovement(String movementId) async {
    final passwordCtrl = TextEditingController();

    bool? authorized = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("Eliminar Registro",
                  style: TextStyle(color: AppTheme.accentRed)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Esta acción es irreversible y ajustará el saldo. Ingrese Clave:",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "******",
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed),
                  onPressed: () => passwordCtrl.text == '102030'
                      ? Navigator.pop(ctx, true)
                      : null,
                  child: const Text("ELIMINAR"),
                )
              ],
            ));

    if (authorized == true) {
      try {
        await _supabase.from('movements').delete().eq('id', movementId);
        _refreshCustomerData(); // Actualizar saldo visual
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Registro eliminado correctamente")));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 4. ELIMINAR CLIENTE COMPLETO (Con Clave) ---
  Future<void> _deleteThisCustomer() async {
    final passwordCtrl = TextEditingController();

    bool? authorized = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("ELIMINAR CLIENTE",
                  style: TextStyle(
                      color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      "Se eliminará el cliente y TODO su historial. Ingrese Clave:",
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "******",
                        filled: true,
                        fillColor: Colors.black26),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed),
                  onPressed: () => passwordCtrl.text == '102030'
                      ? Navigator.pop(ctx, true)
                      : null,
                  child: const Text("CONFIRMAR"),
                )
              ],
            ));

    if (authorized == true) {
      try {
        await _supabase
            .from('movements')
            .delete()
            .eq('customer_id', widget.customerId);
        await _supabase.from('customers').delete().eq('id', widget.customerId);
        if (mounted) {
          Navigator.pop(context); // Volver a la lista
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Cliente eliminado")));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 5. REGISTRAR ABONO ---
  void _showPaymentDialog(BuildContext context, double currentBalance) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? selectedMethod;
    final paymentMethodsFuture =
        _supabase.from('payment_methods').select().order('name');
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    // Estado local del diálogo
    String bsEquivalent = "Bs. 0.00";
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text("Registrar Abono",
              style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Deuda actual: \$${currentBalance.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),

                  // Selector Fecha
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, ch) =>
                              Theme(data: AppTheme.darkTheme, child: ch!));
                      if (picked != null)
                        setDialogState(() => selectedDate = picked);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  "Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}",
                                  style: const TextStyle(color: Colors.white)),
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Colors.blue)
                            ])),
                  ),
                  const SizedBox(height: 15),

                  // Método de Pago
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: paymentMethodsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      final methods = snapshot.data!;
                      if (selectedMethod == null && methods.isNotEmpty)
                        selectedMethod = methods.first['name'];
                      return DropdownButtonFormField<String>(
                        value: selectedMethod,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Forma de Pago",
                            prefixIcon:
                                Icon(Icons.payment, color: Colors.grey)),
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

                  // Monto y Conversión
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        labelText: "Monto (\$)",
                        prefixIcon:
                            Icon(Icons.attach_money, color: Colors.green)),
                    onChanged: (val) {
                      setDialogState(() {
                        bsEquivalent = provider.toBs(double.tryParse(val) ?? 0);
                      });
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Equivalente: $bsEquivalent",
                              style: const TextStyle(
                                  color: AppTheme.accentGreen,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              "Tasa: Bs. ${provider.activeRate.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Nota Opcional
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: "Nota (Opcional)",
                        prefixIcon: Icon(Icons.note, color: Colors.grey)),
                  ),
                ],
              ),
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
                      'description':
                          'Abono ($selectedMethod)${noteCtrl.text.isNotEmpty ? ' - ${noteCtrl.text}' : ''}',
                      'payment_method': selectedMethod,
                      'created_at': selectedDate.toIso8601String()
                    });
                    _refreshCustomerData();
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

  // --- 6. EDITAR DATOS CLIENTE ---
  Future<void> _editCustomerData(Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final phoneCtrl = TextEditingController(text: currentData['phone']);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text("Editar Cliente",
                    style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Nombre")),
                    const SizedBox(height: 10),
                    TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: "Teléfono")),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () async {
                        await _supabase.from('customers').update({
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim()
                        }).eq('id', widget.customerId);
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Guardar"))
                ]));
  }

  // --- 7. EXPORTAR PDF ---
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("No hay datos")));
          return;
        }

        final customerNow = await _supabase
            .from('customers')
            .select('name')
            .eq('id', widget.customerId)
            .single();
        await ReportGenerator.generateAccountStatement(
          customerName: customerNow['name'] ?? widget.customerName,
          customerId: widget.customerId,
          currentBalance: currentBalance,
          movements: movements,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // --- 8. WHATSAPP ---
  void _launchWhatsApp(String? phone, double amount, AppStateProvider provider,
      String name) async {
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
Hola $name, le escribimos de BBT Licores.

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
    if (await canLaunchUrl(url)) await launchUrl(url);
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
              tooltip: "Exportar PDF",
              onPressed: () => _exportToPdf(widget.initialBalance)),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _customerStream,
        builder: (context, snapshot) {
          final customerData = snapshot.data;
          final currentBalance = (customerData != null)
              ? (customerData['current_balance'] as num).toDouble()
              : widget.initialBalance;
          final phone = customerData?['phone'] as String?;
          final displayName = customerData?['name'] ?? widget.customerName;

          return Column(
            children: [
              // HEADER
              Container(
                  padding: const EdgeInsets.all(24),
                  color: AppTheme.surface,
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(
                          radius: 35,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  fontSize: 32, color: Colors.white))),
                      const SizedBox(width: 20),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              Flexible(
                                  child: Text(displayName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis)),
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue, size: 20),
                                  onPressed: () =>
                                      _editCustomerData(customerData ?? {}))
                            ]),
                            Text("ID: ...${widget.customerId.substring(0, 6)}",
                                style: const TextStyle(color: Colors.grey)),
                            Row(children: [
                              const Icon(Icons.phone,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(phone ?? "Sin teléfono",
                                  style: const TextStyle(color: Colors.grey))
                            ])
                          ])),
                    ]),
                    const SizedBox(height: 20),
                    // KPI
                    Row(children: [
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10)),
                              child: Column(children: [
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
                              ]))),
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
                                phone, currentBalance, provider, displayName),
                            icon: const Icon(Icons.message, size: 18),
                            label: const Text("WhatsApp"),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                fixedSize: const Size(140, 45))),
                      ])
                    ]),
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
                                    AppTheme.accentRed.withOpacity(0.1)))),
                  ])),

              // Tabs
              Container(
                  color: AppTheme.surface,
                  child: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppTheme.primary,
                      tabs: const [Tab(text: "Pedidos"), Tab(text: "Abonos")])),

              // Lists
              Expanded(
                  child: TabBarView(controller: _tabController, children: [
                _buildMovementList('DEBT'),
                _buildMovementList('CREDIT'),
              ])),
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
              // SI ES DEUDA, ABRE EL EDITOR AVANZADO. SI ES ABONO, ABRE EL EDITOR DE ABONO.
              onTap: () {
                if (type == 'DEBT' && mov['sale_id'] != null) {
                  _openSaleEditor(mov['sale_id']);
                } else if (type == 'CREDIT') {
                  _openPaymentEditor(mov);
                }
              },
              title: Text(mov['description'] ?? 'Movimiento',
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  "$dateStr • ${type == 'DEBT' ? 'Ver detalle >' : 'Editar >'}",
                  style: TextStyle(
                      color: type == 'DEBT'
                          ? Colors.blueAccent
                          : Colors.greenAccent,
                      fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("\$${(mov['amount'] as num).toStringAsFixed(2)}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
}

// --- WIDGET EDITOR DE ABONO ---
class _EditPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> movement;
  final VoidCallback onSave;
  const _EditPaymentSheet({required this.movement, required this.onSave});
  @override
  State<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<_EditPaymentSheet> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _date;
  String? _method;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.movement['amount'].toString());
    _noteCtrl = TextEditingController(text: widget.movement['description']);
    _date = DateTime.parse(widget.movement['created_at']).toLocal();
    _method = widget.movement['payment_method'];
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('movements').update({
        'amount': double.parse(_amountCtrl.text),
        'description': _noteCtrl.text,
        'payment_method': _method,
        'created_at': _date.toIso8601String()
      }).eq('id', widget.movement['id']);

      if (mounted) {
        widget.onSave();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Abono actualizado"), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsFuture =
        _supabase.from('payment_methods').select().order('name');

    return Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Editar Abono",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, ch) =>
                              Theme(data: AppTheme.darkTheme, child: ch!));
                      if (p != null) setState(() => _date = p);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4)),
                        child: Row(children: [
                          Text(DateFormat('dd/MM/yyyy').format(_date),
                              style: const TextStyle(color: Colors.white)),
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue)
                        ])))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: "Monto",
                        prefixIcon: Icon(Icons.attach_money))))
          ]),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: paymentMethodsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final methods = snapshot.data!;
              return DropdownButtonFormField<String>(
                value: _method,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Método",
                    prefixIcon: Icon(Icons.payment, color: Colors.grey)),
                items: methods
                    .map((m) => DropdownMenuItem<String>(
                        value: m['name'], child: Text(m['name'])))
                    .toList(),
                onChanged: (val) => setState(() => _method = val),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Descripción")),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("GUARDAR CAMBIOS")))
        ]));
  }
}

// --- WIDGET EDITOR DE VENTA AVANZADO ---
class _EditSaleSheet extends StatefulWidget {
  final String saleId;
  final String customerId;
  final VoidCallback onSave;

  const _EditSaleSheet(
      {required this.saleId, required this.customerId, required this.onSave});

  @override
  State<_EditSaleSheet> createState() => _EditSaleSheetState();
}

class _EditSaleSheetState extends State<_EditSaleSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _noteCtrl = TextEditingController();
  DateTime _saleDate = DateTime.now();
  bool _isLoading = true;
  final TextEditingController _addItemPriceCtrl = TextEditingController();
  String _addItemName = "";

  @override
  void initState() {
    super.initState();
    _loadSaleDetails();
  }

  Future<void> _loadSaleDetails() async {
    try {
      final sale = await _supabase
          .from('sales')
          .select()
          .eq('id', widget.saleId)
          .single();
      final items = await _supabase
          .from('sale_items')
          .select()
          .eq('sale_id', widget.saleId);
      if (mounted) {
        setState(() {
          _noteCtrl.text = sale['note'] ?? '';
          _saleDate = DateTime.parse(sale['created_at']).toLocal();
          _items = List<Map<String, dynamic>>.from(items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _addNewItem() {
    if (_addItemName.isEmpty || _addItemPriceCtrl.text.isEmpty) return;
    setState(() {
      _items.add({
        'item_name': _addItemName,
        'unit_price': double.parse(_addItemPriceCtrl.text),
        'quantity': 1,
        'total': double.parse(_addItemPriceCtrl.text)
      });
      _addItemName = "";
      _addItemPriceCtrl.clear();
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  void _updateQty(int index, String val) {
    int? newQty = int.tryParse(val);
    if (newQty != null && newQty > 0) {
      setState(() {
        _items[index]['quantity'] = newQty;
        _items[index]['total'] = newQty * (_items[index]['unit_price'] as num);
      });
    }
  }

  void _updateQtyBtn(int index, int delta) {
    int newQty = (_items[index]['quantity'] as int) + delta;
    if (newQty < 1) return;
    setState(() {
      _items[index]['quantity'] = newQty;
      _items[index]['total'] = newQty * (_items[index]['unit_price'] as num);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    double newTotal =
        _items.fold(0, (sum, item) => sum + (item['total'] as num));
    String itemsSummary =
        _items.map((i) => "${i['quantity']}x ${i['item_name']}").join(", ");
    if (itemsSummary.length > 100)
      itemsSummary = "${itemsSummary.substring(0, 97)}...";

    try {
      // 1. Actualizar venta
      await _supabase.from('sales').update({
        'total_amount': newTotal,
        'note': _noteCtrl.text,
        'created_at': _saleDate.toIso8601String()
      }).eq('id', widget.saleId);

      // 2. Reemplazar items
      await _supabase.from('sale_items').delete().eq('sale_id', widget.saleId);
      final newItems = _items
          .map((i) => {
                'sale_id': widget.saleId,
                'item_name': i['item_name'],
                'unit_price': i['unit_price'],
                'quantity': i['quantity'],
                'total': i['total']
              })
          .toList();
      await _supabase.from('sale_items').insert(newItems);

      // 3. Actualizar deuda del cliente (Movement)
      await _supabase.from('movements').update({
        'amount': newTotal,
        'description': 'Venta Modificada: $itemsSummary',
        'created_at': _saleDate.toIso8601String()
      }).match({'sale_id': widget.saleId, 'customer_id': widget.customerId});

      if (mounted) {
        widget.onSave(); // Callback para refrescar padre
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Venta actualizada"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const SizedBox(
          height: 300, child: Center(child: CircularProgressIndicator()));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Editar Venta",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.grey))
          ]),
          const SizedBox(height: 20),

          // Fecha y Nota
          Row(children: [
            Expanded(
                child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                          context: context,
                          initialDate: _saleDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, ch) =>
                              Theme(data: AppTheme.darkTheme, child: ch!));
                      if (p != null) setState(() => _saleDate = p);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(_saleDate),
                              style: const TextStyle(color: Colors.white))
                        ])))),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: "Nota",
                        isDense: true,
                        border: OutlineInputBorder()))),
          ]),

          const SizedBox(height: 20),
          const Text("Productos", style: TextStyle(color: Colors.grey)),
          const Divider(color: Colors.white24),

          // Lista de Items
          Expanded(
              child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final qtyCtrl = TextEditingController(
                        text: item['quantity'].toString());
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['item_name'],
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text("\$${item['unit_price']}",
                          style: const TextStyle(color: Colors.green)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.remove,
                                  color: Colors.grey, size: 18),
                              onPressed: () => _updateQtyBtn(i, -1)),
                          SizedBox(
                              width: 40,
                              child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  onChanged: (val) => _updateQty(i, val))),
                          IconButton(
                              icon: const Icon(Icons.add,
                                  color: Colors.grey, size: 18),
                              onPressed: () => _updateQtyBtn(i, 1)),
                          const SizedBox(width: 10),
                          Text("\$${(item['total'] as num).toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(width: 5),
                          IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppTheme.accentRed, size: 20),
                              onPressed: () => _removeItem(i)),
                        ],
                      ),
                    );
                  })),

          // Agregar Item (Autocompletar)
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white.withOpacity(0.05),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text.isEmpty)
                        return const Iterable<Map<String, dynamic>>.empty();
                      final response = await Supabase.instance.client
                          .from('products')
                          .select('name, price')
                          .ilike('name', '%${textEditingValue.text}%')
                          .limit(5);
                      return List<Map<String, dynamic>>.from(response);
                    },
                    displayStringForOption: (option) => option['name'],
                    onSelected: (option) {
                      _addItemName = option['name'];
                      _addItemPriceCtrl.text = option['price'].toString();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "Agregar...",
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: Colors.grey)),
                        onChanged: (val) => _addItemName = val,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                              elevation: 4,
                              color: AppTheme.surface,
                              child: SizedBox(
                                  width: 300,
                                  child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                            title: Text(option['name'],
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            subtitle: Text(
                                                "\$${option['price']}",
                                                style: const TextStyle(
                                                    color:
                                                        AppTheme.accentGreen)),
                                            onTap: () => onSelected(option));
                                      }))));
                    },
                  ),
                ),
                SizedBox(
                    width: 70,
                    child: TextField(
                        controller: _addItemPriceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "\$", border: InputBorder.none))),
                IconButton(
                    onPressed: _addNewItem,
                    icon: const Icon(Icons.add_circle, color: Colors.blue))
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Total y Guardar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nuevo Total:",
                      style: TextStyle(color: Colors.grey)),
                  Text(
                      "\$${_items.fold(0.0, (sum, i) => sum + (i['total'] as num)).toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text("GUARDAR CAMBIOS"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16)),
              )
            ],
          )
        ],
      ),
    );
  }
}
