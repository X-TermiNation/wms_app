import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/outbound_item_sheet.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/transfer_controller.dart';
import '../models/transfer_model.dart';

class TransferView extends GetView<TransferController> {
  const TransferView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () => Get.to(() => const TransferFormPage()),
      icon: const Icon(Icons.add),
      label: const Text('Transfer Baru'),
    ),
    body: RefreshIndicator(
      onRefresh: controller.fetchTransfers,
      child: Obx(() {
        final rows = controller.filteredTransfers;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            SummaryBanner(
              icon: Icons.swap_horiz_rounded,
              title: 'Transfer ${WarehouseContext.instance.activeName}',
              value: '${controller.inboundPending} perlu diterima',
              subtitle: '${controller.completedCount} selesai • ${controller.totalMoved} unit dipindahkan',
            ),
            const SizedBox(height: 14),
            AppSearchField(hint: 'Cari nomor, gudang, batch...', controller: controller.searchController, onChanged: controller.updateSearch),
            const SizedBox(height: 10),
            StatusFilterChips(
              options: const ['Semua', 'Perlu Diterima', 'Draft', 'Pending', 'In Transit', 'Completed', 'Cancelled'],
              selected: controller.selectedStatus,
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty && controller.isLoading.value)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              const EmptyState(message: 'Belum ada transaksi transfer.', icon: Icons.swap_horiz_rounded)
            else
              ...rows.map((t) {
                final inbound = controller.isInbound(t);
                return DocumentCard(
                  icon: inbound ? Icons.call_received_rounded : Icons.call_made_rounded,
                  number: t.number,
                  date: '${TransferController.formatDate(t.date)} • ${inbound ? 'MASUK' : 'KELUAR'}',
                  statusLabel: TransferController.statusLabel(t.status),
                  statusColor: TransferController.statusColor(t.status),
                  title: '${t.sourceWarehouseName} → ${t.destinationWarehouseName}',
                  subtitle: t.status == TransferStatus.inTransit ? 'Sisa ${t.remainingQuantity} unit belum diterima' : '${t.items.length} item',
                  trailing: '${t.totalQuantity} unit',
                  onTap: () => _detail(controller, t),
                  menu: _menu(controller, t),
                  onMenu: (a) => _action(controller, t, a),
                );
              }),
          ],
        );
      }),
    ),
  );
}

List<PopupMenuEntry<String>> _menu(TransferController c, TransferModel t) {
  final inbound = c.isInbound(t);
  final open = t.status == TransferStatus.draft || t.status == TransferStatus.pending;
  return [
    if (!inbound && open) const PopupMenuItem(value: 'ship', child: Text('Kirim (IN TRANSIT)')),
    if (inbound && t.status == TransferStatus.inTransit) const PopupMenuItem(value: 'receive', child: Text('Terima barang')),
    if (!inbound && open) const PopupMenuItem(value: 'cancel', child: Text('Batalkan')),
    if (!inbound && open) const PopupMenuItem(value: 'delete', child: Text('Hapus')),
  ];
}

Future<void> _action(TransferController c, TransferModel t, String action) async {
  switch (action) {
    case 'ship':
      if (await confirmAction(
        title: 'Kirim transfer?',
        message: 'Stok AVAILABLE di ${t.sourceWarehouseName} dialokasikan FEFO dan berstatus IN TRANSIT sampai diterima ${t.destinationWarehouseName}.',
        confirmLabel: 'Kirim',
      )) {
        await c.ship(t);
      }
    case 'receive':
      await Get.to(() => TransferReceivePage(transfer: t));
    case 'cancel':
      if (await confirmAction(title: 'Batalkan transfer?', message: '${t.number} akan dibatalkan.', confirmLabel: 'Batalkan', danger: true)) {
        await c.cancel(t);
      }
    case 'delete':
      if (await confirmAction(title: 'Hapus transfer?', message: '${t.number} akan dihapus.', confirmLabel: 'Hapus', danger: true)) {
        await c.deleteDraft(t);
      }
  }
}

void _detail(TransferController c, TransferModel t) {
  final actions = _menu(c, t).whereType<PopupMenuItem<String>>().where((m) => m.value == 'ship' || m.value == 'receive').toList();
  showDetailSheet(
    title: 'Detail Transfer',
    badge: AppStatusBadge(label: TransferController.statusLabel(t.status), color: TransferController.statusColor(t.status)),
    children: [
      InfoRow('Nomor', t.number, bold: true),
      InfoRow('Tanggal', TransferController.formatDate(t.date)),
      InfoRow('Gudang asal', t.sourceWarehouseName),
      InfoRow('Gudang tujuan', t.destinationWarehouseName),
      if (t.notes.isNotEmpty) InfoRow('Catatan', t.notes),
      const SectionTitle('Item'),
      ...t.items.map((i) => ItemLine(
        title: i.productName,
        subtitle: i.batchNumber == null ? '${i.sku} • FEFO otomatis' : '${i.sku} • Batch ${i.batchNumber}',
        trailing: '${i.quantity} ${i.unit}',
      )),
      if (t.lots.isNotEmpty) ...[
        const SectionTitle('Batch dikirim'),
        ...t.lots.map((l) => ItemLine(
          title: '${l.productName} • ${l.batchNumber}',
          subtitle: 'Diterima ${l.receivedQuantity}/${l.quantity}${l.expiryDate == null ? '' : ' • ED ${formatDate(l.expiryDate)}'}',
          trailing: l.remaining > 0 ? 'Sisa ${l.remaining}' : 'Lengkap',
        )),
      ],
    ],
    actions: actions.map((m) => FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      onPressed: () {
        Get.back();
        _action(c, t, m.value!);
      },
      child: Text(m.value == 'ship' ? 'Kirim' : 'Terima Barang'),
    )).toList(),
  );
}

/// Form transfer berbasis scan item / batch.
class TransferFormPage extends StatefulWidget {
  const TransferFormPage({super.key});

  @override
  State<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends State<TransferFormPage> {
  final c = Get.find<TransferController>();
  final notes = TextEditingController();
  final lines = <OutboundLine>[];
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  String? destinationId;
  DateTime date = DateTime.now();
  ScanRegistration? _scan;
  bool _busyScan = false;

  @override
  void initState() {
    super.initState();
    final options = c.destinationOptions;
    destinationId = options.isNotEmpty ? options.first.id : null;
    _scan = ScannerService.instance.register(_onScan, label: 'Transfer form');
  }

  @override
  void dispose() {
    _scan?.cancel();
    notes.dispose();
    super.dispose();
  }

  int _already(String productId, String? lotId) =>
      lines.where((l) => l.productId == productId && (lotId == null || l.lotId == lotId)).fold(0, (s, l) => s + l.quantity);

  void _add(OutboundLine? line) {
    if (line == null) return;
    setState(() {
      final i = lines.indexWhere((l) => l.key == line.key);
      if (i >= 0) {
        final o = lines[i];
        lines[i] = OutboundLine(productId: o.productId, productName: o.productName, sku: o.sku, unit: o.unit,
            quantity: o.quantity + line.quantity, lotId: o.lotId, batchNumber: o.batchNumber);
      } else {
        lines.add(line);
      }
    });
  }

  Future<void> _onScan(String code) async {
    if (_busyScan) return;
    _busyScan = true;
    try {
      _add(await scanOutboundLine(code, warehouseId: c.warehouseId, alreadyAdded: _already));
    } finally {
      _busyScan = false;
    }
  }

  Future<void> _save({required bool ship}) async {
    if (destinationId == null) {
      Get.snackbar('Data belum lengkap', 'Pilih gudang tujuan.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (lines.isEmpty) {
      Get.snackbar('Data belum lengkap', 'Scan minimal satu item.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (ship && !await confirmAction(title: 'Simpan & kirim?', message: 'Stok AVAILABLE dialokasikan FEFO dan berstatus IN TRANSIT.', confirmLabel: 'Kirim')) {
      return;
    }
    final record = await c.createTransfer(
      destinationId: destinationId!,
      date: date,
      items: lines.map((l) => TransferItemModel(productId: l.productId, productName: l.productName, sku: l.sku, unit: l.unit,
          quantity: l.quantity, lotId: l.lotId, batchNumber: l.batchNumber)).toList(),
      notes: notes.text,
      ship: ship,
      idempotencyKey: idempotencyKey,
    );
    if (record == null || !mounted) return;
    Get.back();
    Get.snackbar('Berhasil', ship ? 'Transfer ${record.number} dikirim (IN TRANSIT).' : 'Transfer ${record.number} tersimpan.',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final options = c.destinationOptions;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transfer Baru', style: TextStyle(fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Obx(() => Row(children: [
            Expanded(child: SizedBox(height: 52, child: OutlinedButton(onPressed: c.isBusy.value ? null : () => _save(ship: false), child: const Text('Simpan')))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: c.isBusy.value ? null : () => _save(ship: true),
                  child: Text(c.isBusy.value ? 'Memproses...' : 'Simpan & Kirim', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ])),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          InfoRow('Gudang asal', WarehouseContext.instance.activeName, bold: true),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: destinationId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gudang tujuan *', border: OutlineInputBorder(), isDense: true),
            items: options.map((w) => DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.code})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => destinationId = v),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (picked != null) setState(() => date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(formatDate(date)),
            ),
          ),
          const SizedBox(height: 14),
          const ScanPromptCard(title: 'Scan item atau batch', subtitle: 'Hanya stok AVAILABLE. Batch & expiry dipertahankan.'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async => _add(await pickOutboundLine(warehouseId: c.warehouseId, alreadyAdded: _already)),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Cari produk manual'),
            ),
          ),
          Text('Item (${lines.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          if (lines.isEmpty)
            const EmptyState(message: 'Belum ada item.', icon: Icons.qr_code_scanner_rounded)
          else
            ...lines.asMap().entries.map((e) => ItemLine(
              title: e.value.productName,
              subtitle: e.value.lotId == null ? '${e.value.sku} • FEFO otomatis' : '${e.value.sku} • Batch ${e.value.batchNumber}',
              trailing: '${e.value.quantity} ${e.value.unit}',
              onRemove: () => setState(() => lines.removeAt(e.key)),
            )),
          const SizedBox(height: 10),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder(), isDense: true)),
        ],
      ),
    );
  }
}

/// Penerimaan transfer di gudang tujuan: scan batch, qty, (opsional) scan rak.
class TransferReceivePage extends StatefulWidget {
  const TransferReceivePage({super.key, required this.transfer});
  final TransferModel transfer;

  @override
  State<TransferReceivePage> createState() => _TransferReceivePageState();
}

class _ReceiveLine {
  _ReceiveLine(this.lot, this.quantity);
  final TransferLotModel lot;
  int quantity;
  LocationInfo? location;
}

class _TransferReceivePageState extends State<TransferReceivePage> {
  final c = Get.find<TransferController>();
  final lines = <_ReceiveLine>[];
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Terima transfer');
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  Future<void> _onScan(String code) async {
    try {
      final result = await InventoryRepository.instance.scan(code, warehouseId: c.warehouseId);
      if (result.type == ScanType.location) {
        final loc = result.location!;
        if (lines.isEmpty) throw const ApiException('Scan batch terlebih dahulu, lalu scan rak tujuan.');
        if (!loc.isStorage) throw ApiException('Lokasi ${loc.code} bukan rak penyimpanan. Tanpa scan rak, barang masuk area RECEIVING.');
        setState(() => lines.last.location = loc);
        ScanFeedback.success();
        return;
      }
      if (result.type != ScanType.batch) throw const ApiException('Scan barcode batch yang tertera pada barang kiriman.');
      final lot = widget.transfer.lots.firstWhereOrNull((l) => l.lotId == result.batch!.id);
      if (lot == null) throw ApiException('Batch ${result.batch!.batchNumber} tidak termasuk dalam transfer ini.');
      final already = lines.where((l) => l.lot.lotId == lot.lotId).fold<int>(0, (s, l) => s + l.quantity);
      if (already >= lot.remaining) throw ApiException('Batch ${lot.batchNumber} sudah diterima penuh.');
      setState(() => lines.add(_ReceiveLine(lot, lot.remaining - already)));
      ScanFeedback.success();
    } on ApiException catch (e) {
      ScanFeedback.error();
      Get.snackbar('Terima transfer', e.message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _submit() async {
    if (lines.isEmpty) return;
    if (!await confirmAction(
      title: 'Konfirmasi penerimaan?',
      message: '${lines.fold<int>(0, (s, l) => s + l.quantity)} unit diterima di ${WarehouseContext.instance.activeName}. Baris tanpa rak masuk area RECEIVING (lanjut putaway).',
      confirmLabel: 'Terima',
    )) {
      return;
    }
    final ok = await c.receive(widget.transfer, lines.map((l) => {
      'lotId': l.lot.lotId,
      'quantity': l.quantity,
      if (l.location != null) 'toLocationId': l.location!.id,
    }).toList(), idempotencyKey);
    if (ok && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Terima ${t.number}', style: const TextStyle(fontWeight: FontWeight.w700))),
      bottomNavigationBar: Obx(() => BottomActionBar(label: 'Konfirmasi Penerimaan', busy: c.isBusy.value, onPressed: lines.isEmpty ? null : _submit)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          InfoRow('Dari', t.sourceWarehouseName, bold: true),
          InfoRow('Ke', t.destinationWarehouseName),
          const SizedBox(height: 10),
          const ScanPromptCard(title: 'Scan batch yang diterima', subtitle: 'Lalu (opsional) scan rak tujuan. Tanpa rak → area RECEIVING'),
          const SectionTitle('Belum diterima'),
          ...t.lots.where((l) => l.remaining > 0).map((l) => ItemLine(
            title: '${l.productName} • ${l.batchNumber}',
            subtitle: l.expiryDate == null ? 'Non-expiry' : 'ED ${formatDate(l.expiryDate)}',
            trailing: '${l.remaining} ${l.unit}',
          )),
          const SectionTitle('Diterima sekarang'),
          if (lines.isEmpty) const EmptyState(message: 'Belum ada batch discan.', icon: Icons.qr_code_2_rounded),
          ...lines.asMap().entries.map((e) {
            final l = e.value;
            final max = l.lot.remaining - lines.where((x) => x != l && x.lot.lotId == l.lot.lotId).fold<int>(0, (s, x) => s + x.quantity);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${l.lot.productName} • ${l.lot.batchNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
                  IconButton(onPressed: () => setState(() => lines.removeAt(e.key)), icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
                ]),
                QtyStepper(value: l.quantity, min: 1, max: max, unit: l.lot.unit, onChanged: (v) => setState(() => l.quantity = v)),
                const SizedBox(height: 4),
                Text(l.location == null ? 'Tujuan: area RECEIVING (scan rak untuk langsung AVAILABLE)' : 'Tujuan: rak ${l.location!.code} → AVAILABLE',
                    style: TextStyle(fontSize: 11, color: l.location == null ? Colors.black54 : AppColors.success, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
