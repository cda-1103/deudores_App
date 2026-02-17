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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  Future<void> _deleteCustomer(String customerId, String customerName) async {
    final passwordCtrl = TextEditingController();

    bool? authorized = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Eliminación", style: TextStyle(color: AppTheme.accentRed)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Se eliminará a '$customerName' y todo su historial.", style: const TextStyle(color: AppTheme.secondary)),
            const SizedBox(height: 20),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Contraseña Supervisor",
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () {
              if (passwordCtrl.text == '102030') Navigator.pop(ctx, true);
              else ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Contraseña incorrecta"), backgroundColor: Colors.red));
            },
            child: const Text("ELIMINAR"),
          )
        ],
      ),
    );

    if (authorized == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('movements').delete().eq('customer_id', customerId);
        await supabase.from('customers').delete().eq('id', customerId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cliente eliminado")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.transparent, // Hereda del padre
      // FAB SOLO EN MÓVIL
      floatingActionButton: isMobile 
        ? FloatingActionButton(
            onPressed: () => _showAddCustomerDialog(context),
            backgroundColor: AppTheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
        
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER (Solo Desktop - En móvil va en AppBar o se omite)
          if (!isMobile)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gestión de Clientes", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ElevatedButton.icon(
                  onPressed: () => _showAddCustomerDialog(context),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Nuevo Cliente"),
                ),
              ],
            ),
          
          if (!isMobile) const SizedBox(height: 20),

          // BUSCADOR
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Buscar por nombre o teléfono...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ""); })
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // LISTA DE CLIENTES
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('customers').stream(primaryKey: ['id']).order('current_balance', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final customers = snapshot.data!;
                final filtered = customers.where((c) {
                  final name = c['name'].toString().toLowerCase();
                  final phone = c['phone']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(_searchQuery.isEmpty ? "No hay clientes aún" : "Sin resultados", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      final balance = (customer['current_balance'] as num).toDouble();
                      final canDelete = balance.abs() < 0.01;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.background,
                          foregroundColor: AppTheme.primary,
                          child: Text((customer['name'] as String).isNotEmpty ? customer['name'][0].toUpperCase() : "?", 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(customer['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            (customer['phone'] != null && customer['phone'].toString().isNotEmpty) ? customer['phone'] : 'Sin contacto',
                            style: const TextStyle(color: AppTheme.secondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("\$ ${AppFormatters.money(balance)}",
                                  style: TextStyle(
                                      color: balance > 0 ? AppTheme.accentRed : AppTheme.accentGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                                Consumer<AppStateProvider>(builder: (_, provider, __) {
                                  return Text("Bs. ${AppFormatters.money(balance * provider.activeRate)}",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey));
                                }),
                              ],
                            ),
                            const SizedBox(width: 10),
                            if (canDelete)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                onPressed: () => _deleteCustomer(customer['id'], customer['name']),
                              )
                            else 
                              const SizedBox(width: 40), // Espacio para alinear
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(
                                  customerId: customer['id'],
                                  customerName: customer['name'],
                                  initialBalance: balance)));
                        },
                      );
                    },
                  ),
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
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Nuevo Cliente"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Nombre Completo", prefixIcon: Icon(Icons.person)),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Teléfono", prefixIcon: Icon(Icons.phone)),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      await Supabase.instance.client.from('customers').insert({
                        'name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'current_balance': 0
                      });
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cliente guardado")));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("GUARDAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}