import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/client_pdf.dart';
import '../../core/utils/formatters.dart';

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

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient _supabase = Supabase.instance.client;
  late Stream<Map<String, dynamic>> _customerStream;

  double _totalPurchases = 0.0;
  double _totalPayments = 0.0;

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
          .stream(primaryKey: ['id']).map((list) => list.firstWhere((element) => element['id'] == widget.customerId, orElse: () => {}));
    });

    _supabase.from('movements').select('amount, type').eq('customer_id', widget.customerId).then((res) {
      double purchases = 0;
      double payments = 0;
      for (var m in res) {
        double amt = (m['amount'] as num).toDouble();
        if (m['type'] == 'DEBT') purchases += amt;
        if (m['type'] == 'CREDIT') payments += amt;
      }
      if (mounted) {
        setState(() {
          _totalPurchases = purchases;
          _totalPayments = payments;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HELPER LIQUID GLASS ---
  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: child,
        ),
      ),
    );
  }

  void _openSaleEditor(Map<String, dynamic> movement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, // Transparente para el Glass
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditSaleSheet(
          movement: movement, 
          customerId: widget.customerId,
          onSave: _refreshCustomerData,
        ),
      ),
    );
  }

  void _openPaymentEditor(Map<String, dynamic> movement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Transparente para el Glass
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditPaymentSheet(
          movement: movement,
          onSave: _refreshCustomerData,
        ),
      ),
    );
  }

  Future<void> _deleteMovement(String movementId) async {
    final passwordCtrl = TextEditingController();

    bool? authorized = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("Eliminar Registro", style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Esta acción ajustará el saldo. Ingrese Clave:", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "******", filled: true, fillColor: Colors.black26),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                  onPressed: () => passwordCtrl.text == '102030' ? Navigator.pop(ctx, true) : null,
                  child: const Text("ELIMINAR"),
                )
              ],
            ));

    if (authorized == true) {
      try {
        await _supabase.from('movements').delete().eq('id', movementId);
        _refreshCustomerData(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registro eliminado"), backgroundColor: AppTheme.accentGreen));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteThisCustomer() async {
    final passwordCtrl = TextEditingController();

    bool? authorized = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("ELIMINAR CLIENTE", style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Se eliminará todo su historial. Ingrese Clave:", style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "******", filled: true, fillColor: Colors.black26),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                  onPressed: () => passwordCtrl.text == '102030' ? Navigator.pop(ctx, true) : null,
                  child: const Text("CONFIRMAR"),
                )
              ],
            ));

    if (authorized == true) {
      try {
        await _supabase.from('movements').delete().eq('customer_id', widget.customerId);
        await _supabase.from('customers').delete().eq('id', widget.customerId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cliente eliminado"), backgroundColor: AppTheme.accentGreen));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showPaymentDialog(BuildContext context, double currentBalance) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? selectedMethod;
    final paymentMethodsFuture = _supabase.from('payment_methods').select().order('name');
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    String bsEquivalent = "Bs. 0.00";
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent, // Transparente para el Glass
          child: _glassContainer(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Registrar Abono", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Deuda pendiente: \$${currentBalance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                         const Text("TASA BCV", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                         Text("Bs. ${AppFormatters.money(provider.activeRate)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                         const Text("REFERENCIA BS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                         Text(bsEquivalent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Monto a Recibir (\$)", 
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        bsEquivalent = "Bs. ${AppFormatters.money((double.tryParse(val) ?? 0) * provider.activeRate)}";
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (c, ch) => Theme(data: AppTheme.darkTheme, child: ch!));
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(12), color: Colors.black12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text("Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}", style: const TextStyle(color: Colors.white70)),
                          const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.blueAccent)
                        ])),
                  ),
                  const SizedBox(height: 15),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: paymentMethodsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final methods = snapshot.data!;
                      if (selectedMethod == null && methods.isNotEmpty) selectedMethod = methods.first['name'];
                      return DropdownButtonFormField<String>(
                        value: selectedMethod,
                        dropdownColor: AppTheme.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Forma de Pago", 
                          labelStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                        ),
                        items: methods.map((m) => DropdownMenuItem<String>(value: m['name'], child: Text(m['name']))).toList(),
                        onChanged: (val) => setDialogState(() => selectedMethod = val),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: noteCtrl, 
                    style: const TextStyle(color: Colors.white), 
                    decoration: InputDecoration(
                      labelText: "Nota (Opcional)", 
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          final amount = double.tryParse(amountCtrl.text);
                          if (amount != null && amount > 0 && selectedMethod != null) {
                            try {
                              await _supabase.from('movements').insert({
                                'customer_id': widget.customerId,
                                'type': 'CREDIT',
                                'amount': amount,
                                'description': 'Abono ($selectedMethod)${noteCtrl.text.isNotEmpty ? ' - ${noteCtrl.text}' : ''}',
                                'payment_method': selectedMethod,
                                'created_at': selectedDate.toUtc().toIso8601String()
                              });
                              _refreshCustomerData();
                              if (mounted) Navigator.pop(ctx);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            }
                          }
                        },
                        child: const Text("CONFIRMAR PAGO", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editCustomerData(Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final phoneCtrl = TextEditingController(text: currentData['phone']);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text("Editar Cliente", style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nombre")),
                    const SizedBox(height: 10),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Teléfono")),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: () async {
                        await _supabase.from('customers').update({'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()}).eq('id', widget.customerId);
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Guardar"))
                ]));
  }

  Future<void> _exportToPdf(double currentBalance) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final response = await _supabase.from('movements').select().eq('customer_id', widget.customerId).order('created_at', ascending: false);
      final movements = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        Navigator.pop(context);
        if (movements.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos")));
          return;
        }

        final customerNow = await _supabase.from('customers').select('name').eq('id', widget.customerId).single();
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

  void _launchWhatsApp(String? phone, double amount, AppStateProvider provider, String name) async {
    if (phone == null || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teléfono inválido")));
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('58')) cleanPhone = '58$cleanPhone';

    final bsAmount = provider.toBs(amount);
    final rateStr = provider.activeRate.toStringAsFixed(2);
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final message = """Hola $name, le escribimos de *BBT TIENDA DE LICORES*.

Fecha: $dateStr
Tasa: $rateStr Bs/\$ 

Su saldo pendiente a la fecha es de: *$amount ($bsAmount BS)*.

Agradecemos su pago.

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

""";

    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
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
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), tooltip: "Exportar PDF", onPressed: () => _exportToPdf(widget.initialBalance)),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _customerStream,
        builder: (context, snapshot) {
          final customerData = snapshot.data;
          final currentBalance = (customerData != null) ? (customerData['current_balance'] as num).toDouble() : widget.initialBalance;
          final phone = customerData?['phone'] as String?;
          final displayName = customerData?['name'] ?? widget.customerName;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _glassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 30, backgroundColor: AppTheme.primary, child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "?", style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editCustomerData(customerData ?? {})),
                                  ]
                                ),
                                Row(children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.white54),
                                  const SizedBox(width: 6),
                                  Text(phone ?? "Sin teléfono", style: const TextStyle(color: Colors.white54, fontSize: 12))
                                ])
                              ]
                            )
                          ),
                        ]
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMiniStat("TOTAL COMPRAS", _totalPurchases, Colors.white),
                          _buildMiniStat("TOTAL ABONOS", _totalPayments, Colors.white70),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("DEUDA TOTAL", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                              Text("\$ ${AppFormatters.money(currentBalance)}", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: currentBalance > 0 ? AppTheme.accentRed : AppTheme.accentGreen)),
                              Text("Bs. ${provider.toBs(currentBalance)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ]
                  )
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: ElevatedButton.icon(onPressed: () => _showPaymentDialog(context, currentBalance), icon: const Icon(Icons.add_card_rounded), label: const Text("REGISTRAR ABONO"), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(onPressed: () => _launchWhatsApp(phone, currentBalance, provider, displayName), icon: const Icon(Icons.chat_bubble_rounded), label: const Text("ENVIAR SALDO"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _deleteThisCustomer,
                    icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRed, size: 20),
                    label: const Text("ELIMINAR CLIENTE DEL SISTEMA", style: TextStyle(color: AppTheme.accentRed, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.accentRed.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.accentRed.withOpacity(0.2))),
                    )
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  indicator: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [Tab(text: "Pedidos Realizados"), Tab(text: "Historial de Abonos")]
                )
              ),
              const SizedBox(height: 10),

              Expanded(
                child: TabBarView(
                  controller: _tabController, 
                  children: [
                    _buildMovementList('DEBT'),
                    _buildMovementList('CREDIT'),
                  ]
                )
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("\$${AppFormatters.money(amount)}", style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMovementList(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('movements').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) => data.where((mov) => mov['customer_id'] == widget.customerId && mov['type'] == type).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final movements = snapshot.data!;
        if (movements.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(type == 'DEBT' ? Icons.shopping_basket_outlined : Icons.account_balance_wallet_outlined, size: 40, color: Colors.white10), const SizedBox(height: 10), const Text("Sin registros.", style: TextStyle(color: Colors.white38))]));
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: movements.length,
          itemBuilder: (context, index) {
            final mov = movements[index];
            final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(mov['created_at']).toLocal());
            return Card(
              color: Colors.transparent, // Transparente para usar el Glass Container
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: _glassContainer(
                padding: const EdgeInsets.all(4),
                borderRadius: 16,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  onTap: () {
                    if (type == 'DEBT') {
                      _openSaleEditor(mov);
                    } else if (type == 'CREDIT') {
                      _openPaymentEditor(mov);
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: type == 'DEBT' ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    child: Icon(type == 'DEBT' ? Icons.shopping_bag_rounded : Icons.check_circle_rounded, color: type == 'DEBT' ? Colors.orange : Colors.green, size: 20),
                  ),
                  title: Text(type == 'DEBT' ? 'Venta de Productos' : 'Abono Recibido', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mov['description'] ?? 'Movimiento', style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(dateStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${type == 'DEBT' ? '+' : '-'} \$${AppFormatters.money(mov['amount'])}", style: TextStyle(color: type == 'DEBT' ? Colors.white : AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20), onPressed: () => _deleteMovement(mov['id'].toString()))
                    ]
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

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
    _amountCtrl = TextEditingController(text: widget.movement['amount'].toString());
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
        'created_at': _date.toUtc().toIso8601String()
      }).eq('id', widget.movement['id']);

      if (mounted) {
        widget.onSave();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abono actualizado"), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsFuture = _supabase.from('payment_methods').select().order('name');

    return _glassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Editar Abono", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: InkWell(
                    onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (c, ch) => Theme(data: AppTheme.darkTheme, child: ch!));
                      if (p != null) setState(() => _date = p);
                    },
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(16), color: Colors.black26),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(DateFormat('dd/MM/yyyy').format(_date), style: const TextStyle(color: Colors.white)),
                          const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.blueAccent)
                        ])))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: "Monto (\$)", 
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )))
          ]),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: paymentMethodsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final methods = snapshot.data!;
              return DropdownButtonFormField<String>(
                value: _method,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Método", 
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                ),
                items: methods.map((m) => DropdownMenuItem<String>(value: m['name'], child: Text(m['name']))).toList(),
                onChanged: (val) => setState(() => _method = val),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl, 
            style: const TextStyle(color: Colors.white), 
            decoration: InputDecoration(
              labelText: "Descripción", 
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.edit_note),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
            )
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GUARDAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))
            ],
          )
        ]));
  }
}

class _SaleItemRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int) onQtyChanged;
  final VoidCallback onRemove;

  const _SaleItemRow({required this.item, required this.onQtyChanged, required this.onRemove});

  @override
  State<_SaleItemRow> createState() => _SaleItemRowState();
}

class _SaleItemRowState extends State<_SaleItemRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item['quantity'].toString());
  }

  @override
  void didUpdateWidget(covariant _SaleItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item['quantity'].toString() != _qtyCtrl.text) {
      _qtyCtrl.text = widget.item['quantity'].toString();
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _modifyQty(int delta) {
    int current = int.tryParse(_qtyCtrl.text) ?? 1;
    int newValue = current + delta;
    if (newValue > 0) {
      widget.onQtyChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item['item_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text("\$${widget.item['unit_price']} c/u", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.remove, color: Colors.white54, size: 18), onPressed: () => _modifyQty(-1), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
                SizedBox(
                  width: 30,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    onChanged: (val) {
                      int? parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) widget.onQtyChanged(parsed);
                    },
                  )
                ),
                IconButton(icon: const Icon(Icons.add, color: Colors.white54, size: 18), onPressed: () => _modifyQty(1), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${(widget.item['total'] as num).toStringAsFixed(2)}", style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              InkWell(
                onTap: widget.onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.delete_sweep_rounded, color: AppTheme.accentRed, size: 22),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _EditSaleSheet extends StatefulWidget {
  final Map<String, dynamic> movement;
  final String customerId;
  final VoidCallback onSave;

  const _EditSaleSheet({required this.movement, required this.customerId, required this.onSave});

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
  
  int? _correlativeId; 
  String? _saleId;
  double _oldGlobalTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _saleId = widget.movement['sale_id']?.toString();
    _loadSaleDetails();
  }

  // --- PARSER DE EXCEL OPTIMIZADO ---
  List<Map<String, dynamic>> _extractItemsFromText(String desc) {
    List<Map<String, dynamic>> items = [];
    try {
      // Limpiamos la descripción de prefijos como "POS: " o "Excel: "
      String cleanDesc = desc.replaceAll("POS:", "").replaceAll("Excel:", "").trim();

      // Separamos por comas o saltos de línea para evaluar cada producto individualmente
      List<String> parts = cleanDesc.split(RegExp(r'[,\n]'));

      for (String part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;

        // Intentamos el patrón: [CANTIDAD] [x opcional] [NOMBRE] [PRECIO con o sin $]
        final regex = RegExp(r'^(\d+)\s*x?\s+(.+?)\s*\(?\$?\s*([\d,.]+)\s*\$?\)?$');
        final match = regex.firstMatch(part);

        if (match != null) {
          int qty = int.tryParse(match.group(1)!) ?? 1;
          String name = match.group(2)!.trim();
          double t = double.parse(match.group(3)!.replaceAll(',', ''));

          items.add({
            'item_name': name,
            'quantity': qty,
            'unit_price': t / (qty > 0 ? qty : 1),
            'total': t
          });
        } else {
          // Fallback: Si no tiene cantidad, solo Nombre y Monto al final (ej: "parte sergio 10$")
          final fallbackRegex = RegExp(r'^(.+?)\s*\(?\$?\s*([\d,.]+)\s*\$?\)?$');
          final fbMatch = fallbackRegex.firstMatch(part);
          if (fbMatch != null) {
            String name = fbMatch.group(1)!.trim();
            double t = double.parse(fbMatch.group(2)!.replaceAll(',', ''));
            items.add({'item_name': name, 'quantity': 1, 'unit_price': t, 'total': t});
          } else {
             // Si el formato es desconocido, lo registra para edición con monto 0
             items.add({'item_name': part, 'quantity': 1, 'unit_price': 0.0, 'total': 0.0});
          }
        }
      }
    } catch (e) {
      debugPrint("Error parseando items de Excel: $e");
    }
    
    // SISTEMA ANTIFALLOS: Si no logró encontrar nada válido, mantiene el monto de la deuda para no perder el dinero
    double sumParsed = items.fold(0.0, (s, i) => s + (i['total'] as num));
    if (items.isEmpty || sumParsed == 0.0) {
       items = [{
         'item_name': desc.isNotEmpty ? desc : 'Venta Importada', 
         'quantity': 1, 
         'unit_price': _oldGlobalTotal, 
         'total': _oldGlobalTotal
       }];
    }
    return items;
  }

  Future<void> _loadSaleDetails() async {
    try {
      if (_saleId != null) {
        final sale = await _supabase.from('sales').select().eq('id', _saleId!).single();
        final items = await _supabase.from('sale_items').select().eq('sale_id', _saleId!);
        _noteCtrl.text = sale['note'] ?? '';
        _oldGlobalTotal = (sale['total_amount'] as num).toDouble();
        _items = List<Map<String, dynamic>>.from(items);
        _correlativeId = sale['correlative_id']; 
      } else {
        _noteCtrl.text = "Importado de Excel";
        _oldGlobalTotal = (widget.movement['amount'] as num).toDouble();
        _items = _extractItemsFromText(widget.movement['description'] ?? "");
      }
      
      if (mounted) {
        setState(() {
          _saleDate = DateTime.parse(widget.movement['created_at']).toLocal();
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

  void _updateQty(int index, int newQty) {
    setState(() {
      _items[index]['quantity'] = newQty;
      _items[index]['total'] = newQty * (_items[index]['unit_price'] as num);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    double newTotal = _items.fold(0, (sum, item) => sum + (item['total'] as num));
    
    double difference = newTotal - _oldGlobalTotal;

    String itemsSummary = _items.map((i) => "${i['quantity']}x ${i['item_name']}").join(", ");
    if (itemsSummary.length > 100) itemsSummary = "${itemsSummary.substring(0, 97)}...";

    String prefix = _correlativeId != null ? 'Venta #$_correlativeId' : 'Venta';
    String finalDescription = '$prefix: $itemsSummary';

    try {
      if (_saleId != null) {
        await _supabase.from('sales').update({'total_amount': newTotal, 'note': _noteCtrl.text, 'created_at': _saleDate.toUtc().toIso8601String()}).eq('id', _saleId!);
        await _supabase.from('sale_items').delete().eq('sale_id', _saleId!);
        final newItems = _items.map((i) => {'sale_id': _saleId, 'item_name': i['item_name'], 'unit_price': i['unit_price'], 'quantity': i['quantity'], 'total': i['total']}).toList();
        await _supabase.from('sale_items').insert(newItems);
        await _supabase.from('movements').update({'description': finalDescription}).eq('sale_id', _saleId!);
        
        double currentMovAmount = (widget.movement['amount'] as num).toDouble();
        double newMovAmount = currentMovAmount + difference;
        if (newMovAmount < 0) newMovAmount = 0; 
        
        await _supabase.from('movements').update({'amount': newMovAmount, 'created_at': _saleDate.toUtc().toIso8601String()}).eq('id', widget.movement['id']);

      } else {
        final newSale = await _supabase.from('sales').insert({
          'total_amount': newTotal,
          'note': _noteCtrl.text,
          'created_at': _saleDate.toUtc().toIso8601String()
        }).select().single();
        
        final newSaleId = newSale['id'];

        final newItems = _items.map((i) => {
          'sale_id': newSaleId, 
          'item_name': i['item_name'], 
          'unit_price': i['unit_price'], 
          'quantity': i['quantity'], 
          'total': i['total']
        }).toList();
        await _supabase.from('sale_items').insert(newItems);

        await _supabase.from('movements').update({
          'amount': newTotal, 
          'description': finalDescription, 
          'sale_id': newSaleId, 
          'created_at': _saleDate.toUtc().toIso8601String()
        }).eq('id', widget.movement['id']);
      }

      if (mounted) {
        widget.onSave(); 
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido actualizado y estructurado en la BD"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));

    return _glassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 30, 
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_saleId == null ? "Modificar Pedido (Excel)" : "Modificar Pedido", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 28))
            ]),
            
            if (_saleId == null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent)),
                child: const Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(child: Text("Este pedido viene de Excel. Al guardar, se convertirá automáticamente en un Pedido Real en la base de datos.", style: TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // AGREGAR NUEVO PRODUCTO
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (textEditingValue) async {
                        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        final response = await Supabase.instance.client.from('products').select('name, price').ilike('name', '%${textEditingValue.text}%').limit(5);
                        return List<Map<String, dynamic>>.from(response);
                      },
                      displayStringForOption: (option) => option['name'],
                      onSelected: (option) {
                        _addItemName = option['name'];
                        _addItemPriceCtrl.text = option['price'].toString();
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller, focusNode: focusNode, style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(hintText: "Buscar producto extra...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, icon: Icon(Icons.add_shopping_cart, color: Colors.white54)),
                          onChanged: (val) => _addItemName = val,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                            alignment: Alignment.topLeft,
                            child: Material(elevation: 8, color: Colors.transparent, 
                                child: _glassContainer(
                                  padding: EdgeInsets.zero,
                                  borderRadius: 16,
                                  child: SizedBox(width: 300, child: ListView.builder(shrinkWrap: true, padding: EdgeInsets.zero, itemCount: options.length, itemBuilder: (context, index) {
                                            final option = options.elementAt(index);
                                            return ListTile(title: Text(option['name'], style: const TextStyle(color: Colors.white)), subtitle: Text("\$${option['price']}", style: const TextStyle(color: AppTheme.accentGreen)), onTap: () => onSelected(option));
                                          }))
                                )));
                      },
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  
                  Expanded(
                    flex: 2, 
                    child: TextField(
                      controller: _addItemPriceCtrl, 
                      keyboardType: TextInputType.number, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), 
                      decoration: const InputDecoration(hintText: "Monto \$", hintStyle: TextStyle(color: Colors.white24, fontSize: 12), border: InputBorder.none)
                    )
                  ),
                  IconButton.filled(onPressed: _addNewItem, icon: const Icon(Icons.add, color: Colors.white), style: IconButton.styleFrom(backgroundColor: AppTheme.primary))
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text("CARRITO ACTUAL", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Divider(color: Colors.white24),

            // LISTA DE ITEMS
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  return _SaleItemRow(
                    item: _items[i],
                    onQtyChanged: (newQty) => _updateQty(i, newQty),
                    onRemove: () => _removeItem(i),
                  );
                }
              )
            ),

            // AVISO DE INTEGRIDAD
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text("Nota: Si esta venta fue dividida con otros, cualquier diferencia de dinero se sumará o restará únicamente a la deuda de este cliente para proteger las cuentas de los demás.", style: TextStyle(color: Colors.orange, fontSize: 10))),
                ]
              )
            ),
            const SizedBox(height: 15),

            // Total y Guardar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.primary.withOpacity(0.5))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("NUEVO TOTAL VENTA", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("\$${_items.fold(0.0, (sum, i) => sum + (i['total'] as num)).toStringAsFixed(2)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.accentGreen)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                    label: Text(_saleId == null ? "CONVERTIR Y GUARDAR" : "ACTUALIZAR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}