import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../models/warehouse_location_model.dart';
import '../models/warehouse_model.dart';

/// Gudang & lokasi untuk SUNMI (hanya baca). Gudang, lokasi, dan barcode
/// lokasi dibuat/dikelola dari aplikasi Desktop.
class WarehouseController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedTab = 0.obs;
  final selectedWarehouseId = ''.obs;
  final selectedStatus = 'Semua'.obs;
  final selectedType = 'Semua'.obs;
  final isLoading = false.obs;

  /// Gudang yang boleh diakses user.
  final warehouses = <WarehouseModel>[].obs;
  /// Semua gudang aktif (untuk pilihan tujuan transfer).
  final allWarehouses = <WarehouseModel>[].obs;
  final locations = <WarehouseLocationModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    selectedWarehouseId.value = WarehouseContext.instance.activeId.value;
    fetchAll();
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _api.getList('/warehouses', WarehouseModel.fromJson),
        _api.getList('/warehouses', WarehouseModel.fromJson, query: {'all': 'true', 'active': 'true'}),
        _api.getList('/locations', WarehouseLocationModel.fromJson),
      ]);
      warehouses.assignAll(results[0] as List<WarehouseModel>);
      allWarehouses.assignAll(results[1] as List<WarehouseModel>);
      locations.assignAll(results[2] as List<WarehouseLocationModel>);
      if (!warehouses.any((w) => w.id == selectedWarehouseId.value)) {
        selectedWarehouseId.value = warehouses.isNotEmpty ? warehouses.first.id : '';
      }
    } catch (e) {
      showApiError(e, title: 'Gagal memuat gudang');
    } finally {
      isLoading.value = false;
    }
  }

  WarehouseModel? get selectedWarehouse => warehouses.firstWhereOrNull(
    (item) => item.id == selectedWarehouseId.value,
  );

  List<WarehouseLocationModel> get currentLocations {
    final query = searchQuery.value.trim().toLowerCase();
    return locations.where((location) {
      final matchesWarehouse = location.warehouseId == selectedWarehouseId.value;
      final matchesQuery = query.isEmpty ||
          location.code.toLowerCase().contains(query) ||
          (location.barcode ?? '').toLowerCase().contains(query) ||
          location.zone.toLowerCase().contains(query) ||
          location.description.toLowerCase().contains(query);
      final matchesStatus = selectedStatus.value == 'Semua' || statusLabel(location.status) == selectedStatus.value;
      final matchesType = selectedType.value == 'Semua' ||
          (selectedType.value == 'Rak' ? location.type == 'STORAGE' : location.type != 'STORAGE');
      return matchesWarehouse && matchesQuery && matchesStatus && matchesType;
    }).toList();
  }

  int countByStatus(LocationStatus status, String warehouseId) => locations
      .where((e) => e.warehouseId == warehouseId && e.status == status)
      .length;

  int get totalLocations =>
      locations.where((e) => e.warehouseId == selectedWarehouseId.value).length;

  void updateSearch(String value) => searchQuery.value = value;

  void selectWarehouse(String id) {
    selectedWarehouseId.value = id;
    searchController.clear();
    searchQuery.value = '';
    selectedStatus.value = 'Semua';
  }

  static String statusLabel(LocationStatus status) {
    switch (status) {
      case LocationStatus.available:
        return 'Available';
      case LocationStatus.occupied:
        return 'Occupied';
      case LocationStatus.blocked:
        return 'Blocked';
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
