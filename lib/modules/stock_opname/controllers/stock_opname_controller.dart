import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../products/controllers/products_controller.dart';
import '../models/stock_opname_model.dart';

/// Stock opname per lokasi x batch x status. Draft tidak mengubah stok;
/// penyesuaian terjadi setelah disetujui supervisor/admin (divalidasi backend).
class StockOpnameController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;
  final isLoading = false.obs;
  final isBusy = false.obs;

  late final ProductsController products;

  final records = <StockOpnameModel>[].obs;

  String get warehouseId => WarehouseContext.instance.activeId.value;
  bool get canApprove => WarehouseContext.instance.canApprove;

  @override
  void onInit() {
    super.onInit();
    products = Get.find<ProductsController>();
    fetchRecords();
  }

  Future<void> fetchRecords() async {
    isLoading.value = true;
    try {
      records.assignAll(await _api.getList('/stock-opnames', StockOpnameModel.fromJson, query: {'warehouseId': warehouseId}));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat stock opname');
    } finally {
      isLoading.value = false;
    }
  }

  List<StockOpnameModel> get filteredRecords {
    final query = searchQuery.value.trim().toLowerCase();
    return records.where((record) {
      final statusOk = selectedStatus.value == 'Semua' || statusLabel(record.status) == selectedStatus.value;
      final queryOk = query.isEmpty ||
          record.number.toLowerCase().contains(query) ||
          (record.locationCode ?? '').toLowerCase().contains(query);
      return statusOk && queryOk;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get completedCount => records.where((r) => r.status == OpnameStatus.completed).length;
  int get draftCount => records.where((r) => r.status == OpnameStatus.draft).length;
  int get totalDifferences => records
      .where((r) => r.status == OpnameStatus.completed)
      .fold(0, (sum, record) => sum + record.items.where((item) => item.difference != 0).length);

  void updateSearch(String value) => searchQuery.value = value;

  void _upsert(StockOpnameModel record) {
    final index = records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
  }

  Future<bool> createOpname({
    required String locationId,
    required DateTime date,
    required List<StockOpnameItemModel> items,
    required String notes,
    required String idempotencyKey,
  }) async {
    if (isBusy.value) return false;
    isBusy.value = true;
    try {
      final data = await _api.post('/stock-opnames', {
        'warehouseId': warehouseId,
        'locationId': locationId,
        'date': ApiClient.formatDate(date),
        'notes': notes.trim(),
        'items': items.map((e) => e.toJson()).toList(),
      }, idempotencyKey);
      final record = StockOpnameModel.fromJson(data as Map<String, dynamic>);
      _upsert(record);
      showSuccess('Hasil hitung tersimpan', '${record.number} disimpan sebagai Draft. Stok berubah setelah disetujui supervisor.');
      return true;
    } catch (e) {
      showApiError(e, title: 'Gagal menyimpan opname');
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> complete(StockOpnameModel record) async {
    if (!canApprove) {
      Get.snackbar('Butuh persetujuan', 'Penyesuaian stok hanya dapat disetujui supervisor / admin.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await _run(() async {
      final data = await _api.post('/stock-opnames/${record.id}/complete', null, _api.newIdempotencyKey());
      _upsert(StockOpnameModel.fromJson(data as Map<String, dynamic>));
      await products.reloadProductsSilently();
      showSuccess('Stock Opname disetujui', 'Stok disesuaikan dengan hasil fisik dan tercatat di riwayat.');
    });
  }

  Future<void> cancel(StockOpnameModel record) => _run(() async {
    final data = await _api.post('/stock-opnames/${record.id}/cancel');
    _upsert(StockOpnameModel.fromJson(data as Map<String, dynamic>));
  });

  Future<void> deleteDraft(StockOpnameModel record) => _run(() async {
    await _api.delete('/stock-opnames/${record.id}');
    records.removeWhere((r) => r.id == record.id);
  });

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

  static String statusLabel(OpnameStatus status) => switch (status) {
    OpnameStatus.draft => 'Draft',
    OpnameStatus.completed => 'Completed',
    OpnameStatus.cancelled => 'Cancelled',
  };

  static Color statusColor(OpnameStatus status) => switch (status) {
    OpnameStatus.draft => Colors.grey,
    OpnameStatus.completed => AppColors.success,
    OpnameStatus.cancelled => AppColors.danger,
  };

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
