import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/label_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../products/controllers/products_controller.dart';
import '../models/receiving_model.dart';

class ReceivingController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedStatus = 'Semua'.obs;
  final isLoading = false.obs;
  final isBusy = false.obs;

  late final ProductsController productsController;

  final receivings = <ReceivingModel>[].obs;

  String get warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void onInit() {
    super.onInit();
    productsController = Get.find<ProductsController>();
    fetchReceivings();
  }

  Future<void> fetchReceivings() async {
    isLoading.value = true;
    try {
      receivings.assignAll(await _api.getList('/receivings', ReceivingModel.fromJson, query: {'warehouseId': warehouseId}));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat penerimaan');
    } finally {
      isLoading.value = false;
    }
  }

  List<ReceivingModel> get filteredReceivings {
    final q = searchQuery.value.trim().toLowerCase();
    return receivings.where((r) {
      final statusMatch = selectedStatus.value == 'Semua' ||
          statusLabel(r.status) == selectedStatus.value;
      final queryMatch = q.isEmpty ||
          r.number.toLowerCase().contains(q) ||
          r.supplier.toLowerCase().contains(q) ||
          r.items.any((i) => (i.batchNumber ?? '').toLowerCase().contains(q) || i.productName.toLowerCase().contains(q));
      return statusMatch && queryMatch;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int get totalItems => receivings.length;
  int get pendingCount => receivings.where((e) => e.status == ReceivingStatus.pending || e.status == ReceivingStatus.draft).length;
  int get completedCount => receivings.where((e) => e.status == ReceivingStatus.completed).length;
  int get totalReceivedQuantity => receivings
      .where((e) => e.status == ReceivingStatus.completed)
      .fold(0, (sum, e) => sum + e.totalQuantity);

  void updateSearch(String value) => searchQuery.value = value;

  void _upsert(ReceivingModel record) {
    final index = receivings.indexWhere((e) => e.id == record.id);
    if (index >= 0) {
      receivings[index] = record;
    } else {
      receivings.add(record);
    }
  }

  /// Simpan & konfirmasi penerimaan (backend membuat batch + barcode batch).
  /// [items]: `{productId, quantity}` (base unit) atau `{productId, packageUnit, packageQuantity}` (kemasan,
  /// dikonversi backend), plus `expiryDate` / `supplierLot` opsional.
  /// [temporaryReceivingId]: melanjutkan Temporary Receiving yang sudah disetujui admin.
  /// [inboundDocumentId]: Tally terhadap dokumen PO ERP (supplier dari dokumen; hasil dikirim ke ERP).
  /// Mengembalikan (record, batch) atau null jika gagal. Idempotency-Key mencegah batch ganda saat retry.
  Future<(ReceivingModel, List<CreatedBatch>)?> submit({
    String? supplierId,
    required List<Map<String, dynamic>> items,
    String? temporaryReceivingId,
    String? inboundDocumentId,
    DateTime? date,
    String notes = '',
    required String idempotencyKey,
  }) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      final data = await _api.post('/receivings', {
        'supplierId': supplierId,
        'warehouseId': warehouseId,
        'date': ApiClient.formatDate(date ?? DateTime.now()),
        'status': 'completed',
        'notes': notes,
        'temporaryReceivingId': temporaryReceivingId,
        'inboundDocumentId': inboundDocumentId,
        'items': items,
      }, idempotencyKey) as Map<String, dynamic>;
      final record = ReceivingModel.fromJson(data);
      _upsert(record);
      final batches = ((data['createdBatches'] as List?) ?? const [])
          .map((e) => CreatedBatch.fromJson(e as Map<String, dynamic>))
          .toList();
      if (batches.isNotEmpty) await productsController.reloadProductsSilently();
      return (record, batches);
    } catch (e) {
      showApiError(e, title: 'Gagal menyimpan penerimaan');
      return null;
    } finally {
      isBusy.value = false;
    }
  }

  /// Konfirmasi penerimaan: backend membuat batch + barcode batch, stok masuk
  /// RECEIVING (tanpa QC) atau QC-HOLD (wajib QC). Belum AVAILABLE.
  Future<void> confirm(ReceivingModel receiving) async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final data = await _api.post('/receivings/${receiving.id}/confirm', null, _api.newIdempotencyKey()) as Map<String, dynamic>;
      _upsert(ReceivingModel.fromJson(data));
      final batches = ((data['createdBatches'] as List?) ?? const [])
          .map((e) => CreatedBatch.fromJson(e as Map<String, dynamic>))
          .toList();
      await productsController.reloadProductsSilently();
      await showCreatedBatches(batches, productIds: receiving.items.map((i) => i.productId).toSet().toList());
    } catch (e) {
      showApiError(e, title: 'Konfirmasi gagal');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> cancel(ReceivingModel receiving) async {
    await runApi(() async {
      final data = await _api.patch('/receivings/${receiving.id}/status', {'status': 'cancelled'});
      _upsert(ReceivingModel.fromJson(data as Map<String, dynamic>));
    });
  }

  Future<void> deleteDraft(ReceivingModel receiving) async {
    if (receiving.status != ReceivingStatus.draft && receiving.status != ReceivingStatus.pending) return;
    await runApi(() async {
      if (receiving.status == ReceivingStatus.pending) {
        await _api.patch('/receivings/${receiving.id}/status', {'status': 'draft'});
      }
      await _api.delete('/receivings/${receiving.id}');
      receivings.removeWhere((e) => e.id == receiving.id);
    }, errorTitle: 'Tidak dapat dihapus');
  }

  /// Dialog daftar batch internal yang baru dibuat + pilihan cetak label (batch / produk / keduanya).
  /// Cetak tidak memengaruhi transaksi: batch sudah tersimpan sebelum dialog ini tampil.
  static Future<void> showCreatedBatches(List<CreatedBatch> batches, {List<String> productIds = const []}) => Get.dialog(AlertDialog(
    title: const Text('Penerimaan dikonfirmasi'),
    actionsOverflowDirection: VerticalDirection.up,
    actions: [
      if (productIds.isNotEmpty)
        TextButton.icon(
          onPressed: () => printFromBackend([for (final id in productIds) ('PRODUCT', id)], title: 'Label Produk'),
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text('Label Produk'),
        ),
      if (productIds.isNotEmpty)
        TextButton.icon(
          onPressed: () => printFromBackend([
            for (final b in batches) ('BATCH', b.batchNumber),
            for (final id in productIds) ('PRODUCT', id),
          ], title: 'Label Batch + Produk'),
          icon: const Icon(Icons.layers_outlined),
          label: const Text('Keduanya'),
        ),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () => printFromBackend([for (final b in batches) ('BATCH', b.batchNumber)], title: 'Label Batch'),
        icon: const Icon(Icons.print_rounded),
        label: const Text('Cetak Label Batch'),
      ),
      OutlinedButton(onPressed: Get.back, child: const Text('Selesai')),
    ],
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text('Batch internal dibuat. Cetak dan tempel label barcode batch pada barang.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          ...batches.map((b) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(b.batchNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .5)),
              Text('${b.productName} • ${b.quantity}', style: const TextStyle(fontSize: 12)),
              Text(
                b.status == InventoryStatus.qcPending
                    ? 'Wajib QC → ${b.locationCode} (lanjut QC Inspection)'
                    : 'Di ${b.locationCode} → lanjut Putaway',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InventoryStatus.color(b.status)),
              ),
            ]),
          )),
        ],
      ),
    ),
  ));

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
