import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/themes.dart';
import '../../providers/app_state_provider.dart';
import '../../core/utils/formatters.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final TextEditingController _usdCtrl = TextEditingController();
  final TextEditingController _bsCtrl = TextEditingController();
  final TextEditingController _rateEditCtrl = TextEditingController();
  
  bool _isUpdating = false;

  @override
  void dispose() {
    _usdCtrl.dispose();
    _bsCtrl.dispose();
    _rateEditCtrl.dispose();
    super.dispose();
  }

  void _onUsdChanged(String val, double rate) {
    if (_isUpdating) return;
    _isUpdating = true;
    double usd = AppFormatters.stringToDouble(val);
    double bs = usd * rate;
    _bsCtrl.text = bs == 0 ? "" : AppFormatters.money(bs);
    _isUpdating = false;
  }

  void _onBsChanged(String val, double rate) {
    if (_isUpdating) return;
    _isUpdating = true;
    double bs = AppFormatters.stringToDouble(val);
    double usd = rate > 0 ? bs / rate : 0;
    _usdCtrl.text = usd == 0 ? "" : AppFormatters.money(usd);
    _isUpdating = false;
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 32}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(32),
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
    final provider = Provider.of<AppStateProvider>(context);
    final rateToUse = provider.activeRate;

    if (_rateEditCtrl.text.isEmpty && provider.isManual) {
      _rateEditCtrl.text = provider.manualRate.toString();
    }

    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.all(24),
          child: _glassContainer(
            child: Column(
              children: [
                const Icon(Icons.rocket_launch_rounded, size: 50, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  "CONVERSOR INTELIGENTE", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)
                ),
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RateToggle(
                          label: "TASA BCV", 
                          isSelected: !provider.isManual, 
                          color: Colors.blue, 
                          onTap: () => provider.setBcvMode()
                        )
                      ),
                      Expanded(
                        child: _RateToggle(
                          label: "MANUAL", 
                          isSelected: provider.isManual, 
                          color: Colors.purpleAccent, 
                          onTap: () => provider.setManualMode(provider.manualRate)
                        )
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (provider.isManual) ...[
                   TextField(
                     controller: _rateEditCtrl,
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                     style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 18),
                     textAlign: TextAlign.center,
                     decoration: InputDecoration(
                       labelText: "Ajustar Tasa Manual",
                       labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                       prefixText: "Bs. ",
                       prefixStyle: const TextStyle(color: Colors.purpleAccent),
                       filled: true, 
                       fillColor: Colors.purple.withOpacity(0.1),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                     ),
                     onChanged: (v) {
                        double val = AppFormatters.stringToDouble(v);
                        if (val > 0) {
                          provider.setManualMode(val);
                          _onUsdChanged(_usdCtrl.text, val); 
                        }
                     },
                   ),
                   const SizedBox(height: 20),
                ] else ...[
                   Text(
                     "Tasa BCV Operativa: Bs. ${AppFormatters.money(rateToUse)}", 
                     style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)
                   ),
                   const SizedBox(height: 24),
                ],
                
                _CyberInput(
                  controller: _usdCtrl,
                  label: "DÓLARES",
                  prefix: "\$ ",
                  color: Colors.white,
                  onChanged: (v) => _onUsdChanged(v, rateToUse),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20), 
                  child: Icon(Icons.sync_alt_rounded, color: Colors.white54, size: 30)
                ),
                _CyberInput(
                  controller: _bsCtrl,
                  label: "BOLÍVARES",
                  prefix: "Bs. ",
                  color: AppTheme.accentGreen,
                  onChanged: (v) => _onBsChanged(v, rateToUse),
                ),
                const SizedBox(height: 32),
                
                TextButton.icon(
                  onPressed: () { 
                    _usdCtrl.clear(); 
                    _bsCtrl.clear(); 
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  label: const Text("LIMPIAR CALCULADORA", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RateToggle extends StatelessWidget {
  final String label; 
  final bool isSelected; 
  final Color color; 
  final VoidCallback onTap;

  const _RateToggle({
    required this.label, 
    required this.isSelected, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), 
        padding: const EdgeInsets.symmetric(vertical: 12), 
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: isSelected ? color : Colors.transparent)
        ), 
        alignment: Alignment.center, 
        child: Text(
          label, 
          style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)
        )
      ),
    );
  }
}

class _CyberInput extends StatelessWidget {
  final TextEditingController controller; 
  final String label; 
  final String prefix; 
  final Color color; 
  final Function(String) onChanged;

  const _CyberInput({
    required this.controller, 
    required this.label, 
    required this.prefix, 
    required this.color, 
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontSize: 38, color: color, fontWeight: FontWeight.w900),
      textAlign: TextAlign.center,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 12),
        prefixText: prefix, 
        prefixStyle: const TextStyle(color: Colors.white54, fontSize: 24),
        filled: true, 
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: color.withOpacity(0.5))),
      ),
    );
  }
}