import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/themes.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Configuración",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 20),
        if (isMobile)
          Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _MobileTab(
                    icon: Icons.payment,
                    label: "Pagos",
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0)),
                _MobileTab(
                    icon: Icons.inventory_2,
                    label: "Productos",
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1)),
                _MobileTab(
                    icon: Icons.people_alt,
                    label: "Usuarios",
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2)),
                _MobileTab(
                    icon: Icons.history_edu,
                    label: "Auditoría",
                    isSelected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3)),
              ]))
        else
          Expanded(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                flex: 1,
                child: Card(
                    color: AppTheme.surface,
                    child: ListView(children: [
                      _SettingsMenuTile(
                          icon: Icons.payment,
                          label: "Formas de Pago",
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0)),
                      _SettingsMenuTile(
                          icon: Icons.inventory_2,
                          label: "Productos",
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1)),
                      const Divider(color: Colors.white24),
                      _SettingsMenuTile(
                          icon: Icons.people_alt,
                          label: "Usuarios y Permisos",
                          isSelected: _selectedTab == 2,
                          onTap: () => setState(() => _selectedTab = 2)),
                      _SettingsMenuTile(
                          icon: Icons.history_edu,
                          label: "Auditoría",
                          isSelected: _selectedTab == 3,
                          onTap: () => setState(() => _selectedTab = 3)),
                    ]))),
            const SizedBox(width: 20),
            Expanded(flex: 3, child: _buildContent()),
          ])),
        if (isMobile) Expanded(child: _buildContent()),
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
        return const _UsersManager();
      case 3:
        return const _AuditLogViewer();
      default:
        return const Center(child: Text("Seleccione opción"));
    }
  }
}

class _MobileTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _MobileTab(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white24)),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))
            ])));
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
        onTap: onTap);
  }
}

// --- 1. GESTOR DE FORMAS DE PAGO (Con Edición) ---
class _PaymentMethodsManager extends StatefulWidget {
  const _PaymentMethodsManager();
  @override
  State<_PaymentMethodsManager> createState() => _PaymentMethodsManagerState();
}

class _PaymentMethodsManagerState extends State<_PaymentMethodsManager> {
  final _supabase = Supabase.instance.client;
  final _methodCtrl = TextEditingController();
  List<Map<String, dynamic>> _methods = [];
  bool _isLoading = true;

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
        _isLoading = false;
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
    try {
      await _supabase.from('payment_methods').delete().eq('id', id);
      _fetchMethods();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se puede eliminar (en uso)")));
    }
  }

  // --- NUEVA FUNCIÓN: EDITAR MÉTODO ---
  Future<void> _editMethod(Map<String, dynamic> method) async {
    final editCtrl = TextEditingController(text: method['name']);
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text("Editar Método",
                  style: TextStyle(color: Colors.white)),
              content: TextField(
                  controller: editCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Nombre")),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")),
                ElevatedButton(
                    onPressed: () async {
                      await _supabase
                          .from('payment_methods')
                          .update({'name': editCtrl.text.trim()}).eq(
                              'id', method['id']);
                      _fetchMethods(); // Recargar lista
                      Navigator.pop(ctx);
                    },
                    child: const Text("Guardar"))
              ],
            ));
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _methods.length,
                          itemBuilder: (ctx, i) {
                            final m = _methods[i];
                            return ListTile(
                                title: Text(m['name'],
                                    style:
                                        const TextStyle(color: Colors.white)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _editMethod(m)), // Botón Editar
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteMethod(m['id'])),
                                  ],
                                ));
                          }))
            ])));
  }
}

// --- 2. GESTOR DE PRODUCTOS (Sin cambios) ---
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

  Future<void> _deleteProduct(int id) async {
    await _supabase.from('products').delete().eq('id', id);
    _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
        color: AppTheme.surface,
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (isMobile) ...[
                TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Producto")),
                const SizedBox(height: 10),
                TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Precio")),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _saveProduct,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _editingId != null
                                ? Colors.blue
                                : AppTheme.accentGreen),
                        child: Icon(_editingId != null ? Icons.save : Icons.add,
                            color: Colors.white)))
              ] else
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
                          keyboardType: TextInputType.number,
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
                                onPressed: () => _deleteProduct(p['id'])),
                          ]),
                        );
                      }))
            ])));
  }
}

// --- 3. GESTOR DE USUARIOS (Con recarga manual segura) ---
class _UsersManager extends StatefulWidget {
  const _UsersManager();
  @override
  State<_UsersManager> createState() => _UsersManagerState();
}

class _UsersManagerState extends State<_UsersManager> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _canDeleteClients = false;
  bool _canDeleteSales = false;
  bool _canChangeRate = false;
  bool _canManageUsers = false; // NUEVO PERMISO

  bool _isLoading = false;
  List<Map<String, dynamic>> _users =
      []; // Lista local para refresco instantáneo

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Carga manual para garantizar que veamos los cambios
  Future<void> _fetchUsers() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .order('created_at');
    if (mounted)
      setState(() => _users = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _createUser() async {
    if (_emailCtrl.text.isEmpty ||
        _passCtrl.text.length < 6 ||
        _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Complete todos los campos. Pass min 6 chars.")));
      return;
    }

    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text("⚠ Crear Usuario",
                      style: TextStyle(color: Colors.orange)),
                  content: const Text(
                      "Se creará el usuario y se cerrará tu sesión actual.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar")),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Crear"))
                  ],
                )) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          data: {
            'full_name': _nameCtrl.text.trim(),
            'can_delete_clients': _canDeleteClients,
            'can_delete_sales': _canDeleteSales,
            'can_change_rate': _canChangeRate,
            'can_manage_users': _canManageUsers, // NUEVO
          });

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario creado con permisos.")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text("Eliminar Usuario",
                        style: TextStyle(color: Colors.red)),
                    content: const Text("Se eliminará de la lista.",
                        style: TextStyle(color: Colors.grey)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar")),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Eliminar"))
                    ])) ??
        false;
    if (confirm) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', userId);
        _fetchUsers(); // Recargar lista
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Eliminado")));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- EDICIÓN DE USUARIO CORREGIDA ---
  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameEdit = TextEditingController(text: user['full_name']);
    bool edDelCli = user['can_delete_clients'] ?? false;
    bool edDelSal = user['can_delete_sales'] ?? false;
    bool edChgRate = user['can_change_rate'] ?? false;
    bool edManageUsers = user['can_manage_users'] ?? false; // NUEVO

    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setState) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text("Editar Permisos",
                      style: TextStyle(color: Colors.white)),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: nameEdit,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Nombre")),
                    SwitchListTile(
                        title: const Text("Eliminar Clientes",
                            style: TextStyle(color: Colors.white)),
                        value: edDelCli,
                        onChanged: (v) => setState(() => edDelCli = v)),
                    SwitchListTile(
                        title: const Text("Eliminar Ventas",
                            style: TextStyle(color: Colors.white)),
                        value: edDelSal,
                        onChanged: (v) => setState(() => edDelSal = v)),
                    SwitchListTile(
                        title: const Text("Cambiar Tasa",
                            style: TextStyle(color: Colors.white)),
                        value: edChgRate,
                        onChanged: (v) => setState(() => edChgRate = v)),
                    SwitchListTile(
                        title: const Text("Gestionar Usuarios",
                            style: TextStyle(color: Colors.white)),
                        value: edManageUsers,
                        onChanged: (v) => setState(() => edManageUsers = v)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancelar")),
                    ElevatedButton(
                        onPressed: () async {
                          await Supabase.instance.client
                              .from('profiles')
                              .update({
                            'full_name': nameEdit.text,
                            'can_delete_clients': edDelCli,
                            'can_delete_sales': edDelSal,
                            'can_change_rate': edChgRate,
                            'can_manage_users': edManageUsers,
                          }).eq('id', user['id']);

                          _fetchUsers(); // IMPORTANTE: Recargar la lista después de guardar
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Usuario actualizado")));
                        },
                        child: const Text("Guardar"))
                  ],
                )));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Crear Nuevo Empleado",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Nombre Completo",
                      prefixIcon: Icon(Icons.badge, color: Colors.grey))),
              const SizedBox(height: 10),
              TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email, color: Colors.grey))),
              const SizedBox(height: 10),
              TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: Icon(Icons.lock, color: Colors.grey))),
              const SizedBox(height: 20),
              const Text("Permisos:",
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.bold)),
              SwitchListTile(
                  title: const Text("Eliminar Clientes",
                      style: TextStyle(color: Colors.white)),
                  value: _canDeleteClients,
                  activeColor: AppTheme.accentRed,
                  onChanged: (val) => setState(() => _canDeleteClients = val)),
              SwitchListTile(
                  title: const Text("Eliminar Ventas/Abonos",
                      style: TextStyle(color: Colors.white)),
                  value: _canDeleteSales,
                  activeColor: AppTheme.accentRed,
                  onChanged: (val) => setState(() => _canDeleteSales = val)),
              SwitchListTile(
                  title: const Text("Cambiar Tasa BCV/Manual",
                      style: TextStyle(color: Colors.white)),
                  value: _canChangeRate,
                  activeColor: AppTheme.primary,
                  onChanged: (val) => setState(() => _canChangeRate = val)),
              SwitchListTile(
                  title: const Text("Gestionar Usuarios",
                      style: TextStyle(color: Colors.white)),
                  value: _canManageUsers,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (val) => setState(() => _canManageUsers = val)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _isLoading ? null : _createUser,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          padding: const EdgeInsets.all(16)),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Registrar Empleado"))),
              const SizedBox(height: 30),
              const Text("Lista de Empleados",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white10),
              SizedBox(
                height: 400,
                // Usamos la lista local _users en lugar de StreamBuilder para mayor control
                child: ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    final List<String> perms = [];
                    if (u['can_delete_clients'] == true)
                      perms.add("Borrar Clientes");
                    if (u['can_delete_sales'] == true)
                      perms.add("Borrar Ventas");
                    if (u['can_change_rate'] == true) perms.add("Cambiar Tasa");
                    if (u['can_manage_users'] == true)
                      perms.add("Gestionar Usuarios");
                    return ListTile(
                      leading: CircleAvatar(
                          child: Text(u['full_name'] != null &&
                                  u['full_name'].isNotEmpty
                              ? u['full_name'][0]
                              : 'U')),
                      title: Text(u['full_name'] ?? 'Sin nombre',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          "${u['email']}\nPermisos: ${perms.isEmpty ? 'Ninguno' : perms.join(', ')}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: "Editar Permisos",
                              onPressed: () => _editUser(u)),
                          IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppTheme.accentRed),
                              tooltip: "Eliminar Usuario",
                              onPressed: () => _deleteUser(u['id'])),
                        ],
                      ),
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
}

// --- 4. VISOR DE LOGS ---
class _AuditLogViewer extends StatelessWidget {
  const _AuditLogViewer();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Auditoría",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold))
                ]),
            const Divider(color: Colors.white10),
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
                        child: Text("Sin registros",
                            style: TextStyle(color: Colors.grey)));
                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10),
                    itemBuilder: (ctx, i) {
                      final log = logs[i];
                      final date = DateTime.parse(log['created_at']).toLocal();
                      return ListTile(
                        leading:
                            const Icon(Icons.history, color: Colors.blueGrey),
                        title: Text(log['action'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "${log['user_email']} • ${DateFormat('dd/MM HH:mm').format(date)}",
                            style: const TextStyle(color: Colors.grey)),
                        trailing: SizedBox(
                            width: 120,
                            child: Text(log['details'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
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
