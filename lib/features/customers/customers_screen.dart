import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/app_state_provider.dart';
import '../../config/themes.dart';
import 'customer_detail_screen.dart';
import '../../core/utils/formatters.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";
  String _sortBy = 'ALL'; // ALL, DEBTORS, DESC, ASC, ALPHA

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
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
    final supabase = Supabase.instance.client;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Directorio de Clientes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCustomerDialog(context), 
                    icon: const Icon(Icons.add), 
                    label: const Text("Nuevo Cliente"),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                  )
                ]
              ),
            ),
          
          // BUSCADOR Y FILTROS LIQUID GLASS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _glassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ""); }) 
                        : null
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterBadge(label: "Todos", isSelected: _sortBy == 'ALL', onTap: () => setState(() => _sortBy = 'ALL')),
                        _FilterBadge(label: "Solo Deudores", isSelected: _sortBy == 'DEBTORS', onTap: () => setState(() => _sortBy = 'DEBTORS'), activeColor: Colors.orangeAccent),
                        _FilterBadge(label: "Mayor a Menor", isSelected: _sortBy == 'DESC', onTap: () => setState(() => _sortBy = 'DESC')),
                        _FilterBadge(label: "Menor a Mayor", isSelected: _sortBy == 'ASC', onTap: () => setState(() => _sortBy = 'ASC')),
                        _FilterBadge(label: "A - Z", isSelected: _sortBy == 'ALPHA', onTap: () => setState(() => _sortBy = 'ALPHA')),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // LISTA DE CLIENTES
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('customers').stream(primaryKey: ['id']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                // 1. Filtrado por Búsqueda
                var filtered = snapshot.data!.where((c) => c['name'].toString().toLowerCase().contains(_searchQuery)).toList();

                // 2. Lógica de Filtros y Ordenamiento
                if (_sortBy == 'DEBTORS') {
                  filtered = filtered.where((c) => (c['current_balance'] as num).toDouble() > 0.05).toList();
                  filtered.sort((a, b) => (b['current_balance'] as num).compareTo(a['current_balance'] as num));
                } else if (_sortBy == 'DESC') {
                  filtered.sort((a, b) => (b['current_balance'] as num).compareTo(a['current_balance'] as num));
                } else if (_sortBy == 'ASC') {
                  filtered.sort((a, b) => (a['current_balance'] as num).compareTo(b['current_balance'] as num));
                } else if (_sortBy == 'ALPHA') {
                  filtered.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text("No se encontraron clientes.", style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final customer = filtered[i];
                    final balance = (customer['current_balance'] as num).toDouble();
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer['id'], customerName: customer['name'], initialBalance: balance))),
                        child: _glassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.primary.withOpacity(0.5), 
                                child: Text(customer['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(customer['phone'] ?? 'Sin contacto', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("\$ ${AppFormatters.money(balance)}", style: TextStyle(color: balance > 0 ? AppTheme.accentRed : AppTheme.accentGreen, fontWeight: FontWeight.w900, fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Consumer<AppStateProvider>(builder: (_, p, __) => Text("Bs. ${AppFormatters.money(balance * p.activeRate)}", style: const TextStyle(fontSize: 11, color: Colors.white38))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text("Nuevo Cliente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Nombre", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), textCapitalization: TextCapitalization.words), 
            const SizedBox(height: 16), 
            TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Teléfono", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), keyboardType: TextInputType.phone)
          ]
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async { 
              if (nameCtrl.text.isEmpty) return; 
              await Supabase.instance.client.from('customers').insert({'name': nameCtrl.text, 'phone': phoneCtrl.text, 'current_balance': 0}); 
              if (mounted) Navigator.pop(ctx); 
            }, 
            child: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }
}

class _FilterBadge extends StatelessWidget {
  final String label; 
  final bool isSelected; 
  final VoidCallback onTap;
  final Color activeColor;

  const _FilterBadge({required this.label, required this.isSelected, required this.onTap, this.activeColor = Colors.blueAccent});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.white54)), 
        selected: isSelected, 
        onSelected: (_) => onTap(), 
        selectedColor: activeColor.withOpacity(0.4), 
        backgroundColor: Colors.black26, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? activeColor : Colors.transparent)),
        showCheckmark: false,
      ),
    );
  }
}