import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';

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
  String _bsEquivalent = "Bs. 0.00";
  bool _isLoading = false;

  // Carga inicial de métodos
  Future<List<Map<String, dynamic>>> _getPaymentMethods() async {
    final response =
        await _supabase.from('payment_methods').select().order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  // --- LÓGICA DE GUARDADO ---
  Future<void> _processPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Seleccione un cliente")));
      return;
    }
    if (_amountCtrl.text.isEmpty || _selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Monto y método son obligatorios")));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Monto inválido")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.from('movements').insert({
        'customer_id': _selectedCustomer!['id'],
        'type': 'CREDIT',
        'amount': amount,
        'description':
            'Abono ($_selectedMethod) ${_noteCtrl.text.isNotEmpty ? "- ${_noteCtrl.text}" : ""}',
        'payment_method': _selectedMethod,
        'created_at': _selectedDate.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Abono registrado con éxito"),
            backgroundColor: Colors.green));
        _clearForm();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedCustomer = null;
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedDate = DateTime.now();
      _bsEquivalent = "Bs. 0.00";
      // No limpiamos el método para agilizar pagos repetitivos
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Registro de Abonos",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 20),

          // --- DISEÑO ADAPTABLE ---
          if (isMobile)
            Column(
              children: [
                _buildCustomerSearchCard(),
                const SizedBox(height: 15),
                _buildPaymentFormCard(provider),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildCustomerSearchCard()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildPaymentFormCard(provider)),
              ],
            )
        ],
      ),
    );
  }

  // 1. TARJETA DE BÚSQUEDA DE CLIENTE
  Widget _buildCustomerSearchCard() {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. Seleccionar Cliente",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // AUTOCOMPLETE
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => option['name'],
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty)
                  return const Iterable<Map<String, dynamic>>.empty();
                // Buscamos clientes que coincidan
                final response = await _supabase
                    .from('customers')
                    .select('id, name, current_balance')
                    .ilike('name', '%${textEditingValue.text}%')
                    .limit(5);
                return List<Map<String, dynamic>>.from(response);
              },
              onSelected: (selection) {
                setState(() => _selectedCustomer = selection);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Buscar por nombre...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
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
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, i) {
                          final opt = options.elementAt(i);
                          return ListTile(
                            title: Text(opt['name'],
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text("Deuda: \$${opt['current_balance']}",
                                style: TextStyle(
                                    color: (opt['current_balance'] > 0)
                                        ? Colors.redAccent
                                        : Colors.greenAccent)),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // VISTA PREVIA DEL CLIENTE SELECCIONADO
            if (_selectedCustomer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.3))),
                child: Column(
                  children: [
                    const Icon(Icons.person, size: 40, color: Colors.blue),
                    const SizedBox(height: 10),
                    Text(_selectedCustomer!['name'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 5),
                    const Text("Saldo Actual Pendiente",
                        style: TextStyle(color: Colors.grey)),
                    Text("\$${_selectedCustomer!['current_balance']}",
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Ningún cliente seleccionado",
                      style: TextStyle(color: Colors.grey)),
                ),
              )
          ],
        ),
      ),
    );
  }

  // 2. TARJETA DE DETALLES DEL PAGO
  Widget _buildPaymentFormCard(AppStateProvider provider) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("2. Detalles del Abono",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MONTO
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        decoration: const InputDecoration(
                          labelText: "Monto (\$)",
                          prefixIcon:
                              Icon(Icons.attach_money, color: Colors.green),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final amount = double.tryParse(val) ?? 0;
                          setState(() => _bsEquivalent = provider.toBs(amount));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 5),
                        child: Text("≈ $_bsEquivalent",
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 15),

                // FECHA
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (c, child) =>
                              Theme(data: AppTheme.darkTheme, child: child!));
                      if (picked != null)
                        setState(() => _selectedDate = picked);
                    },
                    child: Container(
                      height: 60, // Misma altura visual que el input
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          const Icon(Icons.calendar_today, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 20),

            // MÉTODO DE PAGO
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getPaymentMethods(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final methods = snapshot.data!;
                return DropdownButtonFormField<String>(
                  value: _selectedMethod,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Forma de Pago",
                    prefixIcon: Icon(Icons.payment, color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                  items: methods
                      .map((m) => DropdownMenuItem<String>(
                          value: m['name'], child: Text(m['name'])))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedMethod = val),
                );
              },
            ),

            const SizedBox(height: 20),

            // NOTA OPCIONAL
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nota / Referencia (Opcional)",
                prefixIcon: Icon(Icons.note, color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("REGISTRAR ABONO",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
