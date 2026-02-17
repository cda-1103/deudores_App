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
  final _usdCtrl = TextEditingController();
  final _bsCtrl = TextEditingController();
  
  bool _useManualRate = false; // Toggle local
  bool _isUpdating = false;

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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    
    // Elegimos la tasa según el switch local
    final rateToUse = _useManualRate ? provider.manualRate : provider.officialRate;
    final rateLabel = _useManualRate ? "Tasa Manual" : "Tasa BCV";

    return Center(
      child: SingleChildScrollView( // Scroll para móviles pequeños
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calculate_outlined, size: 60, color: Colors.white24),
              const SizedBox(height: 20),
              const Text("Calculadora Rápida", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              
              // SELECTOR DE TASA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("BCV", style: TextStyle(color: !_useManualRate ? Colors.blue : Colors.grey)),
                    Switch(
                      value: _useManualRate,
                      activeColor: Colors.purple,
                      inactiveTrackColor: Colors.blue.withOpacity(0.5),
                      onChanged: (val) {
                        setState(() {
                           _useManualRate = val;
                           // Recalcular si ya hay montos
                           if(_usdCtrl.text.isNotEmpty) _onUsdChanged(_usdCtrl.text, rateToUse);
                        });
                      },
                    ),
                    Text("Manual", style: TextStyle(color: _useManualRate ? Colors.purple : Colors.grey)),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              Text(
                "Usando $rateLabel: Bs. ${AppFormatters.money(rateToUse)}", 
                style: const TextStyle(color: Colors.white70, fontSize: 16)
              ),
              const SizedBox(height: 30),
              
              // INPUTS
              TextField(
                controller: _usdCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: "\$ ", prefixStyle: const TextStyle(color: Colors.white54, fontSize: 32),
                  filled: true, fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  labelText: "Dólares",
                ),
                onChanged: (val) => _onUsdChanged(val, rateToUse),
              ),
              const SizedBox(height: 15),
              const Icon(Icons.swap_vert, size: 40, color: Colors.grey),
              const SizedBox(height: 15),
              TextField(
                controller: _bsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 32, color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: "Bs. ", prefixStyle: const TextStyle(color: Colors.white54, fontSize: 32),
                  filled: true, fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  labelText: "Bolívares",
                ),
                onChanged: (val) => _onBsChanged(val, rateToUse),
              ),
              const SizedBox(height: 30),
              
              TextButton.icon(
                onPressed: () { _usdCtrl.clear(); _bsCtrl.clear(); },
                icon: const Icon(Icons.refresh, color: Colors.grey),
                label: const Text("LIMPIAR", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}