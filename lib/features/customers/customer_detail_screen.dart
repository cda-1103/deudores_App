import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/themes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/client_pdf.dart'; 
import '../../providers/app_state_provider.dart';

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

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _filter = 'ALL';
  // Eliminado _isSyncing ya que no se usaba efectivamente en la UI
  Map<String, dynamic>? _customerData;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final res = await _supabase.from('customers').select().eq('id', widget.customerId).single();
    if (mounted) setState(() => _customerData = res);
  }

  Future<void> _refreshBalance() async {
    // Eliminada la referencia a _isSyncing
    try {
      final res = await _supabase.from('movements').select('amount, type').eq('customer_id', widget.customerId);
      double newBalance = 0;
      for (var m in res) {
        double amt = (m['amount'] as num).toDouble();
        if (m['type'] == 'DEBT') newBalance += amt;
        else newBalance -= amt;
      }
      await _supabase.from('customers').update({'current_balance': newBalance}).eq('id', widget.customerId);
      await _loadCustomerData();
    } catch (e) {
      debugPrint("Error sincronización: $e");
    }
  }

  // --- WHATSAPP ---
  void _sendWhatsApp(double amount, AppStateProvider provider) async {
    final phone = _customerData?['phone'] as String?;
    if (phone == null || phone.length < 10) {
      _showMsg("Teléfono inválido o no registrado", Colors.orange);
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) cleanPhone = cleanPhone.substring(1);
    if (!cleanPhone.startsWith('58')) cleanPhone = '58$cleanPhone';

    final bsAmount = provider.toBs(amount);
    final rateStr = AppFormatters.money(provider.activeRate);
    final message = """
Hola *${widget.customerName}*, le escribimos de *BBT Licores* 🍷

Saldo Pendiente: *\$${AppFormatters.money(amount)}*
Equivalente: *Bs. $bsAmount*
Tasa: $rateStr Bs/\$

Gracias por su preferencia.""";

    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // --- GESTIÓN DE ABONOS ---
  void _showAbonoDialog(AppStateProvider provider, {Map<String, dynamic>? existingMov}) async {
    final amtCtrl = TextEditingController(text: existingMov?['amount']?.toString());
    final noteCtrl = TextEditingController(text: existingMov?['description']?.toString().split(") ").last);
    String? selectedMethod = existingMov?['payment_method'];
    DateTime selectedDate = existingMov != null ? DateTime.parse(existingMov['created_at']).toLocal() : DateTime.now();
    double currentBs = (existingMov?['amount'] ?? 0.0) * provider.activeRate;
    
    final methodsRes = await _supabase.from('payment_methods').select().order('name');
    final List<Map<String, dynamic>> methods = List<Map<String, dynamic>>.from(methodsRes);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 32, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(existingMov == null ? "Registrar Abono" : "Editar Abono", 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              
              // INDICADOR DE TASA Y BS GRANDE
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text("TASA BCV:", style: TextStyle(color: Colors.white70)),
                         Text("Bs. ${AppFormatters.money(provider.activeRate)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                    const Text("EQUIVALENTE EN BOLÍVARES", style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(AppFormatters.money(currentBs), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const Text("Bs", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: amtCtrl, 
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                onChanged: (v) {
                  final val = AppFormatters.stringToDouble(v);
                  setModalState(() => currentBs = val * provider.activeRate);
                },
                decoration: const InputDecoration(
                  labelText: "Monto en Dólares (\$)",
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.attach_money, color: Colors.white),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(labelText: "Forma de Pago", labelStyle: TextStyle(color: Colors.white70)),
                items: methods.map((m) => DropdownMenuItem(value: m['name'] as String, child: Text(m['name'] as String, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setModalState(() => selectedMethod = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl, 
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nota / Referencia", labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final amt = AppFormatters.stringToDouble(amtCtrl.text);
                    if (amt <= 0 || selectedMethod == null) {
                      _showMsg("Verifique monto y método", Colors.orange);
                      return;
                    }
                    // ELIMINADO exchange_rate DEL MAPA
                    final data = {
                      'customer_id': widget.customerId, 'amount': amt, 'type': 'CREDIT',
                      'payment_method': selectedMethod, 'description': "Abono ($selectedMethod) ${noteCtrl.text.trim()}",
                      'created_at': selectedDate.toUtc().toIso8601String(),
                    };
                    
                    try {
                      if (existingMov == null) await _supabase.from('movements').insert(data);
                      else await _supabase.from('movements').update(data).eq('id', existingMov['id']);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _refreshBalance();
                        _showMsg("Abono guardado", Colors.green);
                      }
                    } catch (e) {
                      _showMsg("Error: $e", Colors.red);
                    }
                  },
                  child: const Text("GUARDAR ABONO"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- VISUALIZADOR DE TICKET (MODO LECTURA) ---
  void _showTicketView(Map<String, dynamic> mov) {
    List<Map<String, dynamic>> items = _parseDescription(mov['description'] ?? "");
    double total = (mov['amount'] as num).toDouble();
    DateTime date = DateTime.parse(mov['created_at']).toLocal();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("Detalle de Compra", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                 IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx))
               ],
             ),
             const Divider(color: Colors.white24),
             
             // INFO CABECERA
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}", style: const TextStyle(color: Colors.white70)),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                   child: const Text("Crédito", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                 )
               ],
             ),
             const SizedBox(height: 20),

             // TABLA DE PRODUCTOS (VISUAL)
             Container(
               decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
               padding: const EdgeInsets.all(12),
               child: Column(
                 children: [
                   Row(children: const [
                     Expanded(flex: 3, child: Text("PRODUCTO", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                     Expanded(flex: 1, child: Text("CANT", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                     Expanded(flex: 2, child: Text("PRECIO", textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                     Expanded(flex: 2, child: Text("TOTAL", textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                   ]),
                   const Divider(color: Colors.white10),
                   if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(mov['description'] ?? "Sin detalle", style: const TextStyle(color: Colors.white)),
                      )
                   else
                     ...items.map((item) => Padding(
                       padding: const EdgeInsets.symmetric(vertical: 6),
                       child: Row(
                         children: [
                           Expanded(flex: 3, child: Text(item['name'], style: const TextStyle(color: Colors.white, fontSize: 13))),
                           Expanded(flex: 1, child: Text(item['qty'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13))),
                           Expanded(flex: 2, child: Text(AppFormatters.money(item['price']), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13))),
                           Expanded(flex: 2, child: Text(AppFormatters.money(item['qty'] * item['price']), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                         ],
                       ),
                     )).toList(),
                 ],
               ),
             ),

             const Spacer(),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("TOTAL OPERACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 Text("\$ ${AppFormatters.money(total)}", style: const TextStyle(color: AppTheme.accentGreen, fontSize: 24, fontWeight: FontWeight.bold)),
               ],
             ),
             const SizedBox(height: 20),
             
             // BOTÓN EDITAR (LÁPIZ)
             SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                 onPressed: () {
                   Navigator.pop(ctx);
                   _editDebtAsCart(mov, items); // PASAR AL EDITOR
                 },
                 icon: const Icon(Icons.edit, size: 18),
                 label: const Text("EDITAR / CORREGIR PEDIDO"),
                 style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   foregroundColor: Colors.white,
                   side: const BorderSide(color: Colors.white24),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  // --- EDITOR DE CARRITO (MODIFICABLE) ---
  void _editDebtAsCart(Map<String, dynamic> mov, List<Map<String, dynamic>> initialItems) {
    List<Map<String, dynamic>> tempCart = List.from(initialItems);
    // Si estaba vacía (item genérico), la inicializamos
    if (tempCart.isEmpty && (mov['description'] != null)) {
       tempCart.add({'name': mov['description'], 'qty': 1, 'price': (mov['amount'] as num).toDouble()});
    }

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: "1");
    DateTime editDate = DateTime.parse(mov['created_at']).toLocal();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double totalTemp = tempCart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

          return Container(
             height: MediaQuery.of(context).size.height * 0.9,
             padding: const EdgeInsets.all(24),
             child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Editar Contenido", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx))
                ]),
                const SizedBox(height: 10),
                
                // BARRA AGREGAR
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      // Buscador
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (v) async {
                          if (v.text.isEmpty) return [];
                          final res = await _supabase.from('products').select().ilike('name', '%${v.text}%').limit(5);
                          return List<Map<String, dynamic>>.from(res);
                        },
                        displayStringForOption: (o) => o['name'],
                        onSelected: (s) {
                          nameCtrl.text = s['name'];
                          priceCtrl.text = s['price'].toString();
                        },
                        fieldViewBuilder: (c, ctrl, f, s) => TextField(controller: ctrl, focusNode: f, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Buscar producto...", prefixIcon: Icon(Icons.search, color: Colors.grey), border: InputBorder.none, isDense: true)),
                      ),
                      const Divider(color: Colors.white10),
                      Row(
                        children: [
                          Expanded(flex: 2, child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Cant.", border: InputBorder.none, isDense: true))),
                          Container(width: 1, height: 20, color: Colors.white24),
                          const SizedBox(width: 10),
                          Expanded(flex: 2, child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "\$ Precio", border: InputBorder.none, isDense: true))),
                          IconButton.filled(
                            onPressed: () {
                              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                              setModalState(() {
                                tempCart.add({'name': nameCtrl.text, 'price': AppFormatters.stringToDouble(priceCtrl.text), 'qty': int.tryParse(qtyCtrl.text) ?? 1});
                                nameCtrl.clear(); priceCtrl.clear(); qtyCtrl.text = "1";
                              });
                            }, 
                            icon: const Icon(Icons.add)
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // LISTA EDITABLE
                Expanded(
                  child: ListView.separated(
                    itemCount: tempCart.length,
                    separatorBuilder: (_,__) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final item = tempCart[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text("\$${item['price']} c/u", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ])),
                            Row(children: [
                              IconButton(icon: const Icon(Icons.remove_circle, size: 16, color: Colors.grey), onPressed: () {
                                if (item['qty'] > 1) setModalState(() => item['qty']--);
                              }),
                              Text("${item['qty']}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add_circle, size: 16, color: Colors.grey), onPressed: () => setModalState(() => item['qty']++)),
                            ]),
                            const SizedBox(width: 10),
                            Text("\$${AppFormatters.money(item['qty'] * item['price'])}", style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 5),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => setModalState(() => tempCart.removeAt(i))),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const Divider(color: Colors.white24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("NUEVO TOTAL", style: TextStyle(color: Colors.grey)),
                    Text("\$ ${AppFormatters.money(totalTemp)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (tempCart.isEmpty) return;
                      String finalDesc = "POS: " + tempCart.map((e) => "${e['qty']}x ${e['name']} (\$${AppFormatters.money(e['price'] * e['qty'])})").join(", ");
                      await _supabase.from('movements').update({
                        'amount': totalTemp,
                        'description': finalDesc,
                        'created_at': editDate.toUtc().toIso8601String()
                      }).eq('id', mov['id']);
                      Navigator.pop(ctx);
                      _refreshBalance();
                    },
                    child: const Text("GUARDAR CAMBIOS"),
                  ),
                )
              ],
            ),
          );
        }
      ),
    );
  }

  // --- PARSER DE DESCRIPCIÓN ---
  List<Map<String, dynamic>> _parseDescription(String desc) {
    List<Map<String, dynamic>> items = [];
    try {
      final clean = desc.replaceAll("POS: ", "");
      final parts = clean.split(", ");
      for (var part in parts) {
        final match = RegExp(r'(\d+)x\s+(.+?)\s+\(\$(\d+\.?\d*)\)').firstMatch(part);
        if (match != null) {
          int qty = int.parse(match.group(1)!);
          String name = match.group(2)!.trim();
          double lineTotal = double.parse(match.group(3)!);
          items.add({'name': name, 'qty': qty, 'price': lineTotal / qty});
        }
      }
    } catch (_) {}
    return items;
  }

  void _showMsg(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final balance = (_customerData?['current_balance'] as num?)?.toDouble() ?? widget.initialBalance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Ficha de Cliente"),
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), onPressed: _refreshBalance),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.background, Color(0xFF0F172A)])),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 10),
            _buildBalanceDashboard(balance, provider.activeRate),
            _buildActionHub(balance, provider),
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase.from('movements').stream(primaryKey: ['id']).eq('customer_id', widget.customerId).order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var data = snapshot.data!;
                  if (_filter != 'ALL') data = data.where((m) => m['type'] == _filter).toList();
                  if (data.isEmpty) return const Center(child: Text("Sin registros", style: TextStyle(color: Colors.white24)));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.length,
                    itemBuilder: (ctx, i) {
                      final mov = data[i];
                      return _buildMovementItem(mov, mov['type'] == 'DEBT', DateTime.parse(mov['created_at']), provider.activeRate, provider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Mantiene el resto de widgets: _buildBalanceDashboard, _buildActionHub, _buildFilterBar)
  // Asegúrate de copiar las funciones auxiliares de diseño del código anterior si no están aquí
  
  Widget _buildBalanceDashboard(double balance, double rate) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
      child: Column(
        children: [
          Text(widget.customerName.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text("\$ ${AppFormatters.money(balance)}", style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
          Text("≈ Bs. ${AppFormatters.money(balance * rate)}", style: TextStyle(color: AppTheme.primary.withOpacity(0.8), fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionHub(double balance, AppStateProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _hubBtn(Icons.add_card_rounded, "ABONAR", AppTheme.accentGreen, () => _showAbonoDialog(provider)),
          _hubBtn(Icons.picture_as_pdf_rounded, "REPORTE", Colors.redAccent, () async {
             final movements = await _supabase.from('movements').select().eq('customer_id', widget.customerId).order('created_at');
             await ReportGenerator.generateAccountStatement(customerName: widget.customerName, customerId: widget.customerId, currentBalance: balance, movements: List<Map<String, dynamic>>.from(movements));
          }),
          _hubBtn(Icons.chat_bubble_rounded, "ENVIAR", const Color(0xFF25D366), () => _sendWhatsApp(balance, provider)),
        ],
      ),
    );
  }

  Widget _hubBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 22),
          style: IconButton.styleFrom(backgroundColor: color.withOpacity(0.12), padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withOpacity(0.3)))),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 16),
      child: Row(
        children: [
          _filterChip("Historial", 'ALL'),
          const SizedBox(width: 8),
          _filterChip("Deudas", 'DEBT'),
          const SizedBox(width: 8),
          _filterChip("Abonos", 'CREDIT'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    bool isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildMovementItem(Map<String, dynamic> mov, bool isDebt, DateTime date, double rate, AppStateProvider provider) {
    final amount = (mov['amount'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: ListTile(
        onTap: () => isDebt ? _showTicketView(mov) : _showAbonoDialog(provider, existingMov: mov),
        leading: Icon(isDebt ? Icons.shopping_bag_outlined : Icons.check_circle_outline, color: isDebt ? Colors.orange : Colors.green, size: 20),
        title: Text(mov['description'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("${DateFormat('dd/MM HH:mm').format(date)} • ≈ Bs. ${AppFormatters.money(amount * rate)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
        trailing: Text("${isDebt ? '+' : '-'} \$${AppFormatters.money(amount)}", style: TextStyle(color: isDebt ? Colors.white : AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}