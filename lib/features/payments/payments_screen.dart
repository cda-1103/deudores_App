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

  // Controladores
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  // Estado
  Map<String, dynamic>? _selectedCustomer;
  String? _selectedMethod;
  DateTime _selectedDate = DateTime.now();
  String _bsEquivalent = "Bs. 0,00";
  bool _isLoading = false;

  // Carga de métodos de pago
  Future<List<Map<String, dynamic>>> _getPaymentMethods() async {
    try {
      final response = await _supabase.from('payment_methods').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // --- LÓGICA DE GUARDADO (CORREGIDA PARA EVITAR DOBLE RESTA) ---
  Future<void> _processPayment(AppStateProvider provider) async {
    if (_selectedCustomer == null) {
      _showMsg("Seleccione un cliente", Colors.orange);
      return;
    }
    if (_amountCtrl.text.isEmpty || _selectedMethod == null) {
      _showMsg("Monto y método son obligatorios", Colors.orange);
      return;
    }

    final amount = AppFormatters.stringToDouble(_amountCtrl.text);
    if (amount <= 0) {
      _showMsg("Monto inválido", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final customerId = _selectedCustomer!['id'];

      // 1. SOLO INSERTAR MOVIMIENTO
      // IMPORTANTE: Dejamos que el Trigger de Supabase actualice el saldo solo.
      // Así evitamos que se reste dos veces.
      await _supabase.from('movements').insert({
        'customer_id': customerId,
        'type': 'CREDIT', 
        'amount': amount,
        'description': 'Abono ($_selectedMethod) ${_noteCtrl.text.isNotEmpty ? "- ${_noteCtrl.text}" : ""}',
        'payment_method': _selectedMethod, 
        'created_at': _selectedDate.toUtc().toIso8601String(),
      });

      // 2. ACTUALIZACIÓN MANUAL ELIMINADA
      // Este bloque se ha removido porque tu DB ya hace el cálculo automáticamente.

      if (mounted) {
        _showMsg("Abono registrado con éxito", AppTheme.accentGreen);
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showMsg("Error al guardar: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  void _clearForm() {
    setState(() {
      _selectedCustomer = null;
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedDate = DateTime.now();
      _bsEquivalent = "Bs. 0,00";
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile) ...[
                const Text("Gestión de Abonos",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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
    );
  }

  // 1. TARJETA DE BÚSQUEDA DE CLIENTE (Estilo Glass Azul)
  Widget _buildCustomerSearchCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: "1. Buscar Cliente", icon: Icons.person_search_rounded),
          const SizedBox(height: 20),

          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                final res = await _supabase.from('customers').select('id, name, current_balance').order('name').limit(10);
                return List<Map<String, dynamic>>.from(res);
              }
              final response = await _supabase
                  .from('customers')
                  .select('id, name, current_balance')
                  .ilike('name', '%${textEditingValue.text}%')
                  .limit(10);
              return List<Map<String, dynamic>>.from(response);
            },
            displayStringForOption: (option) => option['name'],
            onSelected: (selection) => setState(() => _selectedCustomer = selection),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Escribe el nombre...",
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 300,
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (ctx, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          title: Text(opt['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text("Deuda: \$${AppFormatters.money(opt['current_balance'])}",
                              style: TextStyle(color: (opt['current_balance'] > 0) ? Colors.redAccent : Colors.greenAccent)),
                          onTap: () => onSelected(opt),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          if (_selectedCustomer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.blue)),
                  const SizedBox(height: 12),
                  Text(_selectedCustomer!['name'],
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const Divider(color: Colors.white10, height: 24),
                  const Text("SALDO PENDIENTE", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
                  Text("\$${AppFormatters.money(_selectedCustomer!['current_balance'])}",
                      style: const TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 2. TARJETA DE FORMULARIO (GLASS BLUE)
  Widget _buildPaymentFormCard(AppStateProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Detalles del Abono", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              _buildDateBadge(),
            ],
          ),
          const SizedBox(height: 24),

          // INPUT MONTO (GLASS BLUE)
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Monto a Recibir (\$)",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.white),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12), // CRISTAL TRANSPARENTE
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white)),
            ),
            onChanged: (val) {
              final amount = AppFormatters.stringToDouble(val);
              setState(() => _bsEquivalent = provider.toBs(amount));
            },
          ),
          
          const SizedBox(height: 12),
          
          // CONVERSIÓN Y TASA (ESTILO INTEGRADO)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("EQUIVALENTE EN BS.", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(_bsEquivalent, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("TASA BCV", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("Bs. ${AppFormatters.money(provider.activeRate)}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // FORMA DE PAGO
          const Text("FORMA DE PAGO", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPaymentMethods(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final methods = snapshot.data!;
              return DropdownButtonFormField<String>(
                value: _selectedMethod,
                dropdownColor: const Color(0xFF1E40AF),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payments_rounded, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
                items: methods.map((m) => DropdownMenuItem<String>(value: m['name'], child: Text(m['name']))).toList(),
                onChanged: (val) => setState(() => _selectedMethod = val),
              );
            },
          ),

          const SizedBox(height: 20),

          // NOTA (GLASS BLUE)
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Nota / Referencia (Opcional)",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
            ),
          ),

          const SizedBox(height: 32),

          // BOTÓN GUARDAR (ACCENTO BLANCO)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _processPayment(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Icon(Icons.verified_rounded, size: 28),
              label: const Text("CONFIRMAR ABONO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
            builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!));
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.primary, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
    ]);
  }
}