import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/helpers/api_feedback.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';

/// QC Inspection: scan batch di area QC -> isi hasil PASS / FAIL / HOLD (boleh parsial).
/// Recheck barang HOLD memakai halaman yang sama (argumen: InventoryBalance QC_HOLD).
class QcInspectionController extends GetxController {
  final _repo = InventoryRepository.instance;
  final _ctx = WarehouseContext.instance;

  static const inspectableStatuses = [InventoryStatus.qcPending, InventoryStatus.qcInProgress, InventoryStatus.qcHold];

  final queue = <InventoryBalance>[].obs;
  final selected = Rxn<InventoryBalance>();
  final history = <QcInspection>[].obs;
  final passed = 0.obs;
  final failed = 0.obs;
  final held = 0.obs;
  final recheck = false.obs;
  final rejectionReason = TextEditingController();
  final holdReason = TextEditingController();
  final notes = TextEditingController();
  final isLoading = false.obs;
  final isBusy = false.obs;

  late String _idempotencyKey;
  ScanRegistration? _scan;

  String get warehouseId => _ctx.activeId.value;
  bool get canInspect => _ctx.canInspect;
  int get total => passed.value + failed.value + held.value;

  @override
  void onInit() {
    super.onInit();
    _idempotencyKey = ApiClient.instance.newIdempotencyKey();
    _scan = ScannerService.instance.register(onScan, label: 'QC Inspection');
    final arg = Get.arguments;
    if (arg is InventoryBalance) select(arg);
    loadQueue();
  }

  @override
  void onClose() {
    _scan?.cancel();
    rejectionReason.dispose();
    holdReason.dispose();
    notes.dispose();
    super.onClose();
  }

  Future<void> loadQueue() async {
    if (warehouseId.isEmpty) return;
    isLoading.value = true;
    try {
      queue.assignAll(await _repo.balances(
        warehouseId: warehouseId,
        statuses: [InventoryStatus.qcPending, InventoryStatus.qcInProgress],
      ));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat antrean QC');
    } finally {
      isLoading.value = false;
    }
  }

  void select(InventoryBalance balance) {
    selected.value = balance;
    passed.value = balance.quantity;
    failed.value = 0;
    held.value = 0;
    recheck.value = false;
    rejectionReason.clear();
    holdReason.clear();
    _loadHistory(balance.lotId);
  }

  void reset() {
    selected.value = null;
    history.clear();
  }

  Future<void> _loadHistory(String lotId) async {
    try {
      history.assignAll(await _repo.inspections(lotId: lotId));
    } catch (_) {
      history.clear();
    }
  }

  Future<void> onScan(String code) async {
    try {
      final result = await _repo.scan(code, warehouseId: warehouseId);
      if (result.type != ScanType.batch) {
        ScanFeedback.error();
        Get.snackbar('QC Inspection', 'Scan barcode batch internal (bukan barcode item/lokasi).', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final options = result.balances.where((b) => inspectableStatuses.contains(b.status)).toList();
      if (options.isEmpty) {
        ScanFeedback.error();
        Get.snackbar('QC Inspection', 'Batch ${result.batch!.batchNumber} tidak sedang berada di proses QC.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      InventoryBalance? choice = options.first;
      if (options.length > 1) {
        choice = await Get.dialog<InventoryBalance>(SimpleDialog(
          title: const Text('Pilih qty yang diperiksa'),
          children: options.map((b) => SimpleDialogOption(
            onPressed: () => Get.back(result: b),
            child: Text('${b.locationCode} • ${InventoryStatus.label(b.status)} • ${b.quantity} ${b.unit}'),
          )).toList(),
        ));
      }
      if (choice != null) {
        ScanFeedback.success();
        select(choice);
      }
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Scan tidak dapat diproses');
    }
  }

  /// Saat salah satu angka diubah, sisa qty otomatis masuk PASS agar total tetap konsisten.
  void setFailed(int v) {
    final max = selected.value?.quantity ?? 0;
    failed.value = v.clamp(0, max - held.value);
    passed.value = (max - failed.value - held.value).clamp(0, max);
  }

  void setHeld(int v) {
    final max = selected.value?.quantity ?? 0;
    held.value = v.clamp(0, max - failed.value);
    passed.value = (max - failed.value - held.value).clamp(0, max);
  }

  void setPassed(int v) {
    final max = selected.value?.quantity ?? 0;
    passed.value = v.clamp(0, max - failed.value - held.value);
  }

  String? validate() {
    final s = selected.value;
    if (s == null) return 'Scan batch yang akan diperiksa.';
    if (total <= 0) return 'Isi hasil pemeriksaan.';
    if (total > s.quantity) return 'Total hasil ($total) melebihi qty yang diperiksa (${s.quantity}).';
    if (failed.value > 0 && rejectionReason.text.trim().isEmpty) return 'Alasan penolakan wajib diisi untuk barang FAIL.';
    if (held.value > 0 && holdReason.text.trim().isEmpty) return 'Alasan HOLD wajib diisi.';
    if (recheck.value && held.value == 0) return 'Hasil RECHECK memerlukan jumlah HOLD.';
    return null;
  }

  Future<void> submit() async {
    final error = validate();
    if (error != null) {
      ScanFeedback.error();
      Get.snackbar('Data belum lengkap', error, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final s = selected.value!;
    final sisa = s.quantity - total;
    final confirmed = await Get.dialog<bool>(AlertDialog(
      title: const Text('Simpan hasil QC?'),
      content: Text(
        'Batch ${s.batchNumber}\n'
        'PASS ${passed.value} → QC-PASS (belum AVAILABLE)\n'
        'FAIL ${failed.value} → QC-REJECT\n'
        'HOLD ${held.value} → QC-HOLD'
        '${sisa > 0 ? '\nBelum diperiksa: $sisa ${s.unit} (tetap di ${s.locationCode})' : ''}',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('Simpan')),
      ],
    ));
    if (confirmed != true) return;
    isBusy.value = true;
    try {
      final record = await _repo.inspect(
        warehouseId: warehouseId,
        source: s,
        passed: passed.value,
        failed: failed.value,
        held: held.value,
        recheck: recheck.value,
        rejectionReason: rejectionReason.text.trim(),
        holdReason: holdReason.text.trim(),
        notes: notes.text.trim(),
        idempotencyKey: _idempotencyKey,
      );
      ScanFeedback.success();
      showSuccess('QC tersimpan (${record.number})',
          'Hasil ${record.result}: PASS ${record.quantityPassed}, FAIL ${record.quantityFailed}, HOLD ${record.quantityHeld}. Barang PASS perlu QC Release ke rak.');
      _idempotencyKey = ApiClient.instance.newIdempotencyKey();
      notes.clear();
      reset();
      await loadQueue();
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Gagal menyimpan hasil QC');
    } finally {
      isBusy.value = false;
    }
  }
}
