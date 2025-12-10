import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/formatters.dart'; // <--- IMPORTANTE

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
    final isManual = provider.isManual;

    // DETECCIÓN DE PANTALLA
    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            const Text("Dashboard Principal",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 30),
          ],

          // --- TARJETAS RESPONSIVAS ---
          if (isMobile)
            Column(
              children: [
                _buildRateCard(provider, isManual),
                const SizedBox(height: 12),
                // FORMATO EUROPEO EN KPI
                _KpiCard(
                    title: "Por Cobrar (USD)",
                    value: "\$ ${AppFormatters.money(_totalDebt)}",
                    icon: Icons.account_balance_wallet,
                    color: Colors.orange,
                    isLoading: _isLoadingDebt),
                const SizedBox(height: 12),
                // CÁLCULO MANUAL PARA ASEGURAR FORMATO
                _KpiCard(
                    title: "Equivalente (Bs)",
                    value:
                        "Bs. ${AppFormatters.money(_totalDebt * provider.activeRate)}",
                    icon: Icons.attach_money,
                    color: Colors.green,
                    isLoading: _isLoadingDebt || provider.isLoading),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildRateCard(provider, isManual)),
                const SizedBox(width: 16),
                Expanded(
                    child: _KpiCard(
                        title: "Por Cobrar (USD)",
                        value: "\$ ${AppFormatters.money(_totalDebt)}",
                        icon: Icons.account_balance_wallet,
                        color: Colors.orange,
                        isLoading: _isLoadingDebt)),
                const SizedBox(width: 16),
                Expanded(
                    child: _KpiCard(
                        title: "Equivalente (Bs)",
                        value:
                            "Bs. ${AppFormatters.money(_totalDebt * provider.activeRate)}",
                        icon: Icons.attach_money,
                        color: Colors.green,
                        isLoading: _isLoadingDebt || provider.isLoading)),
              ],
            ),

          const SizedBox(height: 30),
          const Text("Actividad Reciente",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          _buildActivityTable(supabase),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRateCard(AppStateProvider provider, bool isManual) {
    return _KpiCard(
      title: isManual ? "Tasa Manual" : "Tasa BCV",
      // FORMATO EUROPEO EN TASA
      value: "Bs. ${AppFormatters.money(provider.activeRate)}",
      subtitle: provider.rateDate,
      icon: isManual ? Icons.edit_note : Icons.verified,
      color: isManual ? Colors.purple : Colors.blue,
      isLoading: provider.isLoading,
      onTap: () => _showQuickRateSelector(context, provider),
    );
  }

  Widget _buildActivityTable(SupabaseClient supabase) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('movements')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .limit(20),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final movements = snapshot.data!;
          if (movements.isEmpty)
            return const Center(
                child: Text("Sin movimientos.",
                    style: TextStyle(color: Colors.grey)));

          return ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final mov = movements[index];
              final isDebt = mov['type'] == 'DEBT';
              final amount = (mov['amount'] as num).toDouble();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDebt
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  child: Icon(isDebt ? Icons.shopping_bag : Icons.attach_money,
                      color: isDebt ? Colors.blue : Colors.green, size: 20),
                ),
                title: FutureBuilder(
                  future: supabase
                      .from('customers')
                      .select('name')
                      .eq('id', mov['customer_id'])
                      .single(),
                  builder: (context, custSnap) {
                    if (!custSnap.hasData) return const Text("...");
                    return Text(custSnap.data!['name'],
                        style: const TextStyle(color: Colors.white));
                  },
                ),
                subtitle: Text(
                    mov['description'] ?? (isDebt ? 'Venta' : 'Abono'),
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                // FORMATO EUROPEO EN LISTA
                trailing: Text(
                    "${isDebt ? '+' : '-'} \$ ${AppFormatters.money(amount)}",
                    style: TextStyle(
                        color: isDebt ? Colors.white : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              );
            },
          );
        },
      ),
    );
  }

  void _showQuickRateSelector(BuildContext context, AppStateProvider provider) {
    final manualCtrl =
        TextEditingController(text: provider.activeRate.toString());
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Configurar Tasa",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Usar Tasa BCV (API)",
                    style: TextStyle(color: Colors.white)),
                // FORMATO EUROPEO EN DIÁLOGO
                subtitle: Text(
                    "Detectada: Bs. ${AppFormatters.money(provider.officialRate)}",
                    style: const TextStyle(color: Colors.grey)),
                leading: const Icon(Icons.cloud_download, color: Colors.blue),
                onTap: () {
                  provider.setBcvMode();
                  Navigator.pop(ctx);
                },
                tileColor:
                    !provider.isManual ? Colors.blue.withOpacity(0.1) : null,
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              TextField(
                controller: manualCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Tasa Manual / Fin de Semana",
                    prefixText: "Bs. ",
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple),
                    onPressed: () {
                      // PARSEO INTELIGENTE
                      final val = AppFormatters.stringToDouble(manualCtrl.text);
                      if (val > 0) {
                        provider.setManualMode(val);
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text("ACTIVAR MANUAL")),
              )
            ],
          ),
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
  final bool isLoading;
  final VoidCallback? onTap;

  const _KpiCard(
      {required this.title,
      required this.value,
      this.subtitle,
      required this.icon,
      required this.color,
      this.isLoading = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(title,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              Icon(icon, color: color, size: 20)
            ]),
            const SizedBox(height: 10),
            isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(value,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12))
                        ]
                      ]),
            if (onTap != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Text("Cambiar",
                        style: TextStyle(fontSize: 12, color: color)),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: Colors.grey)
                  ]))
          ],
        ),
      ),
    );
  }
}
