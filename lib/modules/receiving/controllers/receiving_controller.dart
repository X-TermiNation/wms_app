
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../products/controllers/products_controller.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../models/receiving_model.dart';

class ReceivingController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;

  late final ProductsController productsController;
  late final WarehouseController warehouseController;

  final receivings = <ReceivingModel>[
    ReceivingModel(
      id: 'RCV-001',
      number: 'RCV-2026-001',
      date: DateTime(2026, 11, 8),
      supplier: 'PT Sumber Elektronik',
      warehouseId: 'WH-001',
      warehouseName: 'Gudang Utama',
      status: ReceivingStatus.completed,
      items: const [
        ReceivingItemModel(productId: '1', productName: 'Kabel USB Type-C', sku: 'ELK-001', unit: 'PCS', quantity: 50),
        ReceivingItemModel(productId: '2', productName: 'Adaptor 20W', sku: 'ELK-002', unit: 'PCS', quantity: 20),
      ],
      notes: 'Penerimaan sesuai purchase order.',
    ),
    ReceivingModel(
      id: 'RCV-002',
      number: 'RCV-2026-002',
      date: DateTime(2026, 11, 9),
      supplier: 'CV Perkakas Jaya',
      warehouseId: 'WH-002',
      warehouseName: 'Gudang Surabaya',
      status: ReceivingStatus.pending,
      items: const [
        ReceivingItemModel(productId: '3', productName: 'Obeng Set', sku: 'PRT-001', unit: 'SET', quantity: 12),
      ],
    ),
    ReceivingModel(
      id: 'RCV-003',
      number: 'RCV-2026-003',
      date: DateTime(2026, 11, 10),
      supplier: 'PT Kemasan Mandiri',
      warehouseId: 'WH-001',
      warehouseName: 'Gudang Utama',
      status: ReceivingStatus.draft,
      items: const [
        ReceivingItemModel(productId: '5', productName: 'Kardus Sedang', sku: 'KMS-001', unit: 'PCS', quantity: 100),
      ],
    ),
  ].obs;

  @override
  void onInit() {
    super.onInit();
    productsController = Get.find<ProductsController>();
    warehouseController = Get.find<WarehouseController>();
  }

  List<ReceivingModel> get filteredReceivings {
    final q = searchQuery.value.trim().toLowerCase();
    return receivings.where((r) {
      final statusMatch = selectedStatus.value == 'Semua' ||
          statusLabel(r.status) == selectedStatus.value;
      final queryMatch = q.isEmpty ||
          r.number.toLowerCase().contains(q) ||
          r.supplier.toLowerCase().contains(q) ||
          r.warehouseName.toLowerCase().contains(q);
      return statusMatch && queryMatch;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int get totalItems => receivings.length;
  int get pendingCount => receivings.where((e) => e.status == ReceivingStatus.pending).length;
  int get completedCount => receivings.where((e) => e.status == ReceivingStatus.completed).length;
  int get totalReceivedQuantity => receivings
      .where((e) => e.status == ReceivingStatus.completed)
      .fold(0, (sum, e) => sum + e.totalQuantity);

  void updateSearch(String value) => searchQuery.value = value;

  void createReceiving({
    required String supplier,
    required String warehouseId,
    required DateTime date,
    required List<ReceivingItemModel> items,
    required String notes,
    required ReceivingStatus status,
  }) {
    final warehouse = warehouseController.warehouses.firstWhereOrNull((w) => w.id == warehouseId);
    if (warehouse == null) {
      Get.snackbar('Gudang tidak ditemukan', 'Pilih gudang tujuan yang valid.');
      return;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final number = 'RCV-${date.year}-${(receivings.length + 1).toString().padLeft(3, '0')}';
    final record = ReceivingModel(
      id: id,
      number: number,
      date: date,
      supplier: supplier,
      warehouseId: warehouseId,
      warehouseName: warehouse.name,
      status: status,
      items: List.unmodifiable(items),
      notes: notes,
    );
    receivings.add(record);
    if (status == ReceivingStatus.completed) _applyStock(record);
  }

  void changeStatus(ReceivingModel receiving, ReceivingStatus status) {
    if (receiving.status == ReceivingStatus.completed || receiving.status == ReceivingStatus.cancelled) {
      Get.snackbar('Status terkunci', 'Transaksi selesai atau dibatalkan tidak dapat diubah.');
      return;
    }
    final index = receivings.indexWhere((e) => e.id == receiving.id);
    if (index < 0) return;
    receivings[index] = receiving.copyWith(status: status);
    if (status == ReceivingStatus.completed) _applyStock(receiving);
  }

  void deleteDraft(ReceivingModel receiving) {
    if (receiving.status != ReceivingStatus.draft) {
      Get.snackbar('Tidak dapat dihapus', 'Hanya transaksi Draft yang dapat dihapus.');
      return;
    }
    receivings.removeWhere((e) => e.id == receiving.id);
  }

  void _applyStock(ReceivingModel receiving) {
    for (final item in receiving.items) {
      final index = productsController.products.indexWhere((p) => p.id == item.productId);
      if (index < 0) continue;
      final old = productsController.products[index];
      productsController.products[index] = ProductModel(
        id: old.id, sku: old.sku, barcode: old.barcode, name: old.name,
        category: old.category, unit: old.unit, stock: old.stock + item.quantity,
        minimumStock: old.minimumStock, location: old.location,
      );
    }
    Get.snackbar('Penerimaan selesai', 'Stok produk berhasil diperbarui dari transaksi ini.',
      snackPosition: SnackPosition.BOTTOM);
  }

  static String statusLabel(ReceivingStatus status) {
    switch (status) {
      case ReceivingStatus.draft: return 'Draft';
      case ReceivingStatus.pending: return 'Pending';
      case ReceivingStatus.completed: return 'Completed';
      case ReceivingStatus.cancelled: return 'Cancelled';
    }
  }

  static Color statusColor(ReceivingStatus status) {
    switch (status) {
      case ReceivingStatus.draft: return Colors.grey;
      case ReceivingStatus.pending: return AppColors.warning;
      case ReceivingStatus.completed: return AppColors.success;
      case ReceivingStatus.cancelled: return AppColors.danger;
    }
  }

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
