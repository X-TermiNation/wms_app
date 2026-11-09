import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/warehouse_location_model.dart';
import '../models/warehouse_model.dart';

class WarehouseController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedTab = 0.obs;
  final selectedWarehouseId = 'WH-001'.obs;
  final selectedStatus = 'Semua'.obs;

  final warehouses = <WarehouseModel>[
    const WarehouseModel(
      id: 'WH-001',
      code: 'WH-SBY-001',
      name: 'Gudang Utama',
      address: 'Jl. Rungkut Industri, Surabaya',
      isActive: true,
    ),
    const WarehouseModel(
      id: 'WH-002',
      code: 'WH-SBY-002',
      name: 'Gudang Surabaya',
      address: 'Jl. Margomulyo, Surabaya',
      isActive: true,
    ),
    const WarehouseModel(
      id: 'WH-003',
      code: 'WH-JKT-001',
      name: 'Gudang Jakarta',
      address: 'Jl. Cakung Cilincing, Jakarta',
      isActive: false,
    ),
  ].obs;

  final locations = <WarehouseLocationModel>[
    const WarehouseLocationModel(
      id: 'LOC-001',
      warehouseId: 'WH-001',
      code: 'A-01-01',
      zone: 'A',
      rack: '01',
      bin: '01',
      status: LocationStatus.occupied,
      description: 'Rak elektronik',
    ),
    const WarehouseLocationModel(
      id: 'LOC-002',
      warehouseId: 'WH-001',
      code: 'A-01-02',
      zone: 'A',
      rack: '01',
      bin: '02',
      status: LocationStatus.available,
      description: 'Rak elektronik',
    ),
    const WarehouseLocationModel(
      id: 'LOC-003',
      warehouseId: 'WH-001',
      code: 'A-02-01',
      zone: 'A',
      rack: '02',
      bin: '01',
      status: LocationStatus.blocked,
      description: 'Perlu perbaikan',
    ),
    const WarehouseLocationModel(
      id: 'LOC-004',
      warehouseId: 'WH-001',
      code: 'B-01-01',
      zone: 'B',
      rack: '01',
      bin: '01',
      status: LocationStatus.occupied,
      description: 'Bahan baku',
    ),
    const WarehouseLocationModel(
      id: 'LOC-005',
      warehouseId: 'WH-002',
      code: 'A-01-01',
      zone: 'A',
      rack: '01',
      bin: '01',
      status: LocationStatus.available,
    ),
    const WarehouseLocationModel(
      id: 'LOC-006',
      warehouseId: 'WH-002',
      code: 'B-01-01',
      zone: 'B',
      rack: '01',
      bin: '01',
      status: LocationStatus.occupied,
    ),
  ].obs;

  WarehouseModel? get selectedWarehouse => warehouses.firstWhereOrNull(
    (item) => item.id == selectedWarehouseId.value,
  );

  List<WarehouseLocationModel> get currentLocations {
    final query = searchQuery.value.trim().toLowerCase();
    return locations.where((location) {
      final matchesWarehouse =
          location.warehouseId == selectedWarehouseId.value;
      final matchesQuery =
          query.isEmpty ||
          location.code.toLowerCase().contains(query) ||
          location.zone.toLowerCase().contains(query) ||
          location.description.toLowerCase().contains(query);
      final matchesStatus =
          selectedStatus.value == 'Semua' ||
          statusLabel(location.status) == selectedStatus.value;
      return matchesWarehouse && matchesQuery && matchesStatus;
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

  void addWarehouse({
    required String code,
    required String name,
    required String address,
    required bool isActive,
  }) {
    if (warehouses.any((e) => e.code.toLowerCase() == code.toLowerCase())) {
      Get.snackbar('Kode sudah digunakan', 'Gunakan kode gudang yang berbeda.');
      return;
    }
    final id = 'WH-${DateTime.now().microsecondsSinceEpoch}';
    warehouses.add(
      WarehouseModel(
        id: id,
        code: code,
        name: name,
        address: address,
        isActive: isActive,
      ),
    );
    selectedWarehouseId.value = id;
  }

  void updateWarehouse(
    WarehouseModel old, {
    required String code,
    required String name,
    required String address,
    required bool isActive,
  }) {
    final index = warehouses.indexWhere((e) => e.id == old.id);
    if (index < 0) return;
    if (warehouses.any(
      (e) => e.id != old.id && e.code.toLowerCase() == code.toLowerCase(),
    )) {
      Get.snackbar('Kode sudah digunakan', 'Gunakan kode gudang yang berbeda.');
      return;
    }
    warehouses[index] = WarehouseModel(
      id: old.id,
      code: code,
      name: name,
      address: address,
      isActive: isActive,
    );
  }

  void deleteWarehouse(WarehouseModel warehouse) {
    if (locations.any((e) => e.warehouseId == warehouse.id)) {
      Get.snackbar(
        'Tidak dapat menghapus',
        'Gudang masih memiliki lokasi penyimpanan.',
      );
      return;
    }
    if (warehouses.length <= 1) {
      Get.snackbar('Tidak dapat menghapus', 'Minimal harus ada satu gudang.');
      return;
    }
    warehouses.removeWhere((e) => e.id == warehouse.id);
    if (selectedWarehouseId.value == warehouse.id) {
      selectedWarehouseId.value = warehouses.first.id;
    }
  }

  void addLocation({
    required String code,
    required String zone,
    required String rack,
    required String bin,
    required LocationStatus status,
    required String description,
  }) {
    if (locations.any(
      (e) =>
          e.warehouseId == selectedWarehouseId.value &&
          e.code.toLowerCase() == code.toLowerCase(),
    )) {
      Get.snackbar(
        'Lokasi sudah ada',
        'Kode lokasi harus unik di dalam gudang.',
      );
      return;
    }
    locations.add(
      WarehouseLocationModel(
        id: 'LOC-${DateTime.now().microsecondsSinceEpoch}',
        warehouseId: selectedWarehouseId.value,
        code: code,
        zone: zone,
        rack: rack,
        bin: bin,
        status: status,
        description: description,
      ),
    );
  }

  void updateLocation(
    WarehouseLocationModel old, {
    required String code,
    required String zone,
    required String rack,
    required String bin,
    required LocationStatus status,
    required String description,
  }) {
    if (locations.any(
      (e) =>
          e.id != old.id &&
          e.warehouseId == old.warehouseId &&
          e.code.toLowerCase() == code.toLowerCase(),
    )) {
      Get.snackbar(
        'Lokasi sudah ada',
        'Kode lokasi harus unik di dalam gudang.',
      );
      return;
    }
    final index = locations.indexWhere((e) => e.id == old.id);
    if (index < 0) return;
    locations[index] = WarehouseLocationModel(
      id: old.id,
      warehouseId: old.warehouseId,
      code: code,
      zone: zone,
      rack: rack,
      bin: bin,
      status: status,
      description: description,
    );
  }

  void deleteLocation(WarehouseLocationModel location) {
    locations.removeWhere((e) => e.id == location.id);
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
