import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/config/app_config.dart';

/// Penyimpanan lokal sesi login (token JWT, data user) dan URL server.
class SessionStorage {
  SessionStorage._();
  static final SessionStorage instance = SessionStorage._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _baseUrlKey = 'api_base_url';
  static const _activeWarehouseKey = 'active_warehouse_id';

  late SharedPreferences _prefs;

  /// Wajib dipanggil sekali di main() sebelum runApp.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? get token => _prefs.getString(_tokenKey);
  bool get hasToken => (token ?? '').isNotEmpty;

  Map<String, dynamic>? get user {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String get baseUrl {
    final saved = _prefs.getString(_baseUrlKey);
    return (saved == null || saved.isEmpty) ? AppConfig.apiBaseUrl : saved;
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user));
  }

  Future<void> clearSession() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }

  String? get activeWarehouseId => _prefs.getString(_activeWarehouseKey);

  Future<void> saveActiveWarehouse(String id) => _prefs.setString(_activeWarehouseKey, id);

  Future<void> saveBaseUrl(String url) async {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) {
      await _prefs.remove(_baseUrlKey);
    } else {
      await _prefs.setString(_baseUrlKey, value);
    }
  }
}
