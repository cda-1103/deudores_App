import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../data/services/sales_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // --- ESTADO ---
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _priceCtrl = TextEditingController();
  final SalesService _salesService = SalesService();

  TextEditingController? _searchController; // Referencia para limpiar input
  DateTime _selectedDate = DateTime.now();
  String _selectedProductName = "";
  int? _selectedProductId;

  // --- UI PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    // Cálculo de totales
    double total =
        _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Punto de quiebre para responsive
    final isMobile = MediaQuery.of(context).size.width < 900;

    // Si es móvil, usamos un layout vertical optimizado
    if (isMobile) {
      return _buildMobileLayout(total, dateStr);
    }

    // Si es escritorio, usamos el layout de dos columnas
    return _buildDesktopLayout(total, dateStr);
  }

  // --- LAYOUT MÓVIL (Vertical) ---
  Widget _buildMobileLayout(double total, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Cabecera de Inputs (Fija arriba)
        Card(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildInputRow(),
          ),
        ),

        // 2. Lista de Items (Ocupa todo el espacio disponible)
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 60, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 10),
                      const Text("Carrito vacío",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (ctx, i) => _buildCartItem(_cart[i], i),
                ),
        ),

        // 3. Panel de Totales y Acción (Fijo abajo)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
            children: [
              // Fila de Fecha y Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(dateStr,
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("TOTAL",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("\$${total.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 15),
              // Botón de Cobrar Grande
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _cart.isEmpty ? null : () => _showCheckoutDialog(total),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text("COBRAR",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- LAYOUT ESCRITORIO (Dos Columnas) ---
  Widget _buildDesktopLayout(double total, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Módulo de Ventas",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLUMNA IZQUIERDA: Carrito
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildInputRow(),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white10),
                        Expanded(
                          child: _cart.isEmpty
                              ? const Center(
                                  child: Text("Agrega productos para comenzar",
                                      style: TextStyle(color: Colors.grey)))
                              : ListView.separated(
                                  itemCount: _cart.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(color: Colors.white10),
                                  itemBuilder: (ctx, i) =>
                                      _buildCartItem(_cart[i], i),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // COLUMNA DERECHA: Resumen
              Expanded(
                flex: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detalles",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 20),
                        // Selector Fecha
                        InkWell(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Fecha Venta",
                                    style: TextStyle(color: Colors.grey)),
                                Text(dateStr,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total a Pagar",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                            Text("\$${total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _cart.isEmpty
                                ? null
                                : () => _showCheckoutDialog(total),
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                backgroundColor: AppTheme.primary),
                            child: const Text("PROCESAR PAGO"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGETS REUTILIZABLES ---

  // Fila de inputs (Buscador + Precio + Botón)
  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildProductAutocomplete(),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Precio",
              prefixText: "\$",
              isDense: true, // Hace el input más compacto
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: _addToCart,
          style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.add, color: Colors.white),
        )
      ],
    );
  }

  // Item individual del carrito
  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final isFreeItem = item['productId'] == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isFreeItem
                ? Colors.orange.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(isFreeItem ? Icons.edit_note : Icons.liquor,
            color: isFreeItem ? Colors.orange : Colors.blue),
      ),
      title: Text(item['name'],
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text("\$${item['price']}",
          style: const TextStyle(color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleButton(
              icon: Icons.remove,
              onTap: () {
                if (item['qty'] > 1) setState(() => item['qty']--);
              }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text("${item['qty']}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          _CircleButton(
              icon: Icons.add, onTap: () => setState(() => item['qty']++)),
          const SizedBox(width: 15),
          Text("\$${(item['price'] * item['qty']).toStringAsFixed(2)}",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.delete, color: AppTheme.accentRed, size: 20),
            onPressed: () => setState(() => _cart.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE NEGOCIO ---

  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['name'],
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty)
          return const Iterable<Map<String, dynamic>>.empty();
        final response = await Supabase.instance.client
            .from('products')
            .select('id, name, price')
            .ilike('name', '%${textEditingValue.text}%')
            .limit(5);
        return List<Map<String, dynamic>>.from(response);
      },
      onSelected: (selection) {
        _selectedProductName = selection['name'];
        _selectedProductId = selection['id'];
        _priceCtrl.text = selection['price'].toString();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _searchController = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          onChanged: (val) {
            _selectedProductName = val;
            _selectedProductId = null;
          },
          decoration: const InputDecoration(
            labelText: "Buscar Producto o libre",
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            isDense: true,
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
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option['name'],
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text("\$${option['price']}",
                        style: const TextStyle(color: AppTheme.accentGreen)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _addToCart() {
    if (_selectedProductName.isEmpty || _priceCtrl.text.isEmpty) return;
    setState(() {
      _cart.add({
        'name': _selectedProductName,
        'price': double.parse(_priceCtrl.text),
        'qty': 1,
        'productId': _selectedProductId
      });
      _priceCtrl.clear();
      _searchController?.clear();
      _selectedProductName = "";
      _selectedProductId = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // --- DIÁLOGO DE COBRO (COMPLETO) ---
  void _showCheckoutDialog(double totalAmount) async {
    // Carga inicial de clientes
    final initialCustomers =
        await Supabase.instance.client.from('customers').select().order('name');
    final List<Map<String, dynamic>> allCustomers =
        List<Map<String, dynamic>>.from(initialCustomers);

    final List<String> selectedIds = [];
    Map<String, double> customAmounts = {};
    String searchQuery = "";
    bool isCustomSplit = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filtrar clientes
            final filteredCustomers = allCustomers
                .where((c) => c['name']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            // Lógica de validación
            double assignedTotal = isCustomSplit
                ? customAmounts.values.fold(0, (sum, val) => sum + val)
                : 0;
            final equalShare =
                selectedIds.isEmpty ? 0 : totalAmount / selectedIds.length;
            bool isValid = selectedIds.isNotEmpty &&
                (!isCustomSplit || (assignedTotal - totalAmount).abs() < 0.05);

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("Procesar Venta",
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 500, // Ancho fijo para que no se deforme
                height: 600,
                child: Column(
                  children: [
                    // Header con Switch
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TOTAL",
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                              Text("\$${totalAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              const Text("Equitativo",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              Switch(
                                value: isCustomSplit,
                                activeColor: AppTheme.primary,
                                onChanged: (val) => setDialogState(() {
                                  isCustomSplit = val;
                                  customAmounts.clear();
                                }),
                              ),
                              const Text("Manual",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Buscador
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Buscar cliente...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      ),
                      onChanged: (val) =>
                          setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),

                    // Lista de Selección
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (ctx, i) {
                          final c = filteredCustomers[i];
                          final isSelected = selectedIds.contains(c['id']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary.withOpacity(0.1)
                                    : null,
                                borderRadius: BorderRadius.circular(6)),
                            child: ListTile(
                              visualDensity: VisualDensity.compact,
                              leading: Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val!) {
                                      selectedIds.add(c['id']);
                                    } else {
                                      selectedIds.remove(c['id']);
                                      customAmounts.remove(c['id']);
                                    }
                                  });
                                },
                              ),
                              title: Text(c['name'],
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              trailing: (isSelected && isCustomSplit)
                                  ? SizedBox(
                                      width: 70,
                                      child: TextFormField(
                                        initialValue: customAmounts[c['id']]
                                                ?.toString() ??
                                            "",
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                            hintText: "0.00",
                                            isDense: true,
                                            contentPadding: EdgeInsets.all(8)),
                                        onChanged: (val) => setDialogState(() =>
                                            customAmounts[c['id']] =
                                                double.tryParse(val) ?? 0),
                                      ),
                                    )
                                  : isSelected
                                      ? Text(
                                          "\$${equalShare.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                              color: AppTheme.accentGreen))
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),

                    // Footer de Validación Manual
                    if (isCustomSplit)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Falta asignar: \$${(totalAmount - assignedTotal).toStringAsFixed(2)}",
                          style: TextStyle(
                              color: (totalAmount - assignedTotal).abs() < 0.05
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          Navigator.pop(context);
                          // Preparamos el split
                          Map<String, double> finalSplit = {};
                          if (isCustomSplit) {
                            finalSplit = customAmounts;
                          } else {
                            double perPerson = double.parse(
                                (totalAmount / selectedIds.length)
                                    .toStringAsFixed(2));
                            for (var id in selectedIds)
                              finalSplit[id] = perPerson;
                          }

                          try {
                            await _salesService.processSaleWithCustomSplit(
                                splitData: finalSplit,
                                items: _cart,
                                totalAmount: totalAmount,
                                note: "Venta POS",
                                customDate: _selectedDate);

                            if (mounted) {
                              setState(() {
                                _cart.clear();
                                _selectedDate = DateTime.now();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Venta Registrada!")));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")));
                          }
                        }
                      : null,
                  child: const Text("CONFIRMAR"),
                )
              ],
            );
          },
        );
      },
    );
  }
}

// Botón circular pequeño para + / -
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
