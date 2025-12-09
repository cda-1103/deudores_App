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
    double total =
        _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

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
              children: [
                Expanded(
                    flex: 3,
                    child: _buildProductAutocomplete() // Buscador inteligente
                    ),
                const SizedBox(width: 10),
                SizedBox(
                    width: 80,
                    child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Precio",
                            prefixText: "\$",
                            isDense: true))),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          minimumSize: const Size(40, 40)),
                      child: const Icon(Icons.add)),
                )
              ],
            ),
            const SizedBox(height: 20),

            const Text("Carrito Actual",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(color: Colors.white10),

            // Lista visual de items
            isMobile && _cart.isEmpty
                ? const SizedBox(
                    height: 50,
                    child: Center(
                        child: Text("Carrito vacío",
                            style: TextStyle(color: Colors.grey))))
                : Expanded(
                    flex: isMobile ? 0 : 1,
                    child: SizedBox(
                      height: isMobile ? 200 : null,
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
                                color:
                                    isFreeItem ? Colors.orange : Colors.blue),
                            title: Text(item['name'],
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text("\$${item['price']}",
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón Menos
                                IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.grey,
                                        size: 20),
                                    onPressed: () {
                                      if (item['qty'] > 1)
                                        setState(() => item['qty']--);
                                    }),
                                Text("${item['qty']}",
                                    style:
                                        const TextStyle(color: Colors.white)),
                                // Botón Más
                                IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Colors.grey, size: 20),
                                    onPressed: () =>
                                        setState(() => item['qty']++)),
                                // Botón Eliminar
                                IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: AppTheme.accentRed, size: 20),
                                    onPressed: () =>
                                        setState(() => _cart.removeAt(i))),
                              ],
                            ),
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
            // Selector de Fecha
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withOpacity(0.05)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Fecha Registro",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Text(dateStr,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))
                          ]),
                      const Icon(Icons.calendar_today, color: AppTheme.primary),
                    ]),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 30, color: Colors.white10),

            // Total Calculado
            _SummaryRow(
                label: "Total a Pagar",
                value: "\$${total.toStringAsFixed(2)}",
                isTotal: true),
            const Spacer(),

            // Botón Cobrar
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed:
                        _cart.isEmpty ? null : () => _showCheckoutDialog(total),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 20)),
                    child: const Text("COBRAR / DIVIDIR"))),
          ],
        ),
      ),
    );

    // LAYOUT PRINCIPAL (Detecta Móvil vs PC)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          const Text("Módulo de Ventas",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 20),
        ],
        Expanded(
          child: isMobile
              ? SingleChildScrollView(
                  // Diseño Móvil: Scroll Vertical
                  child: Column(
                    children: [
                      SizedBox(height: 400, child: cartSection),
                      const SizedBox(height: 10),
                      SizedBox(height: 250, child: summarySection),
                      const SizedBox(height: 80), // Espacio extra abajo
                    ],
                  ),
                )
              : Row(
                  // Diseño PC: Dos columnas lado a lado
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

  // --- FUNCIONES LÓGICAS (Ahora sí, expandidas y legibles) ---

  /// Muestra el calendario para cambiar la fecha de la venta
  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(), // No se puede vender a futuro
        builder: (context, child) {
          // Aplicamos tema oscuro al calendario
          return Theme(data: AppTheme.darkTheme, child: child!);
        });

    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  /// Construye el campo de texto con autocompletado de productos
  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      // Cómo se muestra la opción en la lista (solo el nombre)
      displayStringForOption: (option) => option['name'],

      // Lógica de búsqueda en Supabase
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }

        // Consulta a la BD (ilike es case-insensitive)
        final response = await Supabase.instance.client
            .from('products')
            .select('id, name, price')
            .ilike('name', '%${textEditingValue.text}%')
            .limit(5); // Traemos máximo 5 sugerencias

        return List<Map<String, dynamic>>.from(response);
      },

      // Qué pasa cuando el usuario selecciona una opción de la lista
      onSelected: (selection) {
        _selectedProductName = selection['name'];
        _selectedProductId = selection['id'];
        _priceCtrl.text = selection['price'].toString();
      },

      // El campo de texto visible
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _searchController =
            controller; // Guardamos referencia para limpiarlo luego
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          onChanged: (val) {
            // Si el usuario escribe manualmente, reseteamos el ID (es item libre)
            _selectedProductName = val;
            _selectedProductId = null;
          },
          decoration: const InputDecoration(
              labelText: "Buscar o Libre",
              prefixIcon: Icon(Icons.search, color: Colors.grey)),
        );
      },

      // Diseño de la lista desplegable de opciones
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

  /// Agrega el producto configurado al carrito
  void _addToCart() {
    // Validaciones básicas
    if (_selectedProductName.isEmpty || _priceCtrl.text.isEmpty) return;

    setState(() {
      _cart.add({
        'name': _selectedProductName,
        'price': double.parse(_priceCtrl.text),
        'qty': 1,
        'productId': _selectedProductId
      });

      // Limpiamos formularios para el siguiente item
      _priceCtrl.clear();
      _searchController?.clear();
      _selectedProductName = "";
      _selectedProductId = null;
    });
  }

  /// Muestra el diálogo para seleccionar clientes y procesar el cobro
  void _showCheckoutDialog(double totalAmount) async {
    // 1. Cargamos clientes para mostrar en la lista
    final customers =
        await Supabase.instance.client.from('customers').select().order('name');

    final List<String> selectedIds = [];
    Map<String, double> customAmounts = {};
    String searchQuery = "";
    bool isCustomSplit = false; // Toggle: false=Equitativo, true=Manual

    if (!mounted) return;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            // Filtramos la lista localmente según la búsqueda
            final filteredCustomers = List<Map<String, dynamic>>.from(customers)
                .where((c) => c['name']
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            // Calculamos totales asignados si estamos en modo manual
            double assignedTotal = isCustomSplit
                ? customAmounts.values.fold(0, (sum, val) => sum + val)
                : 0;

            // Monto si fuera equitativo
            final equalShare =
                selectedIds.isEmpty ? 0 : totalAmount / selectedIds.length;

            // Validación para activar el botón
            bool isValid = selectedIds.isNotEmpty &&
                (!isCustomSplit || (assignedTotal - totalAmount).abs() < 0.05);

            return AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text("Procesar Venta",
                    style: TextStyle(color: Colors.white)),
                content: SizedBox(
                  width: 500,
                  height: 600,
                  child: Column(children: [
                    // --- HEADER CON SWITCH DE MODO ---
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
                                    const Text("TOTAL",
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 10)),
                                    Text("\$${totalAmount.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold))
                                  ]),
                              Row(children: [
                                const Text("Equitativo",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                Switch(
                                  value: isCustomSplit,
                                  activeColor: AppTheme.primary,
                                  onChanged: (val) => setDialogState(() {
                                    isCustomSplit = val;
                                    customAmounts
                                        .clear(); // Reseteamos montos al cambiar
                                  }),
                                ),
                                const Text("Manual",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12))
                              ])
                            ])),
                    const SizedBox(height: 15),

                    // --- BUSCADOR ---
                    TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "Buscar cliente...",
                            prefixIcon: Icon(Icons.search, color: Colors.grey)),
                        onChanged: (val) =>
                            setDialogState(() => searchQuery = val)),
                    const SizedBox(height: 10),

                    // --- LISTA DE CLIENTES ---
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
                                    style:
                                        const TextStyle(color: Colors.white)),
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
                                                color: AppTheme.accentGreen))
                                        : null),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar")),
                  ElevatedButton(
                      onPressed: isValid
                          ? () async {
                              Navigator.pop(context);

                              // Preparamos el mapa de división (Quién paga cuánto)
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

                              // Llamamos al servicio para guardar en Supabase
                              await _salesService.processSaleWithCustomSplit(
                                splitData: finalSplit,
                                items: _cart,
                                totalAmount: totalAmount,
                                note: "Venta POS",
                                customDate: _selectedDate,
                              );

                              if (mounted) {
                                setState(() {
                                  _cart.clear(); // Limpiamos el carrito
                                  _selectedDate =
                                      DateTime.now(); // Reseteamos fecha
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Venta Registrada!")));
                              }
                            }
                          : null, // Botón deshabilitado si los números no cuadran
                      child: const Text("CONFIRMAR"))
                ]);
          });
        });
  }
}

// Widget auxiliar para las filas del resumen
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
