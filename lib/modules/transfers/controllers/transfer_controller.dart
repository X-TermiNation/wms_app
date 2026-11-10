import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../models/transfer_model.dart';

class TransferController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;

  late final ProductsController products;
  late final WarehouseController warehouses;

  final transfers = <TransferModel>[].obs;

  @override
  void onInit() {
    super.onInit();

    products = Get.find<ProductsController>();
    warehouses = Get.find<WarehouseController>();

    if (warehouses.warehouses.length >= 2 && products.products.isNotEmpty) {
      transfers.addAll([
        TransferModel(
          id: 'TRF-001',
          number: 'TRF-2026-001',
          date: DateTime(2026, 11, 8),
          sourceWarehouseId: 'WH-001',
          sourceWarehouseName: 'Gudang Utama',
          destinationWarehouseId: 'WH-002',
          destinationWarehouseName: 'Gudang Surabaya',
          status: TransferStatus.completed,
          items: [
            TransferItemModel(
              productId: '1',
              productName: 'Kabel USB Type-C',
              sku: 'ELK-001',
              unit: 'PCS',
              quantity: 12,
            ),
          ],
          notes: 'Distribusi stok cabang.',
        ),
        TransferModel(
          id: 'TRF-002',
          number: 'TRF-2026-002',
          date: DateTime(2026, 11, 10),
          sourceWarehouseId: 'WH-001',
          sourceWarehouseName: 'Gudang Utama',
          destinationWarehouseId: 'WH-003',
          destinationWarehouseName: 'Gudang Jakarta',
          status: TransferStatus.pending,
          items: [
            TransferItemModel(
              productId: '3',
              productName: 'Obeng Set',
              sku: 'PRT-001',
              unit: 'SET',
              quantity: 3,
            ),
          ],
        ),
      ]);
    }
  }

  List<TransferModel> get filteredTransfers {
    final query = searchQuery.value.trim().toLowerCase();

    return transfers.where((transfer) {
      final statusOk =
          selectedStatus.value == 'Semua' ||
          statusLabel(transfer.status) == selectedStatus.value;

      final queryOk =
          query.isEmpty ||
          transfer.number.toLowerCase().contains(query) ||
          transfer.sourceWarehouseName.toLowerCase().contains(query) ||
          transfer.destinationWarehouseName.toLowerCase().contains(query);

      return statusOk && queryOk;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get completedCount =>
      transfers.where((t) => t.status == TransferStatus.completed).length;

  int get totalMoved => transfers
      .where((t) => t.status == TransferStatus.completed)
      .fold(0, (sum, t) => sum + t.totalQuantity);

  void updateSearch(String value) {
    searchQuery.value = value;
  }

  // Menggabungkan jumlah jika produk yang sama dimasukkan lebih dari sekali.
  Map<String, int> _calculateTotals(List<TransferItemModel> items) {
    final totals = <String, int>{};

    for (final item in items) {
      totals.update(
        item.productId,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    return totals;
  }

  // Memastikan semua produk tersedia dan jumlahnya valid.
  bool _validateItems(List<TransferItemModel> items) {
    if (items.isEmpty || items.any((item) => item.quantity <= 0)) {
      _error('Tambahkan produk dengan jumlah lebih dari nol.');
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

    return true;
  }

  // Pemeriksaan ini masih menggunakan stok global produk.
  // Belum memeriksa saldo stok khusus gudang asal.
  bool _validateGlobalStock(List<TransferItemModel> items) {
    final totals = _calculateTotals(items);

    for (final entry in totals.entries) {
      final product = products.products.firstWhereOrNull(
        (p) => p.id == entry.key,
      );

      if (product == null || entry.value > product.stock) {
        _error('Stok ${product?.name ?? 'produk'} tidak mencukupi.');
        return false;
      }
    }

    return true;
  }

  bool createTransfer({
    required String sourceId,
    required String destinationId,
    required DateTime date,
    required List<TransferItemModel> items,
    required String notes,
    required TransferStatus status,
  }) {
    if (sourceId == destinationId) {
      _error('Gudang asal dan tujuan tidak boleh sama.');
      return false;
    }

    final source = warehouses.warehouses.firstWhereOrNull(
      (w) => w.id == sourceId,
    );

    final destination = warehouses.warehouses.firstWhereOrNull(
      (w) => w.id == destinationId,
    );

    if (source == null || destination == null) {
      _error('Pilih gudang asal dan tujuan yang valid.');
      return false;
    }

    if (!_validateItems(items)) {
      return false;
    }

    if (status == TransferStatus.completed && !_validateGlobalStock(items)) {
      return false;
    }

    final number =
        'TRF-${date.year}-${(transfers.length + 1).toString().padLeft(3, '0')}';

    final transfer = TransferModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      number: number,
      date: date,
      sourceWarehouseId: sourceId,
      sourceWarehouseName: source.name,
      destinationWarehouseId: destinationId,
      destinationWarehouseName: destination.name,
      status: status,
      items: List.unmodifiable(items),
      notes: notes.trim(),
    );

    transfers.add(transfer);

    if (status == TransferStatus.completed) {
      _applyTransferStock();
    }

    return true;
  }

  void changeStatus(TransferModel record, TransferStatus newStatus) {
    if (record.status == TransferStatus.completed ||
        record.status == TransferStatus.cancelled) {
      _error('Transaksi selesai atau dibatalkan sudah terkunci.');
      return;
    }

    if (record.status == newStatus) {
      return;
    }

    // Status hanya boleh bergerak dari Draft ke Pending/Cancelled,
    // atau Pending ke Completed/Cancelled.
    final allowed = switch (record.status) {
      TransferStatus.draft => [
        TransferStatus.pending,
        TransferStatus.cancelled,
      ],
      TransferStatus.pending => [
        TransferStatus.completed,
        TransferStatus.cancelled,
      ],
      TransferStatus.completed => <TransferStatus>[],
      TransferStatus.cancelled => <TransferStatus>[],
    };

    if (!allowed.contains(newStatus)) {
      _error('Perubahan status transaksi tidak diperbolehkan.');
      return;
    }

    if (newStatus == TransferStatus.completed) {
      if (!_validateGlobalStock(record.items)) {
        return;
      }
    }

    final index = transfers.indexWhere((t) => t.id == record.id);

    if (index < 0) {
      _error('Data transfer tidak ditemukan.');
      return;
    }

    transfers[index] = record.copyWith(status: newStatus);

    if (newStatus == TransferStatus.completed) {
      _applyTransferStock();
    }
  }

  void _applyTransferStock() {
    // Transfer tidak mengubah total stok global.
    // Fungsi ini belum memindahkan saldo antar gudang karena
    // model stok per gudang belum tersedia.
    Get.snackbar(
      'Transfer selesai',
      'Transaksi transfer berhasil diselesaikan.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void deleteDraft(TransferModel transfer) {
    if (transfer.status != TransferStatus.draft) {
      _error('Hanya transaksi Draft yang dapat dihapus.');
      return;
    }

    transfers.removeWhere((t) => t.id == transfer.id);
  }

  void _error(String message) {
    Get.snackbar(
      'Tidak dapat diproses',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static String statusLabel(TransferStatus status) {
    return switch (status) {
      TransferStatus.draft => 'Draft',
      TransferStatus.pending => 'Pending',
      TransferStatus.completed => 'Completed',
      TransferStatus.cancelled => 'Cancelled',
    };
  }

  static Color statusColor(TransferStatus status) {
    return switch (status) {
      TransferStatus.draft => Colors.grey,
      TransferStatus.pending => AppColors.warning,
      TransferStatus.completed => AppColors.success,
      TransferStatus.cancelled => AppColors.danger,
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
