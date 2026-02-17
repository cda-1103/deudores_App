import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/utils/formatters.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppStateProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  double _officialRate = 0.0;
  double _manualRate = 0.0;
  String _rateType = 'BCV';
  String _rateDate = 'Cargando...';
  Map<String, dynamic> _currentUserProfile = {};
  bool _isLoading = true;

  double get activeRate => _rateType == 'MANUAL' ? _manualRate : _officialRate;
  double get officialRate => _officialRate;
  double get manualRate => _manualRate;
  String get rateType => _rateType;
  String get rateDate => _rateDate;
  bool get isLoading => _isLoading;
  bool get isManual => _rateType == 'MANUAL';
  
  bool get canChangeRate => _currentUserProfile['can_change_rate'] == true;

  AppStateProvider() {
    _initSystem();
  }

  Future<void> _initSystem() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadUserProfile();
      await _loadFromSupabase();
      if (_rateType == 'BCV') await fetchBcvNow();
    } catch (e) {
      debugPrint("Error Provider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final res = await _supabase.from('profiles').select().eq('id', user.id).single();
        _currentUserProfile = res;
      } catch (_) {}
    }
  }

  Future<void> _loadFromSupabase() async {
    final response = await _supabase.from('app_config').select().limit(1).maybeSingle();
    if (response != null) {
      _officialRate = (response['bcv_rate'] as num).toDouble();
      _manualRate = (response['manual_rate'] ?? _officialRate).toDouble();
      _rateType = response['rate_type'] ?? 'BCV';
      if (response['updated_at'] != null) {
         try {
           _rateDate = DateFormat('dd/MM HH:mm').format(DateTime.parse(response['updated_at']).toLocal());
         } catch (_) { _rateDate = "Actualizado"; }
      }
    }
  }

  // --- API BCV ROBUSTA (Cache Buster) ---
  Future<void> fetchBcvNow() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Esta API funciona nativamente en Web y Desktop sin trucos
      const url = 'https://ve.dolarapi.com/v1/dolares/oficial';
      debugPrint("🖥️ Modo Computadora: Consultando $url");

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // La API devuelve: { "promedio": 36.5, "fechaActualizacion": ... }
        final rate = (data['promedio'] as num).toDouble();
        
        if (rate > 0) {
          _officialRate = rate;
          _rateDate = DateFormat('dd/MM HH:mm').format(DateTime.now());
          
          if (_rateType == 'BCV') await _saveToSupabase();
          debugPrint("✅ ÉXITO: Tasa obtenida: $_officialRate");
        }
      } else {
        throw Exception("Error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error en computadora: $e");
      // Aquí podrías poner un valor por defecto o mostrar alerta
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setManualMode(double rate) async {
    _rateType = 'MANUAL';
    _manualRate = rate;
    
    // Log de auditoría
    final user = _supabase.auth.currentUser;
    try {
      await _supabase.from('action_logs').insert({
        'user_email': user?.email,
        'action': 'Cambio Tasa Manual',
        'details': 'Nueva tasa: $rate',
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
    } catch (_) {}

    await _saveToSupabase();
    notifyListeners();
  }
  
  Future<void> setBcvMode() async {
     _rateType = 'BCV';
     await fetchBcvNow();
     await _saveToSupabase();
     notifyListeners();
  }

  Future<void> _saveToSupabase() async {
    final existing = await _supabase.from('app_config').select('id').limit(1).maybeSingle();
    final now = DateTime.now().toIso8601String();
    
    if (existing != null) {
      await _supabase.from('app_config').update({
        'bcv_rate': _officialRate,
        'manual_rate': _manualRate,
        'rate_type': _rateType,
        'updated_at': now
      }).eq('id', existing['id']);
    } else {
       await _supabase.from('app_config').insert({
         'bcv_rate': _officialRate, 
         'manual_rate': _manualRate, 
         'rate_type': _rateType
       });
    }
  }
  
  String toBs(double amountUsd) {
     final bs = amountUsd * activeRate;
     return AppFormatters.money(bs); 
  }
}