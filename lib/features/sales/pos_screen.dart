import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state_provider.dart';
import '../../config/themes.dart';
import '../../core/utils/formatters.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  // --- ESTADO DEL CARRITO ---
  final List<Map<String, dynamic>> _cartItems = [];
  
  // Controladores
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: "1");
  TextEditingController? _searchController; 
  
  String _selectedProductName = "";
  int? _selectedProductId;
  
  // --- CONFIGURACIÓN DE VENTA ---
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _selectedCustomers = [];
  bool _isSplitEqually = true; 
  final Map<String, TextEditingController> _manualSplitCtrls = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _manualSplitCtrls.forEach((key, ctrl) => ctrl.dispose());
    super.dispose();
  }

  // --- LÓGICA DEL CARRITO ---
  void _addToCart() {
    if (_selectedProductName.isEmpty || _priceCtrl.text.isEmpty) {
       _showMsg("Indique producto y precio", Colors.orange);
       return;
    }

    final price = AppFormatters.stringToDouble(_priceCtrl.text);
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (price <= 0 || qty <= 0) return;

    setState(() {
      _cartItems.add({
        'name': _selectedProductName,
        'price': price,
        'qty': qty,
        'productId': _selectedProductId 
      });
      
      _priceCtrl.clear();
      _qtyCtrl.text = "1";
      _searchController?.clear();
      _selectedProductName = "";
      _selectedProductId = null;
      _recalculateSplit(); 
    });
  }

  double get _totalCartAmount => _cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));

  double get _totalAssignedManually {
    double total = 0;
    for (var c in _selectedCustomers) {
      total += AppFormatters.stringToDouble(_manualSplitCtrls[c['id']]?.text ?? "0");
    }
    return total;
  }

  // --- LÓGICA DE CLIENTES ---
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
      final splitAmount = _totalCartAmount / _selectedCustomers.length;
      for (var customer in _selectedCustomers) {
        _manualSplitCtrls[customer['id']]?.text = splitAmount.toStringAsFixed(2);
      }
    }
  }

  void _toggleSplitMode(bool value) {
    setState(() {
      _isSplitEqually = value;
      _recalculateSplit();
    });
  }

  // --- PROCESAR VENTA (SIN DUPLICAR) ---
  Future<void> _processSale(AppStateProvider provider) async {
    if (_cartItems.isEmpty || _selectedCustomers.isEmpty) return;

    final assignedTotal = _totalAssignedManually;
    if ((assignedTotal - _totalCartAmount).abs() > 0.05) {
       _showMsg("Los montos no coinciden con el total", Colors.red);
       return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final productsDesc = _cartItems.map((e) => "${e['qty']}x ${e['name']}").join(', ');

      for (var customer in _selectedCustomers) {
        final amountToPay = AppFormatters.stringToDouble(_manualSplitCtrls[customer['id']]!.text);
        if (amountToPay <= 0) continue; 

        // 1. REGISTRAR EL MOVIMIENTO
        // IMPORTANTE: Solo insertamos el movimiento. 
        // Si tu Supabase tiene un Trigger, él actualizará el saldo automáticamente.
        await supabase.from('movements').insert({
          'customer_id': customer['id'],
          'amount': amountToPay,
          'type': 'DEBT',
          'description': "POS: $productsDesc",
          'created_at': _selectedDate.toUtc().toIso8601String(),
        });

        // 2. ACTUALIZACIÓN MANUAL DESHABILITADA
        // Se comenta esta sección para evitar que el saldo se sume dos veces si hay un Trigger en la DB.
        /*
        final userRefresh = await supabase.from('customers').select('current_balance').eq('id', customer['id']).single();
        final currentBalance = (userRefresh['current_balance'] as num?)?.toDouble() ?? 0.0;
        await supabase.from('customers').update({'current_balance': currentBalance + amountToPay}).eq('id', customer['id']);
        */
      }

      if (mounted) {
        _showMsg("Venta registrada con éxito", AppTheme.accentGreen);
        setState(() {
          _cartItems.clear();
          _selectedCustomers.clear();
          _manualSplitCtrls.forEach((key, value) => value.dispose());
          _manualSplitCtrls.clear();
          _isSplitEqually = true;
          _priceCtrl.clear();
          _searchController?.clear();
          _selectedProductName = "";
          _selectedProductId = null;
        });
      }
    } catch (e) {
      if (mounted) _showMsg("Error al guardar: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final provider = Provider.of<AppStateProvider>(context);
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    final leftPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: "1. Selección de Productos", icon: Icons.shopping_cart_checkout),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(flex: 3, child: _buildProductAutocomplete()),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Cant", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16)),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "\$", contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 16)),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addToCart, 
              icon: const Icon(Icons.add), 
              style: IconButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCartList(),
        const SizedBox(height: 24),
        _SectionHeader(title: "2. Clientes Responsables", icon: Icons.group_outlined),
        const SizedBox(height: 12),
        _CustomerAutocompleteSearch(onSelect: _addCustomer),
        const SizedBox(height: 10),
        _buildCustomerChips(),
      ],
    );

    final rightPanel = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight, 
          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)]
        ),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopActions(dateStr),
          const SizedBox(height: 20),
          const Text("División de Cuenta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          _buildSplitToggle(),
          const SizedBox(height: 15),
          Expanded(child: _buildSplitList()),
          const Divider(color: Colors.white24, height: 30),
          _buildTotals(provider),
          const SizedBox(height: 20),
          _buildSubmitButton(provider),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (isMobile) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)), child: leftPanel),
            const SizedBox(height: 20),
            SizedBox(height: 550, child: rightPanel),
            const SizedBox(height: 80),
          ]),
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24)), child: SingleChildScrollView(child: leftPanel))),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: rightPanel),
      ]);
    });
  }

  // --- COMPONENTES AUXILIARES ---

  Widget _buildCartList() {
    if (_cartItems.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("El carrito está vacío", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))));
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _cartItems.length,
        separatorBuilder: (_,__) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (ctx, i) => _CartItemTile(
          key: ValueKey(_cartItems[i]), 
          item: _cartItems[i], 
          onDelete: () => setState(() => _cartItems.removeAt(i)), 
          onQtyChanged: (n) => setState(() => _cartItems[i]['qty'] = n)
        ),
      ),
    );
  }

  Widget _buildCustomerChips() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _selectedCustomers.map((c) => Chip(
        label: Text(c['name'], style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: AppTheme.primary.withOpacity(0.1),
        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
        onDeleted: () => _removeCustomer(c['id']),
        side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      )).toList(),
    );
  }

  Widget _buildTopActions(String dateStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () async {
            final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now(), builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!));
            if(p!=null) setState(()=>_selectedDate=p);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [const Icon(Icons.calendar_today, color: Colors.white, size: 14), const SizedBox(width: 8), Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
          ),
        ),
        const Icon(Icons.history_edu, color: Colors.white70),
      ],
    );
  }

  Widget _buildSplitToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: _SplitModeButton(label: "Equitativo", isSelected: _isSplitEqually, onTap: () => _toggleSplitMode(true), activeColor: Colors.white24)),
        Expanded(child: _SplitModeButton(label: "Manual", isSelected: !_isSplitEqually, onTap: () => _toggleSplitMode(false), activeColor: Colors.white24)),
      ]),
    );
  }

  Widget _buildSplitList() {
    if (_selectedCustomers.isEmpty) return const Center(child: Text("Agregue clientes para dividir", style: TextStyle(color: Colors.white54, fontSize: 13)));
    return ListView.separated(
      itemCount: _selectedCustomers.length,
      separatorBuilder: (_,__) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final c = _selectedCustomers[i];
        final ctrl = _manualSplitCtrls[c['id']];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12), // DISEÑO AZUL CRISTAL
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15))
          ),
          child: Row(
            children: [
              Expanded(child: Text(c['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              SizedBox(width: 100, child: TextField(
                controller: ctrl, enabled: !_isSplitEqually,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                decoration: const InputDecoration(
                  prefixText: "\$ ", 
                  prefixStyle: TextStyle(color: Colors.white54, fontSize: 13),
                  border: InputBorder.none, 
                  enabledBorder: InputBorder.none, 
                  focusedBorder: InputBorder.none, 
                  contentPadding: EdgeInsets.zero
                ),
                onChanged: (_) => setState((){}),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotals(AppStateProvider provider) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("TOTAL CUENTA USD", style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text("\$ ${AppFormatters.money(_totalCartAmount)}", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("CONVERSIÓN BCV", style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text("Bs. ${AppFormatters.money(_totalCartAmount * provider.activeRate)}", style: const TextStyle(color: Colors.white, fontSize: 16)),
      ]),
    ]);
  }

  Widget _buildSubmitButton(AppStateProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _cartItems.isEmpty || _selectedCustomers.isEmpty) ? null : () => _processSale(provider),
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)) : const Icon(Icons.check_circle_outline, color: AppTheme.primary),
        label: Text(_isLoading ? "GUARDANDO..." : "REGISTRAR VENTA", style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['name'],
      optionsBuilder: (v) async {
        if (v.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
        final res = await Supabase.instance.client.from('products').select('id, name, price').ilike('name', '%${v.text}%').limit(5);
        return List<Map<String, dynamic>>.from(res);
      },
      onSelected: (s) { 
        _selectedProductName = s['name']; 
        _selectedProductId = s['id']; 
        _priceCtrl.text = s['price'].toString(); 
      },
      fieldViewBuilder: (ctx, ctrl, focus, submit) {
        _searchController = ctrl;
        ctrl.addListener(() { 
          if(ctrl.text != _selectedProductName) { 
            _selectedProductName = ctrl.text; 
            _selectedProductId = null; 
          } 
        });
        return TextField(controller: ctrl, focusNode: focus, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Buscar producto...", prefixIcon: Icon(Icons.search_rounded, size: 18)));
      },
      optionsViewBuilder: (ctx, onSelect, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, color: AppTheme.surface, borderRadius: BorderRadius.circular(12), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300), child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (ctx, i) { final opt = options.elementAt(i); return ListTile(title: Text(opt['name'], style: const TextStyle(color: Colors.white)), subtitle: Text("\$${opt['price']}", style: const TextStyle(color: AppTheme.accentGreen)), onTap: () => onSelect(opt)); })))),
    );
  }
}

class _CustomerAutocompleteSearch extends StatelessWidget {
  final Function(Map<String, dynamic>) onSelect;
  const _CustomerAutocompleteSearch({required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('customers').stream(primaryKey: ['id']).order('name'),
      builder: (ctx, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (v) => v.text.isEmpty ? snap.data! : snap.data!.where((c) => c['name'].toString().toLowerCase().contains(v.text.toLowerCase())),
          displayStringForOption: (o) => o['name'],
          onSelected: onSelect,
          fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(controller: ctrl, focusNode: focus, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Escriba para filtrar clientes...", prefixIcon: Icon(Icons.person_add_alt_1_rounded, size: 18))),
          optionsViewBuilder: (ctx, onSelect, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 4, color: AppTheme.surface, borderRadius: BorderRadius.circular(12), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300), child: ListView.builder(padding: EdgeInsets.zero, itemCount: options.length, itemBuilder: (ctx, i) { final opt = options.elementAt(i); return ListTile(leading: const CircleAvatar(backgroundColor: Colors.white10, radius: 14, child: Icon(Icons.person, size: 14, color: Colors.white)), title: Text(opt['name'], style: const TextStyle(color: Colors.white)), onTap: () => onSelect(opt)); })))),
        );
      },
    );
  }
}

class _CartItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final Function(int) onQtyChanged;
  const _CartItemTile({super.key, required this.item, required this.onDelete, required this.onQtyChanged});
  @override State<_CartItemTile> createState() => _CartItemTileState();
}
class _CartItemTileState extends State<_CartItemTile> {
  late TextEditingController _q;
  @override void initState() { super.initState(); _q = TextEditingController(text: widget.item['qty'].toString()); }
  void _up(int d) { final n = (int.tryParse(_q.text) ?? 1) + d; if (n > 0) { setState(() { _q.text = n.toString(); }); widget.onQtyChanged(n); } }
  @override Widget build(BuildContext context) {
    return ListTile(
      dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      title: Text(widget.item['name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text("\$ ${AppFormatters.money(widget.item['price'])}/u", style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.white54), onPressed: () => _up(-1)),
        Text(_q.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white54), onPressed: () => _up(1)),
        const SizedBox(width: 8),
        Text("\$${AppFormatters.money(widget.item['price'] * widget.item['qty'])}", style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppTheme.accentRed), onPressed: widget.onDelete),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override Widget build(BuildContext context) { return Row(children: [Icon(icon, color: AppTheme.primary, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]); }
}

class _SplitModeButton extends StatelessWidget {
  final String label; final bool isSelected; final VoidCallback onTap; final Color activeColor;
  const _SplitModeButton({required this.label, required this.isSelected, required this.onTap, this.activeColor = AppTheme.primary});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: isSelected ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))));
  }
}