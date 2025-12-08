import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/app_state_provider.dart';
import '../../config/themes.dart';
import 'customer_detail_screen.dart'; // Importamos la nueva pantalla

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  // Controlador para el buscador
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HEADER ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Gestión de Clientes",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Agregar Cliente",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // --- BARRA DE BÚSQUEDA ---
        TextField(
          controller: _searchCtrl,
          // Actualizamos el estado cuando el texto cambia
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Buscar cliente por nombre...",
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            // Botón para limpiar búsqueda
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --- LISTA DE CLIENTES ---
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('customers').stream(
                primaryKey: ['id']).order('current_balance', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text("Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final customers = snapshot.data!;

              // FILTRADO EN TIEMPO REAL
              final filteredCustomers = customers.where((c) {
                final name = c['name'].toString().toLowerCase();
                final phone = c['phone']?.toString().toLowerCase() ?? '';
                return name.contains(_searchQuery) ||
                    phone.contains(_searchQuery);
              }).toList();

              if (filteredCustomers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 60, color: Colors.grey.shade700),
                      const SizedBox(height: 10),
                      Text(
                        _searchQuery.isEmpty
                            ? "No hay clientes registrados"
                            : "No se encontraron resultados para '$_searchQuery'",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Card(
                color: AppTheme.surface,
                child: ListView.separated(
                  itemCount: filteredCustomers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final customer = filteredCustomers[index];
                    final balance =
                        (customer['current_balance'] as num).toDouble();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.background,
                        child: Text(
                          (customer['name'] as String).isNotEmpty
                              ? customer['name'][0].toUpperCase()
                              : "?",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(customer['name'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          customer['phone'] != null &&
                                  customer['phone'].toString().isNotEmpty
                              ? customer['phone']
                              : 'Sin teléfono',
                          style: const TextStyle(color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "\$${balance.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: balance > 0
                                      ? AppTheme.accentRed
                                      : AppTheme.accentGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Consumer<AppStateProvider>(
                                builder: (_, provider, __) => Text(
                                  provider.toBs(balance),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                      onTap: () {
                        // NAVEGACIÓN AL PERFIL
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(
                              customerId: customer['id'],
                              customerName: customer['name'],
                              initialBalance: balance,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
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
              backgroundColor: AppTheme.surface,
              title: const Text("Nuevo Cliente",
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Nombre Completo *",
                      prefixIcon: Icon(Icons.person, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Teléfono (Opcional)",
                      prefixIcon: Icon(Icons.phone, color: Colors.grey),
                      hintText: "Ej: 0414...",
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setState(() => isLoading = true);
                          try {
                            await Supabase.instance.client
                                .from('customers')
                                .insert({
                              'name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'current_balance': 0,
                            });
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Cliente '${nameCtrl.text}' creado con éxito"),
                                  backgroundColor: AppTheme.accentGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          } finally {
                            if (context.mounted)
                              setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
