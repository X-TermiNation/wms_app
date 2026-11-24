import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../../warehouse/models/warehouse_model.dart';
import '../models/transfer_model.dart';

/// Transfer antar gudang/cabang: kirim (IN_TRANSIT) lalu diterima gudang tujuan.
class TransferController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;
  final isLoading = false.obs;
  final isBusy = false.obs;

  late final ProductsController products;
  late final WarehouseController warehouses;

  final transfers = <TransferModel>[].obs;

  String get warehouseId => WarehouseContext.instance.activeId.value;

  /// Gudang tujuan yang boleh dipilih (semua gudang aktif selain gudang aktif).
  List<WarehouseModel> get destinationOptions => warehouses.allWarehouses.where((w) => w.id != warehouseId && w.isActive).toList();

  @override
  void onInit() {
    super.onInit();
    products = Get.find<ProductsController>();
    warehouses = Get.find<WarehouseController>();
    if (warehouses.allWarehouses.isEmpty) warehouses.fetchAll();
    fetchTransfers();
  }

  Future<void> fetchTransfers() async {
    isLoading.value = true;
    try {
      transfers.assignAll(await _api.getList('/transfers', TransferModel.fromJson, query: {'warehouseId': warehouseId}));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat transfer');
    } finally {
      isLoading.value = false;
    }
  }

  bool isInbound(TransferModel t) => t.destinationWarehouseId == warehouseId;

  List<TransferModel> get filteredTransfers {
    final query = searchQuery.value.trim().toLowerCase();
    return transfers.where((t) {
      final statusOk = selectedStatus.value == 'Semua' ||
          (selectedStatus.value == 'Perlu Diterima' ? isInbound(t) && t.status == TransferStatus.inTransit : statusLabel(t.status) == selectedStatus.value);
      final queryOk = query.isEmpty ||
          t.number.toLowerCase().contains(query) ||
          t.sourceWarehouseName.toLowerCase().contains(query) ||
          t.destinationWarehouseName.toLowerCase().contains(query) ||
          t.lots.any((l) => l.batchNumber.toLowerCase().contains(query));
      return statusOk && queryOk;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get completedCount => transfers.where((t) => t.status == TransferStatus.completed).length;
  int get inboundPending => transfers.where((t) => isInbound(t) && t.status == TransferStatus.inTransit).length;
  int get totalMoved => transfers.where((t) => t.status == TransferStatus.completed).fold(0, (sum, t) => sum + t.totalQuantity);

  void updateSearch(String value) => searchQuery.value = value;

  void _upsert(TransferModel record) {
    final index = transfers.indexWhere((t) => t.id == record.id);
    if (index >= 0) {
      transfers[index] = record;
    } else {
      transfers.add(record);
    }
  }

  /// Simpan transfer; [ship] = langsung kirim (stok AVAILABLE gudang asal -> IN_TRANSIT).
  Future<TransferModel?> createTransfer({
    required String destinationId,
    required DateTime date,
    required List<TransferItemModel> items,
    required String notes,
    required bool ship,
    required String idempotencyKey,
  }) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final data = await _api.post('/transfers', {
        'sourceWarehouseId': warehouseId,
        'destinationWarehouseId': destinationId,
        'date': ApiClient.formatDate(date),
        'status': 'pending',
        'notes': notes.trim(),
        'items': items.map((e) => e.toJson()).toList(),
      }, idempotencyKey);
      var record = TransferModel.fromJson(data as Map<String, dynamic>);
      _upsert(record);
      if (ship) {
        final shipped = await _api.post('/transfers/${record.id}/ship', null, '$idempotencyKey:ship');
        record = TransferModel.fromJson(shipped as Map<String, dynamic>);
        _upsert(record);
        await products.reloadProductsSilently();
      }
      return record;
    } catch (e) {
      showApiError(e, title: 'Transfer gagal');
      await fetchTransfers();
      return null;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> ship(TransferModel record) => _run(() async {
    final data = await _api.post('/transfers/${record.id}/ship', null, _api.newIdempotencyKey());
    _upsert(TransferModel.fromJson(data as Map<String, dynamic>));
    await products.reloadProductsSilently();
    showSuccess('Transfer dikirim', '${record.number} berstatus IN TRANSIT sampai diterima ${record.destinationWarehouseName}.');
  });

  Future<void> cancel(TransferModel record) => _run(() async {
    final data = await _api.patch('/transfers/${record.id}/status', {'status': 'cancelled'});
    _upsert(TransferModel.fromJson(data as Map<String, dynamic>));
  });

  Future<void> deleteDraft(TransferModel record) => _run(() async {
    if (record.status == TransferStatus.pending) {
      await _api.patch('/transfers/${record.id}/status', {'status': 'draft'});
    }
    await _api.delete('/transfers/${record.id}');
    transfers.removeWhere((t) => t.id == record.id);
  });

  /// Konfirmasi penerimaan di gudang tujuan. Mengembalikan true jika berhasil.
  Future<bool> receive(TransferModel record, List<Map<String, dynamic>> items, String idempotencyKey) async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      final data = await _api.post('/transfers/${record.id}/receive', {'items': items}, idempotencyKey);
      final updated = TransferModel.fromJson(data as Map<String, dynamic>);
      _upsert(updated);
      await products.reloadProductsSilently();
      showSuccess('Penerimaan transfer dicatat',
          updated.status == TransferStatus.completed ? 'Seluruh barang diterima. Transfer selesai.' : 'Sisa ${updated.remainingQuantity} unit masih IN TRANSIT.');
      return true;
    } catch (e) {
      showApiError(e, title: 'Penerimaan gagal');
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      await action();
    } catch (e) {
      showApiError(e);
    } finally {
      isBusy.value = false;
    }
  }

  static String statusLabel(TransferStatus status) => switch (status) {
    TransferStatus.draft => 'Draft',
    TransferStatus.pending => 'Pending',
    TransferStatus.inTransit => 'In Transit',
    TransferStatus.completed => 'Completed',
    TransferStatus.cancelled => 'Cancelled',
  };

  static Color statusColor(TransferStatus status) => switch (status) {
    TransferStatus.draft => Colors.grey,
    TransferStatus.pending => AppColors.warning,
    TransferStatus.inTransit => const Color(0xFF6B5BD2),
    TransferStatus.completed => AppColors.success,
    TransferStatus.cancelled => AppColors.danger,
  };

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
