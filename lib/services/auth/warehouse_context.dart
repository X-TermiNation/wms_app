import 'package:get/get.dart';

import '../api/api_client.dart';
import '../storage/session_storage.dart';

/// Gudang yang boleh diakses user (dari backend) dan gudang aktif yang dipakai
/// semua menu operasional. User tidak bisa memilih gudang di luar haknya;
/// backend tetap memvalidasi akses pada setiap transaksi.
class AccessibleWarehouse {
  const AccessibleWarehouse({required this.id, required this.code, required this.name, required this.isActive});

  final String id, code, name;
  final bool isActive;

  factory AccessibleWarehouse.fromJson(Map<String, dynamic> json) => AccessibleWarehouse(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    isActive: json['isActive'] != false,
  );
}

class WarehouseContext {
  WarehouseContext._();
  static final WarehouseContext instance = WarehouseContext._();

  final warehouses = <AccessibleWarehouse>[].obs;
  final activeId = ''.obs;
  final role = ''.obs;
  final userName = ''.obs;

  AccessibleWarehouse? get active => warehouses.firstWhereOrNull((w) => w.id == activeId.value);
  String get activeName => active?.name ?? '-';
  bool get hasActive => active != null;
  bool get canApprove => role.value == 'admin' || role.value == 'supervisor';
  bool get canInspect => role.value == 'admin' || role.value == 'supervisor' || role.value == 'qc';

  /// Muat dari sesi tersimpan (dipanggil saat start & setelah login).
  void loadFromSession() {
    final user = SessionStorage.instance.user;
    role.value = (user?['role'] as String?) ?? '';
    userName.value = (user?['fullName'] as String?) ?? (user?['username'] as String?) ?? '';
    final list = ((user?['warehouses'] as List?) ?? const [])
        .map((e) => AccessibleWarehouse.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((w) => w.isActive)
        .toList();
    warehouses.assignAll(list);
    final saved = SessionStorage.instance.activeWarehouseId;
    activeId.value = list.any((w) => w.id == saved) ? saved! : (list.isNotEmpty ? list.first.id : '');
  }

  /// Sinkronkan hak akses terbaru dari server (perubahan dari Desktop).
  Future<void> refresh() async {
    final data = await ApiClient.instance.get('/auth/me') as Map<String, dynamic>;
    final token = SessionStorage.instance.token;
    if (token != null) await SessionStorage.instance.saveSession(token, data);
    loadFromSession();
  }

  Future<void> select(String warehouseId) async {
    if (!warehouses.any((w) => w.id == warehouseId)) return;
    activeId.value = warehouseId;
    await SessionStorage.instance.saveActiveWarehouse(warehouseId);
  }

  void clear() {
    warehouses.clear();
    activeId.value = '';
    role.value = '';
    userName.value = '';
  }
}
