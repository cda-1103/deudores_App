import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/formatters.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController(); 
  final TextEditingController _manualRateCtrl = TextEditingController(); 

  Map<String, dynamic>? _selectedCustomer;
  String? _selectedMethod;
  DateTime _selectedDate = DateTime.now();
  String _bsEquivalent = "Bs. 0,00";
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    _manualRateCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _getPaymentMethods() async {
    try {
      final response = await _supabase.from('payment_methods').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> _processPayment(AppStateProvider provider) async {
    if (_selectedCustomer == null || _amountCtrl.text.isEmpty || _selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete los campos requeridos")));
      return;
    }

    final amount = AppFormatters.stringToDouble(_amountCtrl.text);
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('movements').insert({
        'customer_id': _selectedCustomer!['id'],
        'type': 'CREDIT', 
        'amount': amount,
        'description': 'Abono ($_selectedMethod) ${_noteCtrl.text.isNotEmpty ? "- ${_noteCtrl.text}" : ""}',
        'payment_method': _selectedMethod, 
        'created_at': _selectedDate.toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abono guardado"), backgroundColor: AppTheme.accentGreen));
        _clearForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedCustomer = null;
      _amountCtrl.clear();
      _noteCtrl.clear();
      _searchCtrl.clear(); 
      _selectedDate = DateTime.now();
      _bsEquivalent = "Bs. 0,00";
    });
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
    final provider = Provider.of<AppStateProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            const Text("Registrar Abonos Global", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
          ],
          if (isMobile)
            Column(
              children: [
                _buildCustomerSearchCard(),
                const SizedBox(height: 20),
                _buildPaymentFormCard(provider),
                const SizedBox(height: 80),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildCustomerSearchCard()),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _buildPaymentFormCard(provider)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildCustomerSearchCard() {
    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person_search_rounded, color: Colors.blueAccent), 
              SizedBox(width: 8), 
              Text("1. Buscar Cliente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
            ]
          ),
          const SizedBox(height: 20),
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                final res = await _supabase.from('customers').select('id, name, current_balance').order('name').limit(10);
                return List<Map<String, dynamic>>.from(res);
              }
              final response = await _supabase.from('customers').select('id, name, current_balance').ilike('name', '%${textEditingValue.text}%').limit(10);
              return List<Map<String, dynamic>>.from(response);
            },
            displayStringForOption: (option) => option['name'],
            onSelected: (selection) => setState(() => _selectedCustomer = selection),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_searchCtrl.text != controller.text && controller.text.isEmpty) {
                _searchCtrl.text = ""; 
              }
              return TextField(
                controller: controller, 
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Escribe el nombre...", 
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft, 
                child: Material(
                  elevation: 8, 
                  color: Colors.transparent, 
                  child: _glassContainer(
                    padding: EdgeInsets.zero, 
                    borderRadius: 16, 
                    child: SizedBox(
                      width: 300, 
                      child: ListView.builder(
                        padding: EdgeInsets.zero, 
                        shrinkWrap: true, 
                        itemCount: options.length, 
                        itemBuilder: (ctx, i) { 
                          final opt = options.elementAt(i); 
                          return ListTile(
                            title: Text(opt['name'], style: const TextStyle(color: Colors.white)), 
                            subtitle: Text("Deuda: \$${AppFormatters.money(opt['current_balance'])}", style: TextStyle(color: (opt['current_balance'] > 0) ? Colors.redAccent : Colors.greenAccent)), 
                            onTap: () => onSelected(opt)
                          ); 
                        }
                      )
                    )
                  )
                )
              );
            },
          ),
          const SizedBox(height: 24),
          if (_selectedCustomer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30, 
                    backgroundColor: AppTheme.primary, 
                    child: Text(
                      _selectedCustomer!['name'][0].toUpperCase(), 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                    )
                  ),
                  const SizedBox(height: 12),
                  Text(_selectedCustomer!['name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const Divider(color: Colors.white10, height: 24),
                  const Text("DEUDA PENDIENTE", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
                  Text(
                    "\$${AppFormatters.money(_selectedCustomer!['current_balance'])}", 
                    style: TextStyle(color: _selectedCustomer!['current_balance'] > 0 ? AppTheme.accentRed : AppTheme.accentGreen, fontSize: 32, fontWeight: FontWeight.w900)
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentFormCard(AppStateProvider provider) {
    if (_manualRateCtrl.text.isEmpty && provider.isManual) {
      _manualRateCtrl.text = provider.manualRate.toString();
    }

    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              const Text("2. Detalles del Abono", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)), 
              _buildDateBadge()
            ]
          ),
          const SizedBox(height: 24),

          // PANEL DE TASA (PERMITE EDITAR SI ES MANUAL)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(provider.isManual ? "EDITAR TASA MANUAL" : "TASA BCV ACTUAL", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      if (provider.isManual)
                        TextField(
                          controller: _manualRateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          decoration: const InputDecoration(isDense: true, prefixText: "Bs. ", prefixStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                          onChanged: (v) {
                            double val = AppFormatters.stringToDouble(v);
                            if (val > 0) {
                              provider.setManualMode(val);
                              setState(() {
                                final amount = AppFormatters.stringToDouble(_amountCtrl.text);
                                _bsEquivalent = "Bs. ${AppFormatters.money(amount * val)}";
                              });
                            }
                          },
                        )
                      else
                        Text("Bs. ${AppFormatters.money(provider.activeRate)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                    ]
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    const Text("EQUIVALENTE EN BS.", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), 
                    Text(_bsEquivalent, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                  ]
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Monto a Recibir (\$)", 
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
              prefixIcon: const Icon(Icons.attach_money_rounded, color: AppTheme.accentGreen, size: 30),
              filled: true, 
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) {
              final amount = AppFormatters.stringToDouble(val);
              setState(() => _bsEquivalent = "Bs. ${AppFormatters.money(amount * provider.activeRate)}");
            },
          ),
          
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPaymentMethods(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final methods = snapshot.data!;
              return DropdownButtonFormField<String>(
                value: _selectedMethod,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Forma de Pago",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54), 
                  filled: true, 
                  fillColor: Colors.black26, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                ),
                items: methods.map((m) => DropdownMenuItem<String>(value: m['name'], child: Text(m['name']))).toList(),
                onChanged: (val) => setState(() => _selectedMethod = val),
              );
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Nota / Referencia", 
              labelStyle: const TextStyle(color: Colors.white54), 
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white54), 
              filled: true, 
              fillColor: Colors.black26, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 65,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _processPayment(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: AppTheme.primary.withOpacity(0.4)
              ),
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded, size: 28),
              label: const Text("PROCESAR ABONO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, 
          initialDate: _selectedDate, 
          firstDate: DateTime(2000), 
          lastDate: DateTime.now(), 
          builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!)
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent, size: 16), 
            const SizedBox(width: 8), 
            Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
          ]
        ),
      ),
    );
  }
}