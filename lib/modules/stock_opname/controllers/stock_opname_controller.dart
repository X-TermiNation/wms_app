import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../products/controllers/products_controller.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../models/stock_opname_model.dart';

class StockOpnameController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;

  late final ProductsController products;
  late final WarehouseController warehouses;

  final records = <StockOpnameModel>[].obs;

  @override
  void onInit() {
    super.onInit();

    products = Get.find<ProductsController>();
    warehouses = Get.find<WarehouseController>();
  }

  List<StockOpnameModel> get filteredRecords {
    final query = searchQuery.value.trim().toLowerCase();

    return records.where((record) {
      final statusOk =
          selectedStatus.value == 'Semua' ||
          statusLabel(record.status) == selectedStatus.value;

      final queryOk =
          query.isEmpty ||
          record.number.toLowerCase().contains(query) ||
          record.warehouseName.toLowerCase().contains(query);

      return statusOk && queryOk;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get completedCount =>
      records.where((r) => r.status == OpnameStatus.completed).length;

  int get totalDifferences => records
      .where((r) => r.status == OpnameStatus.completed)
      .fold(
        0,
        (sum, record) =>
            sum + record.items.where((item) => item.difference != 0).length,
      );

  void updateSearch(String value) {
    searchQuery.value = value;
  }

  bool createOpname({
    required String warehouseId,
    required DateTime date,
    required List<StockOpnameItemModel> items,
    required String notes,
  }) {
    final warehouse = warehouses.warehouses.firstWhereOrNull(
      (w) => w.id == warehouseId,
    );

    if (warehouse == null) {
      _error('Pilih gudang yang valid.');
      return false;
    }

    if (items.isEmpty) {
      _error('Masukkan minimal satu produk.');
      return false;
    }

    final productIds = items.map((item) => item.productId).toSet();

    if (productIds.length != items.length) {
      _error('Produk yang sama hanya boleh dimasukkan satu kali.');
      return false;
    }

    if (items.any((item) => item.physicalStock < 0)) {
      _error('Stok fisik tidak boleh negatif.');
      return false;
    }

    for (final item in items) {
      final product = products.products.firstWhereOrNull(
        (p) => p.id == item.productId,
      );

      if (product == null) {
        _error('Produk ${item.productName} tidak ditemukan.');
        return false;
      }
    }

    final number =
        'OPN-${date.year}-${(records.length + 1).toString().padLeft(3, '0')}';

    final record = StockOpnameModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      number: number,
      date: date,
      warehouseId: warehouseId,
      warehouseName: warehouse.name,
      status: OpnameStatus.draft,
      items: List.unmodifiable(items),
      notes: notes.trim(),
    );

    records.add(record);

    return true;
  }

  void complete(StockOpnameModel record) {
    if (record.status != OpnameStatus.draft) {
      _error('Hanya Stock Opname Draft yang dapat diselesaikan.');
      return;
    }

    // Tahap 1: validasi semua produk dan stok sistem.
    // Belum ada perubahan data pada tahap ini.
    for (final item in record.items) {
      final product = products.products.firstWhereOrNull(
        (p) => p.id == item.productId,
      );

      if (product == null) {
        _error('Produk ${item.productName} tidak ditemukan.');
        return;
      }

      if (product.stock != item.systemStock) {
        _error(
          'Stok sistem ${item.productName} sudah berubah. '
          'Buat opname ulang agar data akurat.',
        );
        return;
      }
    }

    // Tahap 2: semua validasi lolos, baru perbarui stok.
    for (final item in record.items) {
      final index = products.products.indexWhere((p) => p.id == item.productId);

      if (index < 0) continue;

      final product = products.products[index];

      products.products[index] = ProductModel(
        id: product.id,
        sku: product.sku,
        barcode: product.barcode,
        name: product.name,
        category: product.category,
        unit: product.unit,
        stock: item.physicalStock,
        minimumStock: product.minimumStock,
        location: product.location,
      );
    }

    // Tahap 3: ubah status transaksi.
    final recordIndex = records.indexWhere((r) => r.id == record.id);

    if (recordIndex < 0) {
      _error('Data Stock Opname tidak ditemukan.');
      return;
    }

    records[recordIndex] = record.copyWith(status: OpnameStatus.completed);

    Get.snackbar(
      'Stock Opname selesai',
      'Stok produk berhasil disesuaikan dengan hasil fisik.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void cancel(StockOpnameModel record) {
    if (record.status != OpnameStatus.draft) {
      _error('Hanya Draft yang dapat dibatalkan.');
      return;
    }

    final index = records.indexWhere((r) => r.id == record.id);

    if (index >= 0) {
      records[index] = record.copyWith(status: OpnameStatus.cancelled);
    }
  }

  void deleteDraft(StockOpnameModel record) {
    if (record.status != OpnameStatus.draft) {
      _error('Hanya Draft yang dapat dihapus.');
      return;
    }

    records.removeWhere((r) => r.id == record.id);
  }

  void _error(String message) {
    Get.snackbar(
      'Tidak dapat diproses',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static String statusLabel(OpnameStatus status) {
    return switch (status) {
      OpnameStatus.draft => 'Draft',
      OpnameStatus.completed => 'Completed',
      OpnameStatus.cancelled => 'Cancelled',
    };
  }

  static Color statusColor(OpnameStatus status) {
    return switch (status) {
      OpnameStatus.draft => Colors.grey,
      OpnameStatus.completed => AppColors.success,
      OpnameStatus.cancelled => AppColors.danger,
    };
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
