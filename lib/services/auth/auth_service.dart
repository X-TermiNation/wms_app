import 'package:get/get.dart';

import '../../application/routes/app_routes.dart';
import '../../modules/products/controllers/products_controller.dart';
import '../../modules/warehouse/controllers/warehouse_controller.dart';
import '../api/api_client.dart';
import '../storage/session_storage.dart';
import 'warehouse_context.dart';

/// Login / logout terhadap backend dan pengelolaan sesi.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool _redirecting = false;

  /// Hubungkan handler 401 dari ApiClient. Dipanggil sekali di main().
  void init() {
    WarehouseContext.instance.loadFromSession();
    ApiClient.instance.onUnauthorized = () async {
      if (_redirecting || !SessionStorage.instance.hasToken) return;
      _redirecting = true;
      await logout(message: 'Sesi berakhir. Silakan login kembali.');
      _redirecting = false;
    };
  }

  bool get isLoggedIn => SessionStorage.instance.hasToken;

  String get displayName {
    final user = SessionStorage.instance.user;
    return (user?['fullName'] as String?) ?? (user?['username'] as String?) ?? '';
  }

  Future<void> login(String username, String password) async {
    final data = await ApiClient.instance.post('/auth/login', {
      'username': username,
      'password': password,
    }) as Map<String, dynamic>;
    await SessionStorage.instance.saveSession(
      data['token'] as String,
      Map<String, dynamic>.from(data['user'] as Map),
    );
    WarehouseContext.instance.loadFromSession();
  }

  /// Hapus sesi, buang controller data master yang permanen (agar data
  /// dimuat ulang saat login berikutnya), lalu kembali ke halaman login.
  Future<void> logout({String? message}) async {
    await SessionStorage.instance.clearSession();
    WarehouseContext.instance.clear();
    if (Get.isRegistered<ProductsController>()) {
      await Get.delete<ProductsController>(force: true);
    }
    if (Get.isRegistered<WarehouseController>()) {
      await Get.delete<WarehouseController>(force: true);
    }
    Get.offAllNamed(AppRoutes.login);
    if (message != null) {
      Get.snackbar('Login diperlukan', message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
