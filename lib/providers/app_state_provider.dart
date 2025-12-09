import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AppStateProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ESTADO DE TASA (Ya existente)
  double _officialRate = 0.0;
  double _manualRate = 0.0;
  String _rateType = 'BCV';
  String _rateDate = 'Cargando...';

  // NUEVO: ESTADO DEL USUARIO ACTUAL
  Map<String, dynamic> _currentUserProfile = {};

  bool _isLoading = true;

  // Getters Tasa
  double get activeRate => _rateType == 'MANUAL' ? _manualRate : _officialRate;
  double get officialRate => _officialRate;
  double get manualRate => _manualRate;
  String get rateType => _rateType;
  String get rateDate => _rateDate;
  bool get isLoading => _isLoading;
  bool get isManual => _rateType == 'MANUAL';

  // NUEVO: Getters de Permisos (Fáciles de usar en la UI)
  String get currentUserName => _currentUserProfile['full_name'] ?? 'Usuario';
  bool get canDeleteClients =>
      _currentUserProfile['can_delete_clients'] == true;
  bool get canDeleteSales => _currentUserProfile['can_delete_sales'] == true;
  bool get canChangeRate => _currentUserProfile['can_change_rate'] == true;

  AppStateProvider() {
    _initSystem();
  }

  Future<void> _initSystem() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromSupabase();
      await _loadUserProfile(); // <--- CARGAMOS EL PERFIL
      if (_rateType == 'BCV') await fetchBcvNow();
    } catch (e) {
      debugPrint("Error Provider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- NUEVO: CARGAR PERFIL DE USUARIO ---
  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        _currentUserProfile = response;
        notifyListeners();
      } catch (e) {
        debugPrint("Error cargando perfil: $e");
      }
    }
  }

  // --- LÓGICA EXISTENTE DE TASAS ---
  Future<void> _loadFromSupabase() async {
    try {
      final response =
          await _supabase.from('app_config').select().limit(1).maybeSingle();
      if (response != null) {
        _officialRate = (response['bcv_rate'] as num).toDouble();
        _manualRate = (response['manual_rate'] ?? _officialRate).toDouble();
        _rateType = response['rate_type'] ?? 'BCV';
        if (response['updated_at'] != null) {
          final date = DateTime.parse(response['updated_at']).toLocal();
          _rateDate = DateFormat('dd/MM HH:mm').format(date);
        }
      } else {
        await _supabase
            .from('app_config')
            .insert({'bcv_rate': 0.0, 'manual_rate': 0.0, 'rate_type': 'BCV'});
      }
    } catch (e) {
      debugPrint("Error DB: $e");
    }
  }

  Future<void> fetchBcvNow() async {
    try {
      final String proxyUrl =
          'https://api.allorigins.win/raw?url=https://bcv.ingeint.com/api/bcv/rate';
      final response = await http
          .get(Uri.parse(proxyUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map) {
          double newRate = 0.0;
          String newDateRaw = '';
          if (data.containsKey('rate'))
            newRate = (data['rate'] as num).toDouble();
          else if (data.containsKey('price'))
            newRate = (data['price'] as num).toDouble();
          else if (data.containsKey('dolar'))
            newRate = (data['dolar'] as num).toDouble();

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
            if (_rateType == 'BCV') await _saveToSupabase();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("Error API: $e");
    }
  }

  Future<void> setBcvMode() async {
    _rateType = 'BCV';
    await fetchBcvNow();
    await _saveToSupabase();
    notifyListeners();
  }

  Future<void> setManualMode(double rate) async {
    _rateType = 'MANUAL';
    _manualRate = rate;
    final now = DateTime.now();
    String label = (now.weekday >= 6) ? "Proy. Lunes" : "Manual";
    _rateDate = "${DateFormat('dd/MM').format(now)} ($label)";
    await _saveToSupabase();
    notifyListeners();
  }

  Future<void> _saveToSupabase() async {
    final existing =
        await _supabase.from('app_config').select('id').limit(1).maybeSingle();
    if (existing != null) {
      await _supabase.from('app_config').update({
        'bcv_rate': _officialRate,
        'manual_rate': _manualRate,
        'rate_type': _rateType,
        'updated_at': DateTime.now().toIso8601String()
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
    if (activeRate == 0) return '---';
    return 'Bs. ${(amountUsd * activeRate).toStringAsFixed(2)}';
  }
}
