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
  // Estado del Carrito y Venta
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _priceCtrl = TextEditingController();
  final SalesService _salesService = SalesService();

  // Controladores auxiliares
  TextEditingController? _searchController;
  DateTime _selectedDate = DateTime.now();
  String _selectedProductName = "";
  int? _selectedProductId;

  @override
  Widget build(BuildContext context) {
    // Calculamos el total sumando (precio * cantidad) de cada item
    double total = _cart.fold(
      0,
      (sum, item) => sum + (item['price'] * item['qty']),
    );

    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isMobile = MediaQuery.of(context).size.width < 800;

    // --- SECCIÓN 1: CARRITO DE COMPRAS ---
    Widget cartSection = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila de Inputs (Buscador + Precio + Botón)
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // ALINEACIÓN CENTRAL PERFECTA
              children: [
                // 1. BUSCADOR
                Expanded(
                  flex: 3,
                  child: _buildProductAutocomplete(),
                ),
                const SizedBox(width: 12),

                // 2. PRECIO
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Precio",
                      prefixText: "\$ ",
                      isDense: true,
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      // Padding específico para igualar altura visualmente con el botón
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 3. BOTÓN AGREGAR
                SizedBox(
                  height:
                      56, // Altura que coincide con los Inputs Material estándar
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _addToCart,
                    style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4))),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              "Carrito Actual",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Divider(color: Colors.white10),

            // Lista visual de items
            isMobile && _cart.isEmpty
                ? const SizedBox(
                    height: 50,
                    child: Center(
                      child: Text(
                        "Carrito vacío",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Expanded(
                    flex: isMobile ? 0 : 1,
                    child: SizedBox(
                      height: isMobile ? 200 : null,
                      child: ListView.separated(
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (ctx, i) {
                          return _CartItemTile(
                            key: ValueKey(_cart[i]),
                            item: _cart[i],
                            onDelete: () => setState(() => _cart.removeAt(i)),
                            onUpdate: () => setState(() {}),
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );

    // --- SECCIÓN 2: RESUMEN Y ACCIONES ---
    Widget summarySection = Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Fecha Registro",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                    const Icon(Icons.calendar_today, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 30, color: Colors.white10),

            // Total Calculado
            _SummaryRow(
              label: "Total a Pagar",
              value: "\$${total.toStringAsFixed(2)}",
              isTotal: true,
            ),
            const Spacer(),

            // Botón Cobrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _cart.isEmpty ? null : () => _showCheckoutDialog(total),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: const Text("COBRAR / DIVIDIR"),
              ),
            ),
          ],
        ),
      ),
    );

    // LAYOUT PRINCIPAL
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          const Text(
            "Módulo de Ventas",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Expanded(
          child: isMobile
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 400, child: cartSection),
                      const SizedBox(height: 10),
                      SizedBox(height: 250, child: summarySection),
                      const SizedBox(height: 80),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: cartSection),
                    const SizedBox(width: 20),
                    Expanded(flex: 1, child: summarySection)
                  ],
                ),
        ),
      ],
    );
  }

  // --- FUNCIONES AUXILIARES ---

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: AppTheme.darkTheme, child: child!);
      },
    );

    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['name'],
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }

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
            labelText: "Buscar o Libre",
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: OutlineInputBorder(),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            // Aseguramos padding vertical para que coincida con el precio
            contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
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
                    title: Text(
                      option['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "\$${option['price']}",
                      style: const TextStyle(color: AppTheme.accentGreen),
                    ),
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

  void _showCheckoutDialog(double totalAmount) async {
    final customers =
        await Supabase.instance.client.from('customers').select().order('name');

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
            final filteredCustomers = List<Map<String, dynamic>>.from(customers)
                .where((c) => c['name']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            double assignedTotal = isCustomSplit
                ? customAmounts.values.fold(0, (sum, val) => sum + val)
                : 0;

            final equalShare =
                selectedIds.isEmpty ? 0 : totalAmount / selectedIds.length;

            bool isValid = selectedIds.isNotEmpty &&
                (!isCustomSplit || (assignedTotal - totalAmount).abs() < 0.05);

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text(
                "Procesar Venta",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 500,
                height: 600,
                child: Column(
                  children: [
                    // Header con Switch
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "TOTAL",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                              Text(
                                "\$${totalAmount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                "Equitativo",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              Switch(
                                value: isCustomSplit,
                                activeColor: AppTheme.primary,
                                onChanged: (val) => setDialogState(() {
                                  isCustomSplit = val;
                                  customAmounts.clear();
                                }),
                              ),
                              const Text(
                                "Manual",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Buscador
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Buscar cliente...",
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                      onChanged: (val) =>
                          setDialogState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 10),

                    // Lista de Clientes
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (ctx, i) {
                          final c = filteredCustomers[i];
                          final isSelected = selectedIds.contains(c['id']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.1)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
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
                              title: Text(
                                c['name'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: (isSelected && isCustomSplit)
                                  ? SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        initialValue: customAmounts[c['id']]
                                                ?.toString() ??
                                            "",
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        onChanged: (val) {
                                          setDialogState(() =>
                                              customAmounts[c['id']] =
                                                  double.tryParse(val) ?? 0);
                                        },
                                      ),
                                    )
                                  : isSelected
                                      ? Text(
                                          "\$${equalShare.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                              color: AppTheme.accentGreen),
                                        )
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
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          Navigator.pop(context);

                          Map<String, double> finalSplit = {};
                          if (isCustomSplit) {
                            finalSplit = customAmounts;
                          } else {
                            double perPerson = double.parse(
                                (totalAmount / selectedIds.length)
                                    .toStringAsFixed(2));
                            for (var id in selectedIds) {
                              finalSplit[id] = perPerson;
                            }
                          }

                          await _salesService.processSaleWithCustomSplit(
                            splitData: finalSplit,
                            items: _cart,
                            totalAmount: totalAmount,
                            note: "Venta POS",
                            // --- AQUÍ ESTÁ EL CAMBIO CLAVE ---
                            customDate:
                                _selectedDate.toUtc(), // Enviamos en UTC
                          );

                          if (mounted) {
                            setState(() {
                              _cart.clear();
                              _selectedDate = DateTime.now();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Venta Registrada!"),
                              ),
                            );
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

// --- WIDGET DE ITEM DE CARRITO (Con Cantidad Editable) ---
class _CartItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _CartItemTile({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item['qty'].toString());
  }

  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['qty'] != widget.item['qty']) {
      final currentPos = _qtyCtrl.selection.base.offset;
      _qtyCtrl.text = widget.item['qty'].toString();
      if (currentPos != -1 && currentPos <= _qtyCtrl.text.length) {
        _qtyCtrl.selection =
            TextSelection.fromPosition(TextPosition(offset: currentPos));
      }
    }
  }

  void _updateQty(String val) {
    int? newQty = int.tryParse(val);
    if (newQty != null && newQty > 0) {
      widget.item['qty'] = newQty;
      widget.onUpdate();
    }
  }

  void _changeQtyBy(int delta) {
    int current = widget.item['qty'];
    int newVal = current + delta;
    if (newVal > 0) {
      setState(() {
        widget.item['qty'] = newVal;
        _qtyCtrl.text = newVal.toString();
      });
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFreeItem = widget.item['productId'] == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isFreeItem ? Icons.edit_note : Icons.liquor,
        color: isFreeItem ? Colors.orange : Colors.blue,
      ),
      title: Text(
        widget.item['name'],
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        "\$${widget.item['price']}",
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => _changeQtyBy(-1),
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _updateQty,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => _changeQtyBy(1),
          ),
          const SizedBox(width: 10),
          Text(
            "\$${(widget.item['price'] * widget.item['qty']).toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete,
              color: AppTheme.accentRed,
              size: 20,
            ),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.grey,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white,
            fontSize: isTotal ? 24 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        )
      ],
    );
  }
}
