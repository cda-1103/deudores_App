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
import 'features/payments/payments_screen.dart';
import 'features/calculator/calculator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // LISTA MÓVIL (Sin Configuración para ahorrar espacio)
  final List<Widget> _mobileScreens = [
    const DashboardScreen(),
    const PosScreen(),
    const PaymentsScreen(),
    const CalculatorScreen(),
    const CustomersScreen(),
  ];

  // LISTA DESKTOP (Completa)
  final List<Widget> _desktopScreens = [
    const DashboardScreen(),
    const PosScreen(),
    const PaymentsScreen(),
    const CalculatorScreen(),
    const CustomersScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Detectar si es móvil (menos de 800px de ancho)
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    // Seleccionar pantalla correcta
    final currentScreen = isMobile 
        ? _mobileScreens[_selectedIndex] 
        : _desktopScreens[_selectedIndex];

    return Scaffold(
      // --- APP BAR (SOLO MÓVIL) ---
      appBar: isMobile
          ? AppBar(
              title: const Text("BBT LICORES"),
              actions: [
                // Icono de configuración aquí para ahorrar espacio abajo
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text("Configuración")),
                        body: const SettingsScreen()
                      )
                    ));
                  },
                ),
              ],
            )
          : null,

      // --- CUERPO PRINCIPAL ---
      body: Row(
        children: [
          // SIDEBAR (SOLO DESKTOP)
          if (!isMobile)
            _buildDesktopSidebar(),
          
          // CONTENIDO
          Expanded(
            child: Container(
              color: AppTheme.background,
              child: SafeArea(
                top: false, // El AppBar ya protege arriba en móvil
                bottom: false, 
                child: Padding(
                  padding: isMobile 
                      ? const EdgeInsets.symmetric(horizontal: 16) 
                      : const EdgeInsets.all(32), 
                  child: currentScreen,
                ),
              ),
            ),
          ),
        ],
      ),

      // --- BARRA INFERIOR (SOLO MÓVIL) ---
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Inicio'),
                NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Venta'),
                NavigationDestination(icon: Icon(Icons.attach_money), label: 'Abonos'),
                NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Calc'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
              ],
            )
          : null,
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      color: AppTheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20)]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100), 
              child: Image.asset('lib/assets/logo2.PNG', height: 90, width: 90, fit: BoxFit.cover)
            ),
          ),
          const SizedBox(height: 20),
          const Text("BBT CONTROL", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
          const SizedBox(height: 40),
          
          // Menú
          _SidebarItem(icon: Icons.dashboard, label: "Dashboard", isActive: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
          _SidebarItem(icon: Icons.point_of_sale, label: "Punto de Venta", isActive: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
          _SidebarItem(icon: Icons.attach_money, label: "Gestión Abonos", isActive: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
          _SidebarItem(icon: Icons.calculate, label: "Calculadora", isActive: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
          _SidebarItem(icon: Icons.people, label: "Clientes", isActive: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
          
          const Divider(color: Colors.white10, height: 40, indent: 20, endIndent: 20),
          
          _SidebarItem(icon: Icons.settings, label: "Configuración", isActive: _selectedIndex == 5, onTap: () => setState(() => _selectedIndex = 5)),
          const Spacer(),
          _SidebarItem(icon: Icons.logout, label: "Cerrar Sesión", isActive: false, onTap: () async { 
            await Supabase.instance.client.auth.signOut(); 
            if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); 
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon; final String label; final bool isActive; final VoidCallback? onTap;
  const _SidebarItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? AppTheme.primary : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : AppTheme.secondary, size: 22),
        title: Text(label, style: TextStyle(
          color: isActive ? Colors.white : AppTheme.secondary, 
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, 
          fontSize: 14)
        ),
        dense: true,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}