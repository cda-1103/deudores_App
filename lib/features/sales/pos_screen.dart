import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../../data/services/sales_service.dart';
import '../../core/utils/formatters.dart'; // <--- FORMATTER

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
    // Cálculo total
    double total = _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isMobile = MediaQuery.of(context).size.width < 900;

    // --- WIDGET DEL CARRITO ---
    Widget cartSection = Card(
      margin: EdgeInsets.zero, // Quitamos márgenes externos para ganar espacio
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila de Inputs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Expanded(flex: 3, child: _buildProductAutocomplete()),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Precio", prefixText: "\$ ", isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12))
                )),
                const SizedBox(width: 8),
                SizedBox(height: 56, width: 56, child: ElevatedButton(onPressed: _addToCart, style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: const Icon(Icons.add, color: Colors.white)))
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white10),
            
            // LISTA CON EXPANDED CORRECTO
            Expanded(
              child: _cart.isEmpty 
                ? const Center(child: Text("Carrito vacío", style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    // Importante: padding inferior para que el último item no quede pegado
                    padding: const EdgeInsets.only(bottom: 20), 
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, i) => _CartItemTile(
                      key: ValueKey(_cart[i]), // Clave única
                      item: _cart[i],
                      onDelete: () => setState(() => _cart.removeAt(i)),
                      onUpdate: () => setState(() {}),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );

    // --- WIDGET DE RESUMEN ---
    Widget summarySection = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8), color: Colors.white.withOpacity(0.05)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Fecha Registro", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                    const Icon(Icons.calendar_today, color: AppTheme.primary),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 30, color: Colors.white10),
            _SummaryRow(label: "Total a Pagar", value: "\$ ${AppFormatters.money(total)}", isTotal: true),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _cart.isEmpty ? null : () => _showCheckoutDialog(total), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 20)), child: const Text("COBRAR / DIVIDIR"))),
          ],
        ),
      ),
    );

    // --- LAYOUT ---
    // Usamos LayoutBuilder para saber exactamente cuánto espacio tenemos
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          // MÓVIL: Stack o Column con Expanded para asegurar que la lista scrollee
          return Column(
            children: [
              const SizedBox(height: 10),
              // El carrito toma el espacio disponible
              Expanded(child: cartSection),
              const SizedBox(height: 10),
              // El resumen tiene altura fija abajo
              SizedBox(height: 220, child: summarySection),
              const SizedBox(height: 80), // Espacio extra para navbar
            ],
          );
        } else {
          // ESCRITORIO
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Módulo de Ventas", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
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
      },
    );
  }
  
  // ... (Resto de funciones: _pickDate, _buildProductAutocomplete, _addToCart, _showCheckoutDialog)
  // ... (Asegúrate de copiar las funciones auxiliares del archivo anterior para que compile)
  // Nota sobre _addToCart: Usa AppFormatters.stringToDouble(_priceCtrl.text)

  Future<void> _pickDate() async { final p = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (c, child) => Theme(data: AppTheme.darkTheme, child: child!)); if(p!=null) setState(()=>_selectedDate=p); }
  Widget _buildProductAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['name'],
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
        final response = await Supabase.instance.client.from('products').select('id, name, price').ilike('name', '%${textEditingValue.text}%').limit(5);
        return List<Map<String, dynamic>>.from(response);
      },
      onSelected: (selection) { _selectedProductName = selection['name']; _selectedProductId = selection['id']; _priceCtrl.text = selection['price'].toString(); },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) { _searchController = controller; return TextField(controller: controller, focusNode: focusNode, style: const TextStyle(color: Colors.white), onChanged: (val) { _selectedProductName = val; _selectedProductId = null; }, decoration: const InputDecoration(labelText: "Buscar o Libre", prefixIcon: Icon(Icons.search, color: Colors.grey), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12))); },
      optionsViewBuilder: (context, onSelected, options) { return Align(alignment: Alignment.topLeft, child: Material(elevation: 4, color: AppTheme.surface, child: SizedBox(width: 300, child: ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length, itemBuilder: (context, index) { final option = options.elementAt(index); return ListTile(title: Text(option['name'], style: const TextStyle(color: Colors.white)), subtitle: Text("\$${option['price']}", style: const TextStyle(color: AppTheme.accentGreen)), onTap: () => onSelected(option)); })))); },
    );
  }
  void _addToCart() { if (_selectedProductName.isEmpty || _priceCtrl.text.isEmpty) return; setState(() { _cart.add({ 'name': _selectedProductName, 'price': AppFormatters.stringToDouble(_priceCtrl.text), 'qty': 1, 'productId': _selectedProductId }); _priceCtrl.clear(); _searchController?.clear(); _selectedProductName = ""; _selectedProductId = null; }); }
  void _showCheckoutDialog(double totalAmount) async {
    // ... Copia la lógica del diálogo del archivo anterior ...
    // Solo recuerda usar AppFormatters.stringToDouble para leer los inputs manuales
    // Aquí te dejo el esqueleto para que compile si lo pegas:
    final customers = await Supabase.instance.client.from('customers').select().order('name');
    if(!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(content: const Text("Diálogo completo aquí (ver respuesta anterior)"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cerrar"))]));
  }
}

class _CartItemTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;
  const _CartItemTile({super.key, required this.item, required this.onDelete, required this.onUpdate});
  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}
class _CartItemTileState extends State<_CartItemTile> {
  late TextEditingController _qtyCtrl;
  @override
  void initState() { super.initState(); _qtyCtrl = TextEditingController(text: widget.item['qty'].toString()); }
  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.item['qty'] != widget.item['qty']) { final pos = _qtyCtrl.selection.base.offset; _qtyCtrl.text = widget.item['qty'].toString(); if(pos != -1) _qtyCtrl.selection = TextSelection.fromPosition(TextPosition(offset: pos)); } }
  void _updateQty(String val) { int? newQty = int.tryParse(val); if(newQty!=null && newQty>0) { widget.item['qty']=newQty; widget.onUpdate(); } }
  void _changeQtyBy(int delta) { int newVal = widget.item['qty'] + delta; if(newVal>0) { setState(() { widget.item['qty']=newVal; _qtyCtrl.text=newVal.toString(); }); widget.onUpdate(); } }
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.liquor, color: Colors.blue),
      title: Text(widget.item['name'], style: const TextStyle(color: Colors.white)),
      subtitle: Text("\$ ${AppFormatters.money(widget.item['price'])}", style: const TextStyle(color: Colors.grey)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove, color: Colors.grey), onPressed: () => _changeQtyBy(-1)),
        SizedBox(width: 40, child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(isDense: true, border: InputBorder.none), onChanged: _updateQty)),
        IconButton(icon: const Icon(Icons.add, color: Colors.grey), onPressed: () => _changeQtyBy(1)),
        const SizedBox(width: 10),
        Text("\$ ${AppFormatters.money((widget.item['price']*widget.item['qty']).toDouble())}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: widget.onDelete),
      ]),
    );
  }
}
class _SummaryRow extends StatelessWidget { final String label; final String value; final bool isTotal; const _SummaryRow({required this.label, required this.value, this.isTotal = false}); @override Widget build(BuildContext context) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(value, style: TextStyle(color: Colors.white, fontSize: isTotal?20:14, fontWeight: FontWeight.bold))]); } }