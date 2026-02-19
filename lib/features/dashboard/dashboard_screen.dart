import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalDebt = 0.0;
  bool _isLoadingDebt = true;

  @override
  void initState() {
    super.initState();
    _fetchTotalDebt();
  }

  Future<void> _fetchTotalDebt() async {
    try {
      final response = await Supabase.instance.client
          .from('customers')
          .select('current_balance');
      double total = 0;
      if (response != null) {
        for (var row in response as List<dynamic>) {
          total += (row['current_balance'] as num).toDouble();
        }
      }
      if (mounted)
        setState(() {
          _totalDebt = total;
          _isLoadingDebt = false;
        });
    } catch (e) {
      debugPrint("$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final supabase = Supabase.instance.client;
    final isMobile = MediaQuery.of(context).size.width < 800;

    final debtUsd = _totalDebt;
    final debtBs = _totalDebt * provider.activeRate;

    return CustomScrollView(
      slivers: [
        if (!isMobile)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text("Panel Principal",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),

        // 1. KPIs con Diseño Glassmorphism Mejorado
        SliverGrid.count(
          crossAxisCount: isMobile ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.3 : 1.8, 
          children: [
            _KpiCard(
              title: provider.isManual ? "Tasa Manual" : "Tasa BCV",
              value: "Bs. ${AppFormatters.money(provider.activeRate)}",
              subtitle: provider.rateDate,
              icon: Icons.auto_graph_rounded,
              color: Colors.blueAccent,
              gradient: [Colors.blue, Colors.blueGrey],
              onTap: () => _showQuickRateSelector(context, provider),
            ),
            _KpiCard(
              title: "Total por Cobrar",
              value: "\$ ${AppFormatters.money(debtUsd)}",
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.orangeAccent,
              gradient: [Colors.orange, Colors.redAccent],
              isLoading: _isLoadingDebt,
            ),
            _KpiCard(
              title: "Equivalente Bs.",
              value: "Bs. ${AppFormatters.money(debtBs)}",
              icon: Icons.currency_exchange_rounded,
              color: AppTheme.accentGreen,
              gradient: [AppTheme.accentGreen, Colors.teal],
              isLoading: _isLoadingDebt || provider.isLoading,
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        // 2. Sección de Gráficos Visuales (Simulado con Widgets personalizados para evitar dependencias extras)
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Distribución de Cartera", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SimpleBar(label: "Lun", value: 0.4, color: Colors.blue),
                    ),
                    Expanded(
                      child: _SimpleBar(label: "Mar", value: 0.7, color: Colors.blue),
                    ),
                    Expanded(
                      child: _SimpleBar(label: "Mie", value: 0.5, color: Colors.blue),
                    ),
                    Expanded(
                      child: _SimpleBar(label: "Jue", value: 0.9, color: Colors.purpleAccent),
                    ),
                    Expanded(
                      child: _SimpleBar(label: "Vie", value: 0.6, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Center(child: Text("Histórico de Cobranza (Semana)", style: TextStyle(color: Colors.white38, fontSize: 10))),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Actividad Reciente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (isMobile) const Icon(Icons.history, color: AppTheme.secondary, size: 20),
              ],
            ),
          ),
        ),

        // 3. Lista de Movimientos
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('movements').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(20),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
                final movements = snapshot.data!;
                if (movements.isEmpty) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("Sin movimientos recientes.", style: TextStyle(color: Colors.grey))));

                return ListView.separated(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final mov = movements[index];
                    final isDebt = mov['type'] == 'DEBT';
                    final amount = (mov['amount'] as num).toDouble();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isDebt ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        child: Icon(isDebt ? Icons.shopping_bag_outlined : Icons.attach_money,
                            color: isDebt ? Colors.orange : Colors.green, size: 20),
                      ),
                      title: FutureBuilder(
                        future: supabase.from('customers').select('name').eq('id', mov['customer_id']).single(),
                        builder: (context, custSnap) {
                          if (!custSnap.hasData) return const Text("...");
                          return Text(custSnap.data!['name'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white));
                        },
                      ),
                      subtitle: Text(
                          mov['description'] ?? (isDebt ? 'Venta' : 'Abono'),
                          style: const TextStyle(color: AppTheme.secondary, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                          "${isDebt ? '+' : '-'} \$${AppFormatters.money(amount)}",
                          style: TextStyle(
                              color: isDebt ? Colors.white : AppTheme.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    );
                  },
                );
              },
            ),
          ),
        ),
        
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _showQuickRateSelector(BuildContext context, AppStateProvider provider) {
    final manualCtrl = TextEditingController(text: provider.activeRate.toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Configuración de Tasa", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              title: const Text("Usar Tasa BCV (API)", style: TextStyle(color: Colors.white)),
              subtitle: Text("Detectada: Bs. ${AppFormatters.money(provider.officialRate)}", style: const TextStyle(color: Colors.grey)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.cloud_download, color: Colors.blue),
              ),
              onTap: () { provider.setBcvMode(); Navigator.pop(ctx); },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: !provider.isManual ? AppTheme.primary.withOpacity(0.1) : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: manualCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Establecer Tasa Manual",
                  prefixText: "Bs. ",
                  prefixIcon: Icon(Icons.edit)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  onPressed: () {
                    final val = AppFormatters.stringToDouble(manualCtrl.text);
                    if (val > 0) { provider.setManualMode(val); Navigator.pop(ctx); }
                  },
                  child: const Text("ACTIVAR TASA MANUAL")),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final bool isLoading;
  final VoidCallback? onTap;

  const _KpiCard({required this.title, required this.value, this.subtitle, required this.icon, required this.color, required this.gradient, this.isLoading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [gradient.first.withOpacity(0.2), gradient.last.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(title, style: TextStyle(color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                    if (subtitle != null) ...[
                       const SizedBox(height: 2),
                       Text(subtitle!, style: TextStyle(color: color.withOpacity(0.8), fontSize: 9))
                    ]
                  ],
                )
          ],
        ),
      ),
    );
  }
}

class _SimpleBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SimpleBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 80,
          width: 12,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(seconds: 1),
            height: 80 * value,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 5)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}