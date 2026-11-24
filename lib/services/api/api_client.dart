import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../application/config/app_config.dart';
import '../storage/session_storage.dart';

/// Status koneksi ke backend. Aplikasi BELUM mendukung antrean transaksi
/// offline: saat offline, transaksi tidak dapat disimpan dan harus diulang.
enum ConnectionStatus { unknown, online, offline }

/// Error dari backend atau jaringan. [message] siap ditampilkan ke user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// HTTP client untuk WMS API.
///
/// Semua respons backend berbentuk `{ success, message, data }`.
/// Method di sini mengembalikan isi `data`, atau melempar [ApiException].
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();
  final Random _random = Random.secure();

  /// Status koneksi terakhir ke server (untuk indikator Online/Offline).
  final connection = ConnectionStatus.unknown.obs;

  /// Dipanggil saat token tidak valid / kedaluwarsa (HTTP 401).
  /// Diisi oleh AuthService agar user diarahkan ke halaman login.
  Future<void> Function()? onUnauthorized;

  String get baseUrl => SessionStorage.instance.baseUrl;

  /// UUID v4 untuk header Idempotency-Key. Buat SEKALI per aksi/form agar
  /// retry atau double-tap tidak membuat transaksi ganda di server.
  String newIdempotencyKey() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body, String? idempotencyKey]) =>
      _send('POST', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> put(String path, [Object? body, String? idempotencyKey]) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> patch(String path, [Object? body, String? idempotencyKey]) =>
      _send('PATCH', path, body: body, idempotencyKey: idempotencyKey);

  Future<dynamic> delete(String path, {String? idempotencyKey}) =>
      _send('DELETE', path, idempotencyKey: idempotencyKey);

  /// Ambil list JSON dan ubah dengan [fromJson].
  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);
    return (data as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Cek koneksi ke server tertentu (dipakai di Pengaturan Server).
  Future<void> ping([String? url]) async {
    final root = (url ?? baseUrl).trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await _http.get(Uri.parse('$root/health')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw ApiException('Server merespons dengan kode ${res.statusCode}.', statusCode: res.statusCode);
      }
    } on ApiException {
      rethrow;
    } on FormatException {
      throw const ApiException('Format URL tidak valid.');
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke $root');
    }
  }

  /// Format tanggal untuk API: YYYY-MM-DD.
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Uri _uri(String path, Map<String, dynamic>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return uri;
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return uri.replace(queryParameters: params);
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body, String? idempotencyKey}) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';
    final token = SessionStorage.instance.token;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null) request.headers['Idempotency-Key'] = idempotencyKey;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(AppConfig.apiTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      connection.value = ConnectionStatus.offline;
      throw const ApiException('Server tidak merespons. Periksa koneksi lalu coba lagi.');
    } on SocketException {
      connection.value = ConnectionStatus.offline;
      throw ApiException('Tidak dapat terhubung ke server ($baseUrl). Periksa jaringan atau Pengaturan Server.');
    } on http.ClientException catch (e) {
      connection.value = ConnectionStatus.offline;
      throw ApiException('Koneksi gagal: ${e.message}');
    }
    connection.value = ConnectionStatus.online;

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && json != null && json['success'] != false) return json['data'];

    final message = (json?['message'] as String?) ??
        (ok ? 'Respons server tidak valid.' : 'Terjadi kesalahan (HTTP ${response.statusCode}).');

    if (response.statusCode == 401 && !path.startsWith('/auth/login')) {
      await onUnauthorized?.call();
    }
    throw ApiException(message, statusCode: response.statusCode);
  }
}
