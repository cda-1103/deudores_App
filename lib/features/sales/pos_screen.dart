import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../core/utils/formatters.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // --- ESTADO DEL CARRITO ---
  final List<Map<String, dynamic>> _cart = [];
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: "0");

  TextEditingController? _searchController; 
  DateTime _selectedDate = DateTime.now();
  String _selectedProductName = "";
  int? _selectedProductId;
  
  bool _isLoading = false;

  // --- ESTADO DE DIVISIÓN DE CUENTAS ---
  TextEditingController? _customerSearchController; 
  final List<Map<String, dynamic>> _selectedCustomers = [];
  bool _isSplitEqually = true;
  final Map<String, TextEditingController> _manualSplitCtrls = {};

  // --- LÓGICA DE CARRITO ---
  void _addToCart() {
    if (_selectedProductName.isEmpty || _priceCtrl.text.isEmpty) return;
    
    final price = AppFormatters.stringToDouble(_priceCtrl.text);
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    
    if (qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cantidad y precio deben ser mayores a 0")));
      return;
    }

    setState(() {
      _cart.add({
        'name': _selectedProductName,
        'price': price,
        'qty': qty,
        'productId': _selectedProductId
      });
      
      // LIMPIEZA
      _selectedProductName = "";
      _selectedProductId = null;
      _priceCtrl.clear();
      _qtyCtrl.text = "0"; 
      _searchController?.clear();

      _recalculateSplit(); 
    });
  }

  void _updateQtyInput(int delta) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newValue = current + delta;
    if (newValue >= 0) {
      setState(() {
        _qtyCtrl.text = newValue.toString();
      });
    }
  }

  void _updateCartItemQty(int index, int newQty) {
    setState(() {
      _cart[index]['qty'] = newQty;
      _recalculateSplit();
    });
  }

  void _removeCartItem(int index) {
    setState(() {
      _cart.removeAt(index);
      _recalculateSplit();
    });
  }

  // --- LÓGICA DE DIVISIÓN DE CUENTAS ---
  void _addCustomer(Map<String, dynamic> customer) {
    if (_selectedCustomers.any((c) => c['id'] == customer['id'])) return;
    setState(() {
      _selectedCustomers.add(customer);
      _manualSplitCtrls[customer['id']] = TextEditingController();
      _recalculateSplit();
    });
  }

  void _removeCustomer(String id) {
    setState(() {
      _selectedCustomers.removeWhere((c) => c['id'] == id);
      _manualSplitCtrls[id]?.dispose();
      _manualSplitCtrls.remove(id);
      _recalculateSplit();
    });
  }

  void _recalculateSplit() {
    if (_selectedCustomers.isEmpty) return;
    
    if (_isSplitEqually) {
      double total = _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
      double splitAmount = total / _selectedCustomers.length;
      
      for (var c in _selectedCustomers) {
        _manualSplitCtrls[c['id']]?.text = splitAmount.toStringAsFixed(2);
      }
    }
  }

  double get _totalAssignedManually {
    double sum = 0;
    for (var c in _selectedCustomers) {
      sum += AppFormatters.stringToDouble(_manualSplitCtrls[c['id']]?.text ?? "0");
    }
    return sum;
  }

  @override
  void dispose() {
    for (var ctrl in _manualSplitCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
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
    double total = _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: isMobile ? AppBar(title: const Text("Registrar Venta"), backgroundColor: Colors.transparent, elevation: 0) : null,
      body: isMobile ? _buildMobileLayout(total, dateStr) : _buildDesktopLayout(total, dateStr),
    );
  }

  Widget _buildDesktopLayout(double total, String dateStr) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. Selección de Productos", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                  const SizedBox(height: 24),
                  _buildProductSearchSection(),
                  const SizedBox(height: 30),
                  const Text("CARRITO ACTUAL", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  Expanded(child: _buildCartList()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildSummaryPanel(total, dateStr),
          )
        ],
      ),
    );
  }

  Widget _buildMobileLayout(double total, String dateStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _glassContainer(
            padding: const EdgeInsets.all(20),
            child: _buildProductSearchSection(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 350,
            child: _glassContainer(
              padding: const EdgeInsets.all(16),
              child: _buildCartList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 700, 
            child: _buildSummaryPanel(total, dateStr),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProductSearchSection() {
    return Column(
      children: [
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (textValue) async {
            if (textValue.text.isEmpty) return [];
            final res = await Supabase.instance.client.from('products').select().ilike('name', '%${textValue.text}%').limit(7);
            return List<Map<String, dynamic>>.from(res);
          },
          displayStringForOption: (opt) => opt['name'],
          onSelected: (selection) {
            setState(() {
              _selectedProductName = selection['name'];
              _selectedProductId = selection['id'];
              _priceCtrl.text = selection['price'].toString();
              if (_qtyCtrl.text == "0" || _qtyCtrl.text.isEmpty) {
                _qtyCtrl.text = "1"; 
              }
            });
          },
          fieldViewBuilder: (ctx, ctrl, focus, onConfirm) {
            _searchController = ctrl;
            return TextField(
              controller: ctrl,
              focusNode: focus,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar producto...", 
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8, color: Colors.transparent, 
                child: _glassContainer(
                  padding: EdgeInsets.zero,
                  borderRadius: 16,
                  child: SizedBox(
                    width: 300,
                    child: ListView.builder(
                      shrinkWrap: true, padding: EdgeInsets.zero, itemCount: options.length,
                      itemBuilder: (ctx, i) {
                        final opt = options.elementAt(i);
                        return ListTile(
                          title: Text(opt['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text("\$${opt['price']}", style: const TextStyle(color: AppTheme.accentGreen)),
                          onTap: () => onSelected(opt),
                        );
                      }
                    )
                  ),
                )
              )
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.remove, color: Colors.white54), onPressed: () => _updateQtyInput(-1)),
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add, color: Colors.white54), onPressed: () => _updateQtyInput(1)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Precio", 
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixText: "\$ ",
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _addToCart,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
                shadowColor: AppTheme.primary.withOpacity(0.5)
              ),
              child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
            )
          ],
        )
      ],
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.white10),
          SizedBox(height: 16),
          Text("El carrito está vacío", style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ));
    }
    return ListView.separated(
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        return _PosCartItemRow(
          item: _cart[i],
          onQtyChanged: (newQty) => _updateCartItemQty(i, newQty),
          onRemove: () => _removeCartItem(i),
        );
      },
    );
  }

  Widget _buildSummaryPanel(double total, String dateStr) {
    // Validadores para bloquear botón
    double remaining = total - _totalAssignedManually;
    bool isManualInvalid = !_isSplitEqually && remaining.abs() > 0.05;
    bool isBtnDisabled = _cart.isEmpty || _selectedCustomers.isEmpty || _isLoading || isManualInvalid;

    return _glassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("2. Facturación y División", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
          const SizedBox(height: 20),
          
          InkWell(
            onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!));
              if(p != null) setState(() => _selectedDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Fecha: $dateStr", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          _buildCustomerSearch(),
          
          // PANEL DE CLIENTES Y DIVISIÓN
          if (_selectedCustomers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _selectedCustomers.map((c) => Chip(
                label: Text(c['name'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: AppTheme.primary.withOpacity(0.5),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () => _removeCustomer(c['id']),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
              )).toList(),
            ),
            const SizedBox(height: 15),
            
            Expanded(child: _buildSplitSection(total)),
          ] else ...[
            const Spacer(),
          ],
          
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TOTAL VENTA", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text("\$ ${AppFormatters.money(total)}", style: const TextStyle(color: AppTheme.accentGreen, fontSize: 44, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 65,
            child: ElevatedButton.icon(
              onPressed: isBtnDisabled ? null : _showFinalizeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 10,
              ),
              icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded, size: 28),
              label: Text(_isLoading ? "PROCESANDO..." : "PROCESAR VENTA", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomerSearch() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (textValue) async {
        if (textValue.text.isEmpty) return [];
        final res = await Supabase.instance.client.from('customers').select().ilike('name', '%${textValue.text}%');
        return List<Map<String, dynamic>>.from(res);
      },
      displayStringForOption: (opt) => opt['name'],
      onSelected: (selection) {
        _addCustomer(selection);
        _customerSearchController?.clear(); 
      },
      fieldViewBuilder: (ctx, ctrl, focus, onConfirm) {
        _customerSearchController = ctrl;
        return TextField(
          controller: ctrl,
          focusNode: focus,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: _selectedCustomers.isEmpty ? "Asignar a cliente(s)" : "Añadir otro cliente...", 
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blueAccent),
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
            elevation: 8, color: Colors.transparent,
            child: _glassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: SizedBox(
                width: 300,
                child: ListView.builder(
                  shrinkWrap: true, padding: EdgeInsets.zero, itemCount: options.length,
                  itemBuilder: (ctx, i) {
                    final opt = options.elementAt(i);
                    return ListTile(title: Text(opt['name'], style: const TextStyle(color: Colors.white)), onTap: () => onSelected(opt));
                  }
                )
              ),
            )
          )
        );
      },
    );
  }

  Widget _buildSplitSection(double total) {
    double remaining = total - _totalAssignedManually;
    bool hasError = !_isSplitEqually && remaining.abs() > 0.05;
    String labelError = remaining < 0 ? "Excedente detectado:" : "Falta por asignar:";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle de División
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _isSplitEqually = true; _recalculateSplit(); }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isSplitEqually ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)
                    ),
                    alignment: Alignment.center,
                    child: Text("Equitativo", style: TextStyle(color: _isSplitEqually ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isSplitEqually = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isSplitEqually ? Colors.purpleAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)
                    ),
                    alignment: Alignment.center,
                    child: Text("Manual", style: TextStyle(color: !_isSplitEqually ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // INDICADOR DE ESTADO DE DIVISIÓN MANUAL
        if (!_isSplitEqually)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: hasError ? AppTheme.accentRed.withOpacity(0.2) : AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hasError ? AppTheme.accentRed : AppTheme.accentGreen)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hasError ? labelError : "Distribución correcta", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (hasError) Text("\$ ${remaining.abs().toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (!hasError) const Icon(Icons.check_circle, color: AppTheme.accentGreen)
              ]
            )
          ),

        Expanded(
          child: ListView.separated(
            itemCount: _selectedCustomers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final c = _selectedCustomers[i];
              final ctrl = _manualSplitCtrls[c['id']];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: Text(c['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: ctrl,
                        enabled: !_isSplitEqually,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: _isSplitEqually ? Colors.white54 : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(prefixText: "\$ ", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        onChanged: (v) => setState(() {}), // Dispara la re-validación
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  void _showFinalizeDialog() {
    final double total = _cart.fold(0.0, (s, i) => s + (i['price'] * i['qty']));
    String customerNames = _selectedCustomers.map((c) => c['name']).join(', ');
    if (customerNames.length > 30) customerNames = "${customerNames.substring(0, 27)}...";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text("Confirmar Venta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("¿Registrar venta a $customerNames por un total de \$${AppFormatters.money(total)}?", style: const TextStyle(color: Colors.white70, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final supabase = Supabase.instance.client;
                
                // 1. Crear Venta global
                final saleRes = await supabase.from('sales').insert({
                  'total_amount': total,
                  'note': _selectedCustomers.length > 1 ? 'Venta Dividida' : 'Venta POS',
                  'created_at': _selectedDate.toUtc().toIso8601String()
                }).select().single();
                
                final saleId = saleRes['id'];

                // 2. Insertar Items de la venta
                final itemsToInsert = _cart.map((i) => {
                  'sale_id': saleId,
                  'item_name': i['name'],
                  'quantity': i['qty'],
                  'unit_price': i['price'],
                  'total': i['qty'] * i['price']
                }).toList();
                await supabase.from('sale_items').insert(itemsToInsert);

                // 3. Crear Movimientos Individuales
                String baseDesc = "POS: " + _cart.map((i) => "${i['qty']}x ${i['name']} (\$${(i['qty']*i['price']).toStringAsFixed(2)})").join(", ");
                
                for (var customer in _selectedCustomers) {
                  double amountToAssign = AppFormatters.stringToDouble(_manualSplitCtrls[customer['id']]!.text);
                  if (amountToAssign <= 0) continue; 
                  
                  String finalDesc = _selectedCustomers.length > 1 ? "(Dividido) $baseDesc" : baseDesc;

                  await supabase.from('movements').insert({
                    'customer_id': customer['id'],
                    'sale_id': saleId,
                    'type': 'DEBT',
                    'amount': amountToAssign,
                    'description': finalDesc,
                    'created_at': _selectedDate.toUtc().toIso8601String()
                  });
                }

                if (mounted) {
                  setState(() {
                    _cart.clear();
                    _selectedDate = DateTime.now();
                    _customerSearchController?.clear();
                    _selectedCustomers.clear();
                    _manualSplitCtrls.clear();
                    _isSplitEqually = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Venta Registrada Exitosamente"), backgroundColor: AppTheme.accentGreen));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("CONFIRMAR VENTA", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// --- WIDGET FILA DEL PRODUCTO POS (CON TECLADO Y DISEÑO LIQUID) ---
class _PosCartItemRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int) onQtyChanged;
  final VoidCallback onRemove;

  const _PosCartItemRow({required this.item, required this.onQtyChanged, required this.onRemove});

  @override
  State<_PosCartItemRow> createState() => _PosCartItemRowState();
}

class _PosCartItemRowState extends State<_PosCartItemRow> {
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item['qty'].toString());
  }

  @override
  void didUpdateWidget(covariant _PosCartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item['qty'].toString() != _qtyCtrl.text) {
      _qtyCtrl.text = widget.item['qty'].toString();
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05))
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("\$${widget.item['price']} c/u", style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.remove, color: Colors.white54, size: 16), onPressed: () => _modifyQty(-1), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
                SizedBox(
                  width: 35,
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
                IconButton(icon: const Icon(Icons.add, color: Colors.white54, size: 16), onPressed: () => _modifyQty(1), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${AppFormatters.money(widget.item['price'] * widget.item['qty'])}", style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              InkWell(
                onTap: widget.onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.delete_sweep_rounded, color: AppTheme.accentRed, size: 20),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}