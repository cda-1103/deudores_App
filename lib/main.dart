import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'config/themes.dart';
import 'features/auth/login_screen.dart';
import 'features/sales/pos_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // COLOCA TUS CLAVES AQUÍ
  await Supabase.initialize(
    url: 'https://qpkzbwbynpmwujekoavu.supabase.co',
    anonKey: 'sb_publishable_3rhNR4Qx6mcmVLZLUMUe8g_egxGs8oL',
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppStateProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return MaterialApp(
      title: 'BBT Licores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: session != null ? const MainLayout() : const LoginScreen(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PosScreen(),
    const CustomersScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // PUNTO DE QUIEBRE: Menos de 800px es Móvil
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      // MÓVIL: Barra Inferior
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              backgroundColor: AppTheme.surface,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed, // Para más de 3 items
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard), label: 'Dash'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.point_of_sale), label: 'Venta'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.people), label: 'Clientes'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Config'),
              ],
            )
          : null,

      // MÓVIL: Botón de Salir en la AppBar (ya que no hay sidebar)
      appBar: isMobile
          ? AppBar(
              title: const Text("BBT LICORES", style: TextStyle(fontSize: 16)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (mounted)
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false);
                  },
                )
              ],
            )
          : null,

      body: Row(
        children: [
          // ESCRITORIO: Sidebar Lateral
          if (!isMobile)
            Container(
              width: 250,
              color: AppTheme.surface,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset('assets/logo.jpg',
                        height: 100, width: 100, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  const Text("BBT LICORES",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 40),

                  _SidebarItem(
                      icon: Icons.dashboard,
                      label: "Dashboard",
                      isActive: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0)),
                  _SidebarItem(
                      icon: Icons.point_of_sale,
                      label: "Ventas / POS",
                      isActive: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1)),
                  _SidebarItem(
                      icon: Icons.people,
                      label: "Clientes",
                      isActive: _selectedIndex == 2,
                      onTap: () => setState(() => _selectedTab = 2)),

                  const Spacer(),

                  _SidebarItem(
                      icon: Icons.settings,
                      label: "Configuración",
                      isActive: _selectedIndex == 3,
                      onTap: () => setState(() => _selectedIndex = 3)),
                  _SidebarItem(
                    icon: Icons.logout,
                    label: "Cerrar Sesión",
                    isActive: false,
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted)
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: Container(
              color: AppTheme.background,
              padding:
                  const EdgeInsets.all(16), // Padding reducido para móviles
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para arreglar el setState del sidebar item 2 (copié mal arriba)
  set _selectedTab(int i) => _selectedIndex = i;
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  const _SidebarItem(
      {required this.icon,
      required this.label,
      required this.isActive,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isActive ? AppTheme.primary : Colors.grey),
      title: Text(label,
          style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      tileColor: isActive ? Colors.white.withOpacity(0.05) : null,
      onTap: onTap,
    );
  }
}
