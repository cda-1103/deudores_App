import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AppStateProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  double _officialRate = 0.0;
  double _manualRate = 0.0;
  String _rateType = 'BCV';
  String _rateDate = 'Cargando...';
  bool _isLoading = true;

  // Getters
  double get activeRate => _rateType == 'MANUAL' ? _manualRate : _officialRate;
  double get officialRate => _officialRate;
  double get manualRate => _manualRate;
  String get rateType => _rateType;
  String get rateDate => _rateDate;
  bool get isLoading => _isLoading;
  bool get isManual => _rateType == 'MANUAL';

  AppStateProvider() {
    _initSystem();
  }

  Future<void> _initSystem() async {
    print("🚀 INICIANDO SISTEMA DE TASAS...");
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Cargar lo que haya en Supabase
      await _loadFromSupabase();

      // 2. Si estamos en modo BCV, buscamos actualización en la web
      if (_rateType == 'BCV') {
        await fetchBcvNow();
      }
    } catch (e) {
      print("🔴 Error Crítico en Provider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
      print("🏁 Sistema de tasas listo. Activa: $activeRate");
    }
  }

  // --- CARGA DE BASE DE DATOS ---
  Future<void> _loadFromSupabase() async {
    try {
      final response =
          await _supabase.from('app_config').select().limit(1).maybeSingle();

      if (response != null) {
        print("📥 Datos recuperados de Supabase: $response");
        _officialRate = (response['bcv_rate'] as num).toDouble();
        _manualRate = (response['manual_rate'] ?? _officialRate).toDouble();
        _rateType = response['rate_type'] ?? 'BCV';

        // Formatear fecha guardada
        if (response['updated_at'] != null) {
          final date = DateTime.parse(response['updated_at']).toLocal();
          _rateDate = DateFormat('dd/MM HH:mm').format(date);
        }
      } else {
        print("⚠️ La tabla app_config está vacía. Creando registro inicial...");
        // Si no existe fila, creamos una por defecto para que no de error
        await _supabase
            .from('app_config')
            .insert({'bcv_rate': 0.0, 'manual_rate': 0.0, 'rate_type': 'BCV'});
      }
    } catch (e) {
      print("Error leyendo Supabase: $e");
    }
  }

  // --- API EXTERNA (CON PROXY) ---
  Future<void> fetchBcvNow() async {
    print("🌐 Consultando API del BCV...");
    try {
      // Usamos Proxy para saltar bloqueo CORS
      final String proxyUrl =
          'https://api.allorigins.win/raw?url=https://bcv.ingeint.com/api/bcv/rate';

      final response = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("📦 Respuesta API: $data");

        if (data is Map) {
          double newRate = 0.0;
          String newDateRaw = '';

          // Rastrear precio (CORREGIDO: Agregado chequeo para 'rate')
          if (data.containsKey('rate'))
            newRate = (data['rate'] as num).toDouble();
          else if (data.containsKey('price'))
            newRate = (data['price'] as num).toDouble();
          else if (data.containsKey('dolar'))
            newRate = (data['dolar'] as num).toDouble();

          // Rastrear fecha (CORREGIDO: Agregado chequeo para 'date')
          if (data.containsKey('date'))
            newDateRaw = data['date'].toString();
          else if (data.containsKey('date_nice'))
            newDateRaw = data['date_nice'].toString();
          else if (data.containsKey('fecha'))
            newDateRaw = data['fecha'].toString();

          if (newRate > 0) {
            _officialRate = newRate;
            _rateDate = newDateRaw.isNotEmpty
                ? newDateRaw
                : DateFormat('dd/MM').format(DateTime.now());

            print("✅ Tasa encontrada: $_officialRate");

            // Guardamos en Supabase para persistencia
            if (_rateType == 'BCV') {
              await _saveToSupabase();
            }
            notifyListeners();
          }
        }
      } else {
        print("❌ Error API Status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error conexión API: $e");
    }
  }

  // --- MODOS ---
  Future<void> setBcvMode() async {
    print("🔄 Cambiando a Modo BCV");
    _rateType = 'BCV';
    await fetchBcvNow();
    await _saveToSupabase();
    notifyListeners();
  }

  Future<void> setManualMode(double rate) async {
    print("🔄 Cambiando a Modo Manual: $rate");
    _rateType = 'MANUAL';
    _manualRate = rate;

    final now = DateTime.now();
    String label = (now.weekday >= 6) ? "Proy. Lunes" : "Manual";
    _rateDate = "${DateFormat('dd/MM').format(now)} ($label)";

    await _saveToSupabase();
    notifyListeners();
  }

  Future<void> _saveToSupabase() async {
    // Actualizamos la fila existente (siempre habrá una sola fila de config)
    // Usamos upsert para mayor seguridad
    /* NOTA: Asumimos que la fila tiene ID, pero como Supabase genera IDs, 
       simplemente actualizamos la fila más reciente */

    // Recuperamos el ID primero para actualizar ESE id especifico
    final existing =
        await _supabase.from('app_config').select('id').limit(1).maybeSingle();

    if (existing != null) {
      await _supabase.from('app_config').update({
        'bcv_rate': _officialRate,
        'manual_rate': _manualRate,
        'rate_type': _rateType,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      await _supabase.from('app_config').insert({
        'bcv_rate': _officialRate,
        'manual_rate': _manualRate,
        'rate_type': _rateType,
      });
    }
  }

  String toBs(double amountUsd) {
    if (activeRate == 0) return '---';
    return 'Bs. ${(amountUsd * activeRate).toStringAsFixed(2)}';
  }
}
