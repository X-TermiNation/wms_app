import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../products/controllers/products_controller.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../models/issuing_model.dart';

class IssuingController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;

  late final ProductsController productsController;
  late final WarehouseController warehouseController;

  final issuings = <IssuingModel>[
    IssuingModel(
      id: 'ISS-001', number: 'ISS-2026-001', date: DateTime(2026, 11, 7),
      destination: 'Produksi - Line A', warehouseId: 'WH-001', warehouseName: 'Gudang Utama',
      status: IssuingStatus.completed,
      items: const [
        IssuingItemModel(productId: '1', productName: 'Kabel USB Type-C', sku: 'ELK-001', unit: 'PCS', quantity: 10),
        IssuingItemModel(productId: '4', productName: 'Baut M8', sku: 'BBK-001', unit: 'BOX', quantity: 2),
      ], notes: 'Pengeluaran untuk kebutuhan produksi.',
    ),
    IssuingModel(
      id: 'ISS-002', number: 'ISS-2026-002', date: DateTime(2026, 11, 9),
      destination: 'Cabang Surabaya', warehouseId: 'WH-002', warehouseName: 'Gudang Surabaya',
      status: IssuingStatus.pending,
      items: const [IssuingItemModel(productId: '3', productName: 'Obeng Set', sku: 'PRT-001', unit: 'SET', quantity: 5)],
    ),
    IssuingModel(
      id: 'ISS-003', number: 'ISS-2026-003', date: DateTime(2026, 11, 10),
      destination: 'Maintenance', warehouseId: 'WH-001', warehouseName: 'Gudang Utama',
      status: IssuingStatus.draft,
      items: const [IssuingItemModel(productId: '5', productName: 'Kardus Sedang', sku: 'KMS-001', unit: 'PCS', quantity: 15)],
    ),
  ].obs;

  @override
  void onInit() {
    super.onInit();
    productsController = Get.find<ProductsController>();
    warehouseController = Get.find<WarehouseController>();
  }

  List<IssuingModel> get filteredIssuings {
    final query = searchQuery.value.trim().toLowerCase();
    return issuings.where((record) {
      final statusMatch = selectedStatus.value == 'Semua' || statusLabel(record.status) == selectedStatus.value;
      final queryMatch = query.isEmpty || record.number.toLowerCase().contains(query) ||
          record.destination.toLowerCase().contains(query) || record.warehouseName.toLowerCase().contains(query);
      return statusMatch && queryMatch;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get totalTransactions => issuings.length;
  int get pendingCount => issuings.where((e) => e.status == IssuingStatus.pending).length;
  int get completedCount => issuings.where((e) => e.status == IssuingStatus.completed).length;
  int get totalIssuedQuantity => issuings.where((e) => e.status == IssuingStatus.completed)
      .fold(0, (sum, e) => sum + e.totalQuantity);

  void updateSearch(String value) => searchQuery.value = value;

  String? validateItems(List<IssuingItemModel> items) {
    if (items.isEmpty) return 'Tambahkan minimal satu produk.';
    final totals = <String, int>{};
    for (final item in items) {
      if (item.quantity <= 0) return 'Jumlah produk harus lebih dari nol.';
      totals.update(item.productId, (value) => value + item.quantity, ifAbsent: () => item.quantity);
    }
    for (final entry in totals.entries) {
      final product = productsController.products.firstWhereOrNull((p) => p.id == entry.key);
      if (product == null) return 'Produk tidak ditemukan.';
      if (entry.value > product.stock) {
        return 'Stok ${product.name} tidak cukup. Tersedia ${product.stock} ${product.unit}.';
      }
    }
    return null;
  }

  bool createIssuing({
    required String destination,
    required String warehouseId,
    required DateTime date,
    required List<IssuingItemModel> items,
    required String notes,
    required IssuingStatus status,
  }) {
    final warehouse = warehouseController.warehouses.firstWhereOrNull((w) => w.id == warehouseId);
    if (warehouse == null) {
      Get.snackbar('Gudang tidak ditemukan', 'Pilih gudang asal yang valid.');
      return false;
    }
    final error = validateItems(items);
    if (error != null) {
      Get.snackbar('Data tidak valid', error, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final number = 'ISS-${date.year}-${(issuings.length + 1).toString().padLeft(3, '0')}';
    final record = IssuingModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(), number: number, date: date,
      destination: destination.trim(), warehouseId: warehouseId, warehouseName: warehouse.name,
      status: status, items: List.unmodifiable(items), notes: notes.trim(),
    );
    issuings.add(record);
    if (status == IssuingStatus.completed) _applyStock(record);
    return true;
  }

  void changeStatus(IssuingModel record, IssuingStatus status) {
    if (record.status == IssuingStatus.completed || record.status == IssuingStatus.cancelled) {
      Get.snackbar('Status terkunci', 'Transaksi selesai atau dibatalkan tidak dapat diubah.');
      return;
    }
    if (status == IssuingStatus.completed) {
      final error = validateItems(record.items);
      if (error != null) {
        Get.snackbar('Stok tidak mencukupi', error, snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }
    final index = issuings.indexWhere((e) => e.id == record.id);
    if (index < 0) return;
    issuings[index] = record.copyWith(status: status);
    if (status == IssuingStatus.completed) _applyStock(record);
  }

  void deleteDraft(IssuingModel record) {
    if (record.status != IssuingStatus.draft) {
      Get.snackbar('Tidak dapat dihapus', 'Hanya transaksi Draft yang dapat dihapus.');
      return;
    }
    issuings.removeWhere((e) => e.id == record.id);
  }

  void _applyStock(IssuingModel record) {
    // Aggregate duplicate product rows before validating/applying stock.
    final quantities = <String, int>{};
    for (final item in record.items) {
      quantities.update(item.productId, (value) => value + item.quantity, ifAbsent: () => item.quantity);
    }
    for (final entry in quantities.entries) {
      final index = productsController.products.indexWhere((p) => p.id == entry.key);
      if (index < 0) continue;
      final old = productsController.products[index];
      productsController.products[index] = ProductModel(
        id: old.id, sku: old.sku, barcode: old.barcode, name: old.name, category: old.category,
        unit: old.unit, stock: old.stock - entry.value, minimumStock: old.minimumStock, location: old.location,
      );
    }
    Get.snackbar('Pengeluaran selesai', 'Stok produk berhasil dikurangi.', snackPosition: SnackPosition.BOTTOM);
  }

  static String statusLabel(IssuingStatus status) {
    switch (status) {
      case IssuingStatus.draft: return 'Draft';
      case IssuingStatus.pending: return 'Pending';
      case IssuingStatus.completed: return 'Completed';
      case IssuingStatus.cancelled: return 'Cancelled';
    }
  }

  static Color statusColor(IssuingStatus status) {
    switch (status) {
      case IssuingStatus.draft: return Colors.grey;
      case IssuingStatus.pending: return AppColors.warning;
      case IssuingStatus.completed: return AppColors.success;
      case IssuingStatus.cancelled: return AppColors.danger;
    }
  }

  static String formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
