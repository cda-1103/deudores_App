import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/themes.dart';
import '../../core/utils/migration_service.dart';
import '../../core/utils/formatters.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isWorking = false;
  final SupabaseClient _supabase = Supabase.instance.client;
  String _productSearch = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),

            _buildSectionHeader("Catálogo y Maestros"),
            _buildSettingsCard(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.orangeAccent),
                    ),
                    title: const Text("Gestión de Inventario", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Productos y precios"),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _showProductManager,
                  ),
                  const Divider(color: Colors.white10, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.credit_card_rounded, color: Colors.blueAccent),
                    ),
                    title: const Text("Métodos de Pago", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Bancos, Zelle, Efectivo"),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _showPaymentMethodManager,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader("Sistema de Datos"),
            _buildSettingsCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_rounded, color: Colors.green),
                    title: const Text("Importar Excel", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Carga masiva de datos"),
                    onTap: _isWorking ? null : _handleSimpleImport,
                  ),
                  const Divider(color: Colors.white10, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentRed),
                    title: const Text("Reiniciar Base de Datos", style: TextStyle(color: AppTheme.accentRed)),
                    subtitle: const Text("Borrar todo y cargar de cero"),
                    trailing: _isWorking ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    onTap: _isWorking ? null : _handleResetAndImport,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // --- GESTOR DE PRODUCTOS (SOLUCIONADO OVERFLOW) ---
  void _showProductManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite altura dinámica
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        // Padding para evitar el teclado
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.85, // 85% de la pantalla
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Cabecera
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Inventario", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton.filled(
                      onPressed: () => _editProductDialog(null), 
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Buscador
                TextField(
                  onChanged: (v) => setModalState(() => _productSearch = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Buscar producto...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Lista con Expanded para evitar Overflow
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase.from('products').stream(primaryKey: ['id']).order('name'),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final products = snap.data!
                          .where((p) => p['name'].toString().toLowerCase().contains(_productSearch))
                          .toList();

                      if (products.isEmpty) return const Center(child: Text("Sin resultados", style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (c, i) {
                          final p = products[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05), 
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.05))
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.black26,
                                child: Icon(Icons.liquor, color: Colors.orangeAccent, size: 20),
                              ),
                              title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("\$${AppFormatters.money(p['price'])}", style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 10),
                                  IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _editProductDialog(p)),
                                  IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), onPressed: () => _confirmDelete('products', p['id'])),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editProductDialog(Map<String, dynamic>? p) {
    final nameCtrl = TextEditingController(text: p?['name']);
    final priceCtrl = TextEditingController(text: p?['price']?.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(p == null ? "Nuevo Producto" : "Editar Producto", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl, 
              style: const TextStyle(color: Colors.white), 
              decoration: const InputDecoration(labelText: "Nombre", labelStyle: TextStyle(color: Colors.grey))
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              style: const TextStyle(color: Colors.white), 
              decoration: const InputDecoration(labelText: "Precio (\$)", prefixIcon: Icon(Icons.attach_money, color: Colors.green))
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
             if (nameCtrl.text.isEmpty) return;
             final data = {'name': nameCtrl.text.trim(), 'price': AppFormatters.stringToDouble(priceCtrl.text)};
             if (p == null) await _supabase.from('products').insert(data);
             else await _supabase.from('products').update(data).eq('id', p['id']);
             Navigator.pop(ctx);
          }, child: const Text("GUARDAR"))
        ],
      ),
    );
  }

  // --- GESTOR DE MÉTODOS DE PAGO (SOLUCIONADO OVERFLOW) ---
  void _showPaymentMethodManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true, // Clave para evitar overflow
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7, // Altura cómoda
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Métodos de Pago", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton.filled(
                    onPressed: () => _addMethodDialog(), 
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                  )
                ],
              ),
              const SizedBox(height: 5),
              const Text("Opciones disponibles para abonos", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              // Lista con Expanded
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase.from('payment_methods').stream(primaryKey: ['id']).order('name'),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final methods = snap.data!;
                    
                    if (methods.isEmpty) return const Center(child: Text("Sin métodos configurados", style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      itemCount: methods.length,
                      itemBuilder: (c, i) {
                        final m = methods[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 20),
                            ),
                            title: Text(m['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                              onPressed: () => _confirmDelete('payment_methods', m['id'])
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _addMethodDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nuevo Método", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl, 
          style: const TextStyle(color: Colors.white), 
          decoration: const InputDecoration(labelText: "Nombre (ej: Pago Móvil)", hintStyle: TextStyle(color: Colors.grey))
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
            if (nameCtrl.text.isNotEmpty) await _supabase.from('payment_methods').insert({'name': nameCtrl.text.trim()});
            Navigator.pop(ctx);
          }, child: const Text("AGREGAR"))
        ],
      ),
    );
  }

  void _confirmDelete(String table, String id) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("¿Eliminar registro?", style: TextStyle(color: Colors.white)), 
        content: const Text("Esta acción no se puede deshacer.", style: TextStyle(color: Colors.grey)), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed), 
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("ELIMINAR")
          )
        ]
      )
    );
    if (ok == true) await _supabase.from(table).delete().eq('id', id);
  }

  Future<void> _handleResetAndImport() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: AppTheme.surface, title: const Text("⚠️ ATENCIÓN", style: TextStyle(color: Colors.orange)), content: const Text("Se borrarán todos los datos actuales para cargar el Excel limpio.", style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed), onPressed: () => Navigator.pop(ctx, true), child: const Text("BORRAR Y CARGAR"))]));
    if (confirm != true) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null || result.files.first.bytes == null) return;
    setState(() => _isWorking = true);
    await MigrationService().resetAndMigrate(result.files.first.bytes!);
    setState(() => _isWorking = false);
  }

  Future<void> _handleSimpleImport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null || result.files.first.bytes == null) return;
    setState(() => _isWorking = true);
    await MigrationService().migrateExcel(result.files.first.bytes!);
    setState(() => _isWorking = false);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(left: 8, bottom: 12), child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)));
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))), child: child);
  }

  Widget _buildLogoutButton() {
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed.withOpacity(0.1), foregroundColor: AppTheme.accentRed, elevation: 0), onPressed: () async { await _supabase.auth.signOut(); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); }, icon: const Icon(Icons.logout), label: const Text("CERRAR SESIÓN")));
  }
}