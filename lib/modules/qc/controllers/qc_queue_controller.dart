import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/routes/app_routes.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';

enum QcQueueMode { hold, rejected }

/// Daftar barang QC HOLD (recheck) atau QC REJECT (tindak lanjut).
class QcQueueController extends GetxController {
  QcQueueController(this.mode);

  final QcQueueMode mode;
  final _repo = InventoryRepository.instance;
  final _ctx = WarehouseContext.instance;

  final items = <InventoryBalance>[].obs;
  final highlightLotId = ''.obs;
  final isLoading = false.obs;
  final isBusy = false.obs;
  ScanRegistration? _scan;

  String get warehouseId => _ctx.activeId.value;
  String get status => mode == QcQueueMode.hold ? InventoryStatus.qcHold : InventoryStatus.qcRejected;
  String get title => mode == QcQueueMode.hold ? 'QC Hold / Recheck' : 'QC Rejected';

  @override
  void onInit() {
    super.onInit();
    _scan = ScannerService.instance.register(onScan, label: title);
    load();
  }

  @override
  void onClose() {
    _scan?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    if (warehouseId.isEmpty) return;
    isLoading.value = true;
    try {
      items.assignAll(await _repo.balances(warehouseId: warehouseId, statuses: [status]));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat data');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onScan(String code) async {
    try {
      final result = await _repo.scan(code, warehouseId: warehouseId);
      if (result.type != ScanType.batch) {
        ScanFeedback.error();
        Get.snackbar(title, 'Scan barcode batch internal.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final match = items.firstWhereOrNull((b) => b.lotId == result.batch!.id);
      if (match == null) {
        ScanFeedback.error();
        Get.snackbar(title, 'Batch ${result.batch!.batchNumber} tidak berstatus ${InventoryStatus.shortLabel(status)}.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      ScanFeedback.success();
      highlightLotId.value = match.lotId;
      open(match);
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Scan tidak dapat diproses');
    }
  }

  void open(InventoryBalance balance) {
    if (mode == QcQueueMode.hold) {
      recheck(balance);
    } else {
      openDisposition(balance);
    }
  }

  Future<void> recheck(InventoryBalance balance) async {
    if (!_ctx.canInspect) {
      Get.snackbar(title, 'Hanya role QC / supervisor / admin yang dapat melakukan pemeriksaan.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Get.toNamed(AppRoutes.qcInspection, arguments: balance);
    await load();
  }

  Future<List<QcInspection>> historyOf(String lotId) => _repo.inspections(lotId: lotId);

  Future<void> openDisposition(InventoryBalance balance) async {
    if (!_ctx.canInspect) {
      Get.snackbar(title, 'Hanya role QC / supervisor / admin yang dapat memproses barang reject.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final result = await Get.dialog<_DispositionInput>(_DispositionDialog(balance: balance), barrierDismissible: false);
    if (result == null) return;
    isBusy.value = true;
    try {
      final data = await _repo.disposition(
        warehouseId: warehouseId,
        source: balance,
        quantity: result.quantity,
        action: result.action,
        reason: result.reason,
        notes: result.notes,
        idempotencyKey: result.idempotencyKey,
      );
      ScanFeedback.success();
      showSuccess('Tindak lanjut tercatat', '${data['action']} ${data['quantity']} ${data['unit']} batch ${data['batchNumber']} (${data['number']}).');
      await load();
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Gagal memproses barang reject');
    } finally {
      isBusy.value = false;
    }
  }
}

class _DispositionInput {
  _DispositionInput(this.action, this.quantity, this.reason, this.notes, this.idempotencyKey);
  final String action, reason, notes, idempotencyKey;
  final int quantity;
}

class _DispositionDialog extends StatefulWidget {
  const _DispositionDialog({required this.balance});
  final InventoryBalance balance;

  @override
  State<_DispositionDialog> createState() => _DispositionDialogState();
}

class _DispositionDialogState extends State<_DispositionDialog> {
  static const actions = {
    'RETURN_TO_SUPPLIER': 'Retur ke Supplier',
    'SCRAP': 'Scrap / Write Off',
    'REWORK': 'Rework / Repair',
    'REINSPECT': 'Reinspeksi',
  };
  String action = 'RETURN_TO_SUPPLIER';
  late int qty = widget.balance.quantity;
  final reason = TextEditingController();
  final notes = TextEditingController();
  final key = ApiClient.instance.newIdempotencyKey();

  @override
  void dispose() {
    reason.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.balance;
    return AlertDialog(
      title: const Text('Tindak lanjut barang reject'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${b.productName}\nBatch ${b.batchNumber} • ${b.quantity} ${b.unit}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: actions.entries.map((e) => ChoiceChip(
            label: Text(e.value, style: const TextStyle(fontSize: 11)),
            selected: action == e.key,
            onSelected: (_) => setState(() => action = e.key),
          )).toList()),
          const SizedBox(height: 6),
          Text(
            action == 'REWORK' || action == 'REINSPECT'
                ? 'Barang kembali ke area QC untuk diperiksa ulang.'
                : 'Barang keluar dari stok gudang dan tercatat di riwayat (tidak dihapus).',
            style: const TextStyle(fontSize: 10.5, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$qty ${b.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            IconButton(onPressed: qty < b.quantity ? () => setState(() => qty++) : null, icon: const Icon(Icons.add_circle_outline)),
          ]),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder(), isDense: true)),
        ]),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            if (reason.text.trim().isEmpty) {
              Get.snackbar('Data belum lengkap', 'Alasan wajib diisi.', snackPosition: SnackPosition.BOTTOM);
              return;
            }
            Get.back(result: _DispositionInput(action, qty, reason.text.trim(), notes.text.trim(), key));
          },
          child: const Text('Proses'),
        ),
      ],
    );
  }
}
