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
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _priceCtrl = TextEditingController();
  final SalesService _salesService = SalesService();

  TextEditingController? _searchController;
  DateTime _selectedDate = DateTime.now();
  String _selectedProductName = "";
  int? _selectedProductId;

  @override
  Widget build(BuildContext context) {
    double total =
        _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Módulo de Ventas",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const Text("Registra ventas de inventario o items libres.",
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IZQUIERDA: CARRITO
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                flex: 3, child: _buildProductAutocomplete()),
                            const SizedBox(width: 10),
                            SizedBox(
                                width: 100,
                                child: TextField(
                                    controller: _priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                        labelText: "Precio",
                                        prefixText: "\$"))),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ElevatedButton(
                                  onPressed: _addToCart,
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(16)),
                                  child: const Icon(Icons.add)),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text("Carrito Actual",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Divider(color: Colors.white10),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10),
                            itemBuilder: (ctx, i) {
                              final item = _cart[i];
                              final isFreeItem = item['productId'] == null;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                    isFreeItem ? Icons.edit_note : Icons.liquor,
                                    color: isFreeItem
                                        ? Colors.orange
                                        : Colors.blue),
                                title: Text(item['name'],
                                    style:
                                        const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                    "\$${item['price']}  ${isFreeItem ? '(Item Libre)' : ''}",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.grey),
                                        onPressed: () {
                                          if (item['qty'] > 1)
                                            setState(() => item['qty']--);
                                        }),
                                    Text("${item['qty']}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.grey),
                                        onPressed: () =>
                                            setState(() => item['qty']++)),
                                    const SizedBox(width: 10),
                                    Text(
                                        "\$${(item['price'] * item['qty']).toStringAsFixed(2)}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: AppTheme.accentRed,
                                            size: 20),
                                        onPressed: () =>
                                            setState(() => _cart.removeAt(i))),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // DERECHA: RESUMEN
              Expanded(
                flex: 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detalles de Venta",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withOpacity(0.05)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Fecha de Registro",
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(dateStr,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16))
                                      ]),
                                  const Icon(Icons.calendar_today,
                                      color: AppTheme.primary),
                                ]),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 30, color: Colors.white10),
                        _SummaryRow(
                            label: "Total a Pagar",
                            value: "\$${total.toStringAsFixed(2)}",
                            isTotal: true),
                        const Spacer(),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: _cart.isEmpty
                                    ? null
                                    : () => _showCheckoutDialog(total),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20)),
                                child: const Text("COBRAR / DIVIDIR"))),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // --- LÓGICA DE COBRO (CHECKOUT) ACTUALIZADA ---
  void _showCheckoutDialog(double totalAmount) async {
    // 1. Cargamos clientes iniciales
    final initialCustomers =
        await Supabase.instance.client.from('customers').select().order('name');

    // Variables de estado del diálogo
    List<Map<String, dynamic>> allCustomers =
        List<Map<String, dynamic>>.from(initialCustomers);
    List<String> selectedIds = [];
    Map<String, double> customAmounts = {}; // Para montos personalizados
    String searchQuery = "";
    bool isCustomSplit = false; // Toggle: false=Equitativo, true=Manual

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Obliga a usar botones
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filtrado de clientes por búsqueda
            final filteredCustomers = allCustomers
                .where((c) => c['name']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            // Cálculos
            double assignedTotal = 0;
            if (isCustomSplit) {
              assignedTotal =
                  customAmounts.values.fold(0, (sum, val) => sum + val);
            }

            // Monto equitativo para mostrar como referencia
            final equalShare =
                selectedIds.isEmpty ? 0 : totalAmount / selectedIds.length;

            // Validación para activar botón "Confirmar"
            bool isValid = false;
            if (selectedIds.isNotEmpty) {
              if (!isCustomSplit) {
                isValid = true; // Equitativo siempre es válido si hay gente
              } else {
                // En manual, la suma debe ser igual al total (con margen de error de centavos)
                isValid = (assignedTotal - totalAmount).abs() < 0.05;
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("Procesar Venta",
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 500, // Hacemos el diálogo más ancho
                height: 600,
                child: Column(
                  children: [
                    // HEADER RESUMEN
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("TOTAL VENTA",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                                Text("\$${totalAmount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold)),
                              ]),

                          // Toggle de Modo de División
                          Row(children: [
                            const Text("Equitativo",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Switch(
                              value: isCustomSplit,
                              activeColor: AppTheme.primary,
                              onChanged: (val) => setDialogState(() {
                                isCustomSplit = val;
                                // Reiniciar montos manuales si cambia modo
                                customAmounts.clear();
                              }),
                            ),
                            const Text("Manual",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ])
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // BUSCADOR + CREAR CLIENTE
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Buscar cliente...",
                              prefixIcon:
                                  const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.black26,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
                            ),
                            onChanged: (val) =>
                                setDialogState(() => searchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón de CREAR CLIENTE RÁPIDO
                        IconButton.filled(
                          icon: const Icon(Icons.person_add),
                          style: IconButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen),
                          tooltip: "Crear Nuevo Cliente",
                          onPressed: () async {
                            // Abrimos diálogo anidado para crear
                            final newClient =
                                await _showQuickCreateClientDialog(context);
                            if (newClient != null) {
                              setDialogState(() {
                                allCustomers.add(
                                    newClient); // Lo agregamos a la lista local
                                selectedIds.add(
                                    newClient['id']); // Lo auto-seleccionamos
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white24),

                    // LISTA DE CLIENTES
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
                                borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              // Checkbox
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
                              // Nombre
                              title: Text(c['name'],
                                  style: const TextStyle(color: Colors.white)),
                              // Input de Monto (Solo si está seleccionado y en modo Manual)
                              trailing: (isSelected && isCustomSplit)
                                  ? SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: customAmounts[c['id']]
                                                ?.toString() ??
                                            "",
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          hintText: "0.00",
                                          prefixText: "\$",
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 5, horizontal: 5),
                                          isDense: true,
                                          enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.grey)),
                                          focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: AppTheme.primary)),
                                        ),
                                        onChanged: (val) {
                                          // Actualizar mapa de montos
                                          final amount =
                                              double.tryParse(val) ?? 0;
                                          setDialogState(() =>
                                              customAmounts[c['id']] = amount);
                                        },
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

                    // FOOTER (Solo visible en modo manual para ver cuánto falta)
                    if (isCustomSplit)
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: (totalAmount - assignedTotal).abs() < 0.05
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                "Asignado: \$${assignedTotal.toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.white)),
                            Text(
                                "Faltan: \$${(totalAmount - assignedTotal).clamp(0, totalAmount).toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
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

                          // PREPARAMOS LA LÓGICA DE SPLIT
                          // Si es manual usamos customAmounts, si es equitativo calculamos

                          try {
                            // Construimos el mapa final de montos
                            Map<String, double> finalSplit = {};

                            if (isCustomSplit) {
                              finalSplit = customAmounts;
                            } else {
                              // Modo Equitativo
                              double perPerson = double.parse(
                                  (totalAmount / selectedIds.length)
                                      .toStringAsFixed(2));
                              for (var id in selectedIds) {
                                finalSplit[id] = perPerson;
                              }
                              // Ajuste de centavos (el último paga la diferencia)
                              // Esto evita errores de redondeo
                              /* (Opcional: lógica avanzada de redondeo aquí) */
                            }

                            // Llamamos al servicio (MODIFICADO para recibir map de montos si es necesario,
                            // o iteramos aquí mismo)

                            // IMPORTANTE: El servicio actual usa lógica simple.
                            // Vamos a llamar processSale con una lógica adaptada.

                            // Como el servicio `processSale` actual divide equitativamente,
                            // para soportar esto limpiamente, es mejor iterar aquí y guardar.

                            // Opción A: Modificar servicio (Mejor práctica)
                            // Opción B: Adaptar aquí. Usaremos Opción A modificada abajo.

                            await _salesService.processSaleWithCustomSplit(
                              splitData:
                                  finalSplit, // { clientId: amount, clientId2: amount }
                              items: _cart,
                              totalAmount: totalAmount,
                              note: "Venta POS",
                              customDate: _selectedDate,
                            );

                            if (mounted) {
                              setState(() {
                                _cart.clear();
                                _selectedDate = DateTime.now();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Venta Registrada Correctamente!")));
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")));
                          }
                        }
                      : null, // Deshabilitado si no es válido
                  child: const Text("CONFIRMAR VENTA"),
                )
              ],
            );
          },
        );
      },
    );
  }

  // Mini diálogo para crear cliente rápido
  Future<Map<String, dynamic>?> _showQuickCreateClientDialog(
      BuildContext context) async {
    final nameCtrl = TextEditingController();
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Nuevo Cliente Rápido",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: "Nombre"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                // Guardamos en Supabase
                final res = await Supabase.instance.client
                    .from('customers')
                    .insert({'name': nameCtrl.text, 'current_balance': 0})
                    .select()
                    .single();
                if (ctx.mounted)
                  Navigator.pop(ctx, res); // Devolvemos el cliente creado
              } catch (e) {
                // Manejo de error
              }
            },
            child: const Text("Crear"),
          )
        ],
      ),
    );
  }

  // ... (Resto de funciones: _pickDate, _buildProductAutocomplete, _addToCart)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        builder: (context, child) =>
            Theme(data: AppTheme.darkTheme, child: child!));
    if (picked != null) setState(() => _selectedDate = picked);
  }

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
              labelText: "Buscar o Item Libre",
              prefixIcon: Icon(Icons.search, color: Colors.grey)),
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
                                  style: const TextStyle(
                                      color: AppTheme.accentGreen)),
                              onTap: () => onSelected(option));
                        }))));
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
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  const _SummaryRow(
      {required this.label, required this.value, this.isTotal = false});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              color: isTotal ? Colors.white : Colors.grey,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
      Text(value,
          style: TextStyle(
              color: isTotal ? Colors.white : Colors.white,
              fontSize: isTotal ? 24 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal))
    ]);
  }
}
