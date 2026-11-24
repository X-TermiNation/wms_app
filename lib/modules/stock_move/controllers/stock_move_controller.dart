import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/helpers/api_feedback.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';

/// Tiga workflow perpindahan stok dengan pola yang sama:
/// scan batch -> scan lokasi tujuan -> qty -> konfirmasi.
enum StockMoveMode {
  putaway(
    title: 'Putaway',
    endpoint: '/putaways',
    sourceStatuses: [InventoryStatus.received],
    pendingStatuses: [InventoryStatus.received],
    destinationTypes: ['STORAGE'],
    resultStatus: InventoryStatus.available,
    icon: Icons.move_down_rounded,
    hint: 'Barang dari area receiving (tanpa QC) dipindahkan ke rak. Setelah putaway, stok menjadi AVAILABLE.',
  ),
  qcTransfer(
    title: 'QC Transfer',
    endpoint: '/qc/transfer',
    sourceStatuses: [InventoryStatus.received, InventoryStatus.available, InventoryStatus.qcPending],
    pendingStatuses: [InventoryStatus.received],
    destinationTypes: ['QC_HOLD', 'QC_INSPECTION', 'QC_QUARANTINE'],
    resultStatus: InventoryStatus.qcPending,
    icon: Icons.science_outlined,
    hint: 'Ambil sebagian / seluruh qty batch ke area QC. Batch tetap sama; sisa qty tetap di lokasi asal.',
  ),
  qcRelease(
    title: 'QC Release',
    endpoint: '/qc/release',
    sourceStatuses: [InventoryStatus.qcPassed],
    pendingStatuses: [InventoryStatus.qcPassed],
    destinationTypes: ['STORAGE'],
    resultStatus: InventoryStatus.available,
    icon: Icons.verified_outlined,
    hint: 'Barang lolos QC baru menjadi AVAILABLE setelah discan dan dipindahkan ke rak penyimpanan.',
  );

  const StockMoveMode({
    required this.title,
    required this.endpoint,
    required this.sourceStatuses,
    required this.pendingStatuses,
    required this.destinationTypes,
    required this.resultStatus,
    required this.icon,
    required this.hint,
  });

  final String title, endpoint, resultStatus, hint;
  final List<String> sourceStatuses, pendingStatuses, destinationTypes;
  final IconData icon;

  String get destinationLabel => destinationTypes.map(LocationInfo.typeLabel).join(' / ');
}

class StockMoveController extends GetxController {
  StockMoveController(this.mode);

  final StockMoveMode mode;
  final _repo = InventoryRepository.instance;
  final _ctx = WarehouseContext.instance;

  final pending = <InventoryBalance>[].obs;
  final selected = Rxn<InventoryBalance>();
  final destination = Rxn<LocationInfo>();
  final quantity = 0.obs;
  final notesController = TextEditingController();
  final isLoading = false.obs;
  final isBusy = false.obs;

  late String _idempotencyKey;
  ScanRegistration? _scan;

  String get warehouseId => _ctx.activeId.value;

  @override
  void onInit() {
    super.onInit();
    _idempotencyKey = ApiClient.instance.newIdempotencyKey();
    _scan = ScannerService.instance.register(onScan, label: mode.title);
    loadPending();
  }

  @override
  void onClose() {
    _scan?.cancel();
    notesController.dispose();
    super.onClose();
  }

  Future<void> loadPending() async {
    if (warehouseId.isEmpty) return;
    isLoading.value = true;
    try {
      pending.assignAll(await _repo.balances(warehouseId: warehouseId, statuses: mode.pendingStatuses));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat daftar');
    } finally {
      isLoading.value = false;
    }
  }

  void selectSource(InventoryBalance balance) {
    if (!mode.sourceStatuses.contains(balance.status)) {
      _fail('Status ${InventoryStatus.shortLabel(balance.status)} tidak dapat diproses di menu ${mode.title}.');
      return;
    }
    selected.value = balance;
    quantity.value = balance.quantity;
    if (destination.value != null && destination.value!.id == balance.locationId) destination.value = null;
    ScanFeedback.success();
  }

  void resetSource() {
    selected.value = null;
    destination.value = null;
    quantity.value = 0;
  }

  /// Konteks scan halaman ini: batch (atau produk) dulu, lalu lokasi tujuan.
  Future<void> onScan(String code) async {
    if (warehouseId.isEmpty) return _fail('Pilih gudang aktif terlebih dahulu.');
    try {
      final result = await _repo.scan(code, warehouseId: warehouseId);
      switch (result.type) {
        case ScanType.location:
          final loc = result.location!;
          if (selected.value == null) return _fail('Scan barcode batch terlebih dahulu, lalu scan lokasi tujuan.');
          if (!mode.destinationTypes.contains(loc.type)) {
            return _fail('Lokasi ${loc.code} bertipe ${LocationInfo.typeLabel(loc.type)}. Tujuan harus ${mode.destinationLabel}.');
          }
          if (!loc.isActive || loc.status == 'blocked') return _fail('Lokasi ${loc.code} sedang tidak aktif / diblokir.');
          destination.value = loc;
          ScanFeedback.success();
        case ScanType.batch:
          final options = result.balances.where((b) => b.warehouseId == warehouseId && mode.sourceStatuses.contains(b.status)).toList();
          await _chooseSource(options, 'Batch ${result.batch!.batchNumber}');
        case ScanType.product:
          final options = await _repo.balances(warehouseId: warehouseId, productId: result.product!.id, statuses: mode.sourceStatuses);
          await _chooseSource(options, result.product!.name);
        case ScanType.temporary:
          return _fail('Label sementara ${result.temporary!.number} belum menjadi stok. Selesaikan registrasi & penerimaan terlebih dahulu.');
      }
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Scan tidak dapat diproses');
    }
  }

  Future<void> _chooseSource(List<InventoryBalance> options, String label) async {
    if (options.isEmpty) {
      return _fail('$label tidak memiliki stok berstatus ${mode.sourceStatuses.map(InventoryStatus.shortLabel).join(' / ')} di gudang ini.');
    }
    if (options.length == 1) return selectSource(options.first);
    final choice = await Get.bottomSheet<InventoryBalance>(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * .7),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Pilih lokasi/status asal – $label', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            ...options.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: const Color(0xFFF7F7F7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                title: Text('${b.batchNumber} • ${b.locationCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text('${InventoryStatus.label(b.status)} • ${b.quantity} ${b.unit}${b.expiryDate == null ? '' : ' • ED ${formatDate(b.expiryDate)}'}'),
                onTap: () => Get.back(result: b),
              ),
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    if (choice != null) selectSource(choice);
  }

  void _fail(String message) {
    ScanFeedback.error();
    Get.snackbar(mode.title, message, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
  }

  bool get canSubmit => selected.value != null && destination.value != null && quantity.value > 0 && !isBusy.value;

  Future<void> submit() async {
    final source = selected.value;
    final dest = destination.value;
    if (source == null || dest == null) return;
    final ok = await _confirm(source, dest);
    if (!ok) return;
    isBusy.value = true;
    try {
      final result = await _repo.move(
        mode.endpoint,
        warehouseId: warehouseId,
        source: source,
        destination: dest,
        quantity: quantity.value,
        notes: notesController.text.trim(),
        idempotencyKey: _idempotencyKey,
      );
      ScanFeedback.success();
      showSuccess('${mode.title} berhasil',
          '${result['quantity']} ${result['unit']} batch ${result['batchNumber']} → ${result['toLocationCode']} (${InventoryStatus.shortLabel(result['toStatus'] as String)}). No: ${result['number']}');
      _idempotencyKey = ApiClient.instance.newIdempotencyKey();
      notesController.clear();
      resetSource();
      await loadPending();
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: '${mode.title} gagal');
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> _confirm(InventoryBalance s, LocationInfo d) async {
    final result = await Get.dialog<bool>(AlertDialog(
      title: Text('Konfirmasi ${mode.title}'),
      content: Text(
        '${quantity.value} ${s.unit} ${s.productName}\n'
        'Batch ${s.batchNumber}\n'
        '${s.locationCode} (${InventoryStatus.shortLabel(s.status)}) → ${d.code} (${InventoryStatus.shortLabel(_resultStatus(d))})',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('Konfirmasi')),
      ],
    ));
    return result == true;
  }

  String _resultStatus(LocationInfo d) => mode == StockMoveMode.qcTransfer && d.type == 'QC_INSPECTION'
      ? InventoryStatus.qcInProgress
      : mode.resultStatus;
}
