import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec
import '../../config/themes.dart';
import '../auth/login_screen.dart'; // Importante para redirigir al crear usuario

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;
  // 0: Pagos, 1: Productos, 2: Usuarios, 3: Auditoría

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Configuración",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MENÚ LATERAL
              Expanded(
                flex: 1,
                child: Card(
                  color: AppTheme.surface,
                  child: ListView(
                    children: [
                      _SettingsMenuTile(
                        icon: Icons.payment,
                        label: "Formas de Pago",
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      _SettingsMenuTile(
                        icon: Icons.inventory_2,
                        label: "Productos",
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                      const Divider(color: Colors.white24),
                      _SettingsMenuTile(
                        icon: Icons.people_alt,
                        label: "Usuarios",
                        isSelected: _selectedTab == 2,
                        onTap: () => setState(() => _selectedTab = 2),
                      ),
                      _SettingsMenuTile(
                        icon: Icons.history_edu, // Icono de auditoría
                        label: "Auditoría / Log",
                        isSelected: _selectedTab == 3,
                        onTap: () => setState(() => _selectedTab = 3),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // CONTENIDO DINÁMICO
              Expanded(
                flex: 3, // Damos más espacio al contenido
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return const _PaymentMethodsManager();
      case 1:
        return const _ProductsManager();
      case 2:
        return const _UsersManager(); // Nuevo
      case 3:
        return const _AuditLogViewer(); // Nuevo
      default:
        return const Center(child: Text("Seleccione una opción"));
    }
  }
}

class _SettingsMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsMenuTile(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primary : Colors.grey),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: Colors.white10,
      onTap: onTap,
    );
  }
}

// --- GESTOR DE USUARIOS (NUEVO) ---
class _UsersManager extends StatefulWidget {
  const _UsersManager();
  @override
  State<_UsersManager> createState() => _UsersManagerState();
}

class _UsersManagerState extends State<_UsersManager> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _createUser() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Email inválido o contraseña corta (min 6)")));
      return;
    }

    // Advertencia de seguridad
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text("⚠ Atención",
                      style: TextStyle(color: Colors.orange)),
                  content: const Text(
                      "Al crear un nuevo usuario, el sistema cerrará tu sesión actual automáticamente por seguridad.\n\n"
                      "Deberás volver a ingresar con tus credenciales.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Entendido, Crear"))
                  ],
                )) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      // 1. Crear usuario en Auth (Esto loguea al nuevo usuario)
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // 2. Registrar Auditoría (Intentamos antes de que cierre, aunque puede fallar por cambio de sesión)
      try {
        await Supabase.instance.client.from('action_logs').insert({
          'user_email': 'Sistema',
          'action': 'Crear Usuario',
          'details': 'Se creó el usuario ${_emailCtrl.text}'
        });
      } catch (_) {}

      if (mounted) {
        // Redirigir al Login
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario creado exitosamente.")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Gestión de Usuarios",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Registra nuevos empleados para que accedan al sistema.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // FORMULARIO CREACIÓN
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Crear Nuevo Acceso",
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon:
                                  Icon(Icons.email, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          style: const TextStyle(color: Colors.white),
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: Icon(Icons.lock, color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createUser,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            padding: const EdgeInsets.all(16)),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Registrar"),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Usuarios Existentes",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white10),

            // LISTA DE USUARIOS (Desde la tabla profiles)
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('profiles')
                    .stream(primaryKey: ['id']).order('created_at'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final users = snapshot.data!;
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (ctx, i) => ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, color: Colors.white)),
                      title: Text(users[i]['email'] ?? 'Sin email',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text("Rol: ${users[i]['role']}",
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- VISOR DE LOGS (NUEVO) ---
class _AuditLogViewer extends StatelessWidget {
  const _AuditLogViewer();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Log de Auditoría Interna",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {/* El Stream se actualiza solo */},
                )
              ],
            ),
            const SizedBox(height: 10),
            const Text("Registro cronológico de acciones en el sistema.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),

            // TABLA DE LOGS
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client
                    .from('action_logs')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false)
                    .limit(50),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final logs = snapshot.data!;

                  if (logs.isEmpty)
                    return const Center(
                        child: Text("Sin registros de auditoría",
                            style: TextStyle(color: Colors.grey)));

                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (ctx, i) {
                      final log = logs[i];
                      final date = DateTime.parse(log['created_at']).toLocal();
                      final dateStr = DateFormat('dd/MM HH:mm').format(date);

                      return ListTile(
                        leading:
                            const Icon(Icons.history, color: Colors.blueGrey),
                        title: Text(log['action'] ?? 'Acción',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "${log['user_email'] ?? 'Anónimo'} • $dateStr",
                            style: const TextStyle(color: Colors.grey)),
                        trailing: SizedBox(
                          width: 200,
                          child: Text(
                            log['details'] ?? '',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}

// --- GESTOR DE FORMAS DE PAGO (Versión anterior) ---
class _PaymentMethodsManager extends StatefulWidget {
  const _PaymentMethodsManager();
  @override
  State<_PaymentMethodsManager> createState() => _PaymentMethodsManagerState();
}

class _PaymentMethodsManagerState extends State<_PaymentMethodsManager> {
  final _supabase = Supabase.instance.client;
  final _methodCtrl = TextEditingController();
  List<Map<String, dynamic>> _methods = [];

  @override
  void initState() {
    super.initState();
    _fetchMethods();
  }

  Future<void> _fetchMethods() async {
    final response =
        await _supabase.from('payment_methods').select().order('created_at');
    if (mounted)
      setState(() {
        _methods = List<Map<String, dynamic>>.from(response);
      });
  }

  Future<void> _addMethod() async {
    if (_methodCtrl.text.trim().isEmpty) return;
    await _supabase
        .from('payment_methods')
        .insert({'name': _methodCtrl.text.trim()});
    _methodCtrl.clear();
    _fetchMethods();
  }

  Future<void> _deleteMethod(int id) async {
    await _supabase.from('payment_methods').delete().eq('id', id);
    _fetchMethods();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        color: AppTheme.surface,
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _methodCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: "Nuevo Método"))),
                IconButton(
                    icon: const Icon(Icons.add, color: Colors.green),
                    onPressed: _addMethod)
              ]),
              const Divider(color: Colors.white10),
              Expanded(
                  child: ListView.builder(
                      itemCount: _methods.length,
                      itemBuilder: (ctx, i) => ListTile(
                          title: Text(_methods[i]['name'],
                              style: const TextStyle(color: Colors.white)),
                          trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  _deleteMethod(_methods[i]['id'])))))
            ])));
  }
}

// --- GESTOR DE PRODUCTOS (Versión anterior mejorada) ---
class _ProductsManager extends StatefulWidget {
  const _ProductsManager();
  @override
  State<_ProductsManager> createState() => _ProductsManagerState();
}

class _ProductsManagerState extends State<_ProductsManager> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final response = await _supabase.from('products').select().order('name');
    if (mounted)
      setState(() {
        _allProducts = List<Map<String, dynamic>>.from(response);
        _filterProducts();
      });
  }

  void _filterProducts() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = query.isEmpty
          ? List.from(_allProducts)
          : _allProducts
              .where((p) => p['name'].toString().toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _saveProduct() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    if (_editingId == null) {
      await _supabase
          .from('products')
          .insert({'name': _nameCtrl.text, 'price': price});
    } else {
      await _supabase.from('products').update(
          {'name': _nameCtrl.text, 'price': price}).eq('id', _editingId!);
      setState(() => _editingId = null);
    }
    _nameCtrl.clear();
    _priceCtrl.clear();
    _fetchProducts();
  }

  void _startEditing(Map<String, dynamic> product) {
    setState(() {
      _editingId = product['id'];
      _nameCtrl.text = product['name'];
      _priceCtrl.text = product['price'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        color: AppTheme.surface,
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                Expanded(
                    flex: 3,
                    child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: "Producto"))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 1,
                    child: TextField(
                        controller: _priceCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: "Precio"))),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _saveProduct,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _editingId != null
                            ? Colors.blue
                            : AppTheme.accentGreen),
                    child: Icon(_editingId != null ? Icons.save : Icons.add,
                        color: Colors.white))
              ]),
              const SizedBox(height: 20),
              TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => _filterProducts(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      hintText: "Buscar...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey))),
              const Divider(color: Colors.white10),
              Expanded(
                  child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (ctx, i) {
                        final p = _filteredProducts[i];
                        return ListTile(
                          title: Text(p['name'],
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text("\$${p['price']}",
                              style: const TextStyle(color: Colors.green)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _startEditing(p)),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await _supabase
                                      .from('products')
                                      .delete()
                                      .eq('id', p['id']);
                                  _fetchProducts();
                                }),
                          ]),
                        );
                      }))
            ])));
  }
}
