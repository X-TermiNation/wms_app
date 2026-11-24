import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../application/routes/app_routes.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../products/controllers/products_controller.dart';
import '../models/issuing_model.dart';

/// Pengeluaran barang. Validasi stok AVAILABLE & pemilihan batch FEFO
/// dilakukan backend; aplikasi hanya menampilkan hasilnya.
class IssuingController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;
  final isLoading = false.obs;
  final isBusy = false.obs;

  late final ProductsController productsController;

  final issuings = <IssuingModel>[].obs;

  String get warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void onInit() {
    super.onInit();
    productsController = Get.find<ProductsController>();
    fetchIssuings();
  }

  Future<void> fetchIssuings() async {
    isLoading.value = true;
    try {
      issuings.assignAll(await _api.getList('/issuings', IssuingModel.fromJson, query: {'warehouseId': warehouseId}));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat pengeluaran');
    } finally {
      isLoading.value = false;
    }
  }

  List<IssuingModel> get filteredIssuings {
    final query = searchQuery.value.trim().toLowerCase();
    return issuings.where((record) {
      final statusMatch = selectedStatus.value == 'Semua' || statusLabel(record.status) == selectedStatus.value;
      final queryMatch = query.isEmpty || record.number.toLowerCase().contains(query) ||
          record.destination.toLowerCase().contains(query) ||
          record.allocations.any((a) => a.batchNumber.toLowerCase().contains(query));
      return statusMatch && queryMatch;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  int get totalTransactions => issuings.length;
  int get pendingCount => issuings.where((e) => e.status == IssuingStatus.pending || e.status == IssuingStatus.draft).length;
  int get completedCount => issuings.where((e) => e.status == IssuingStatus.completed).length;
  int get totalIssuedQuantity => issuings.where((e) => e.status == IssuingStatus.completed)
      .fold(0, (sum, e) => sum + e.totalQuantity);

  void updateSearch(String value) => searchQuery.value = value;

  void _upsert(IssuingModel record) {
    final index = issuings.indexWhere((e) => e.id == record.id);
    if (index >= 0) {
      issuings[index] = record;
    } else {
      issuings.add(record);
    }
  }

  /// [complete] = langsung keluarkan stok (FEFO). Mengembalikan transaksi atau null jika gagal.
  Future<IssuingModel?> createIssuing({
    required String destination,
    required DateTime date,
    required List<IssuingItemModel> items,
    required String notes,
    required bool complete,
    required String idempotencyKey,
    String? outboundDocumentId,
  }) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final data = await _api.post('/issuings', {
        'destination': destination.trim(),
        'warehouseId': warehouseId,
        'date': ApiClient.formatDate(date),
        'status': complete ? 'completed' : 'pending',
        'notes': notes.trim(),
        'items': items.map((e) => e.toJson()).toList(),
        // Picking terhadap dokumen SO ERP: tujuan = customer SO, qty dicek terhadap sisa SO, hasil dikirim ke ERP.
        'outboundDocumentId': outboundDocumentId,
      }, idempotencyKey);
      final record = IssuingModel.fromJson(data as Map<String, dynamic>);
      _upsert(record);
      if (record.status == IssuingStatus.completed) await productsController.reloadProductsSilently();
      return record;
    } catch (e) {
      showApiError(e, title: 'Pengeluaran gagal');
      return null;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> changeStatus(IssuingModel record, IssuingStatus status) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final data = await _api.patch('/issuings/${record.id}/status', {'status': status.name}, _api.newIdempotencyKey());
      final updated = IssuingModel.fromJson(data as Map<String, dynamic>);
      _upsert(updated);
      if (status == IssuingStatus.completed) {
        await productsController.reloadProductsSilently();
        await showAllocations(updated);
      }
    } catch (e) {
      showApiError(e, title: status == IssuingStatus.completed ? 'Stok tidak mencukupi' : 'Tidak dapat diproses');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> deleteDraft(IssuingModel record) async {
    await runApi(() async {
      if (record.status == IssuingStatus.pending) {
        await _api.patch('/issuings/${record.id}/status', {'status': 'draft'});
      }
      await _api.delete('/issuings/${record.id}');
      issuings.removeWhere((e) => e.id == record.id);
    }, errorTitle: 'Tidak dapat dihapus');
  }

  /// Tampilkan batch yang dipilih backend (FEFO).
  static Future<void> showAllocations(IssuingModel r) => Get.dialog(AlertDialog(
    title: Text('Pengeluaran ${r.number} selesai'),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(shrinkWrap: true, children: [
        const Text('Batch dipilih otomatis (FEFO: expiry terdekat lebih dulu):', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        ...r.allocations.map((a) {
          final item = r.items.firstWhereOrNull((i) => i.productId == a.productId);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${item?.productName ?? ''} • ${a.quantity} ${item?.unit ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Batch ${a.batchNumber} • ${a.locationCode}${a.expiryDate == null ? '' : ' • ED ${formatDate(a.expiryDate!)}'}'),
          );
        }),
      ]),
    ),
    actions: [
      TextButton(onPressed: Get.back, child: const Text('Nanti')),
      // Alur pengiriman: barang hasil picking langsung dikemas ke koli.
      if (r.shippingStatus == 'PICKED')
        FilledButton.icon(
          onPressed: () {
            Get.back();
            Get.toNamed(AppRoutes.packing);
          },
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Lanjut Packing'),
        )
      else
        FilledButton(onPressed: Get.back, child: const Text('OK')),
    ],
  ));

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
