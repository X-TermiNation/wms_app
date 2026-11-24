import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/erp_document_picker.dart';
import '../../../common/widgets/outbound_item_sheet.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/erp_document_models.dart';
import '../../../data/models/inventory_models.dart' show formatDate;
import '../../../data/models/shipping_models.dart' show shippingStageLabel;
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/issuing_controller.dart';
import '../models/issuing_model.dart';

class IssuingView extends GetView<IssuingController> {
  const IssuingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Issuing', style: TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: _chooseIssuingType,
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: const Text('Pengeluaran Baru'),
    ),
    body: RefreshIndicator(
      onRefresh: controller.fetchIssuings,
      child: Obx(() {
        final records = controller.filteredIssuings;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            SummaryBanner(
              icon: Icons.outbox_rounded,
              title: 'Dikeluarkan dari ${WarehouseContext.instance.activeName}',
              value: '${controller.totalIssuedQuantity} unit',
              subtitle: '${controller.completedCount} selesai • ${controller.pendingCount} menunggu',
            ),
            const SizedBox(height: 14),
            AppSearchField(hint: 'Cari nomor, tujuan, batch...', controller: controller.searchController, onChanged: controller.updateSearch),
            const SizedBox(height: 10),
            StatusFilterChips(options: const ['Semua', 'Draft', 'Pending', 'Completed', 'Cancelled'], selected: controller.selectedStatus),
            const SizedBox(height: 8),
            if (records.isEmpty && controller.isLoading.value)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (records.isEmpty)
              const EmptyState(message: 'Tidak ada transaksi pengeluaran.', icon: Icons.outbox_outlined)
            else
              ...records.map((r) => DocumentCard(
                icon: Icons.outbox_outlined,
                number: r.number,
                date: IssuingController.formatDate(r.date),
                statusLabel: IssuingController.statusLabel(r.status),
                statusColor: IssuingController.statusColor(r.status),
                title: r.destination,
                subtitle: r.warehouseName,
                trailing: '${r.items.length} item • ${r.totalQuantity} unit',
                onTap: () => _showDetail(controller, r),
                menu: [
                  if (_open(r)) const PopupMenuItem(value: 'complete', child: Text('Keluarkan stok (FEFO)')),
                  if (_open(r)) const PopupMenuItem(value: 'cancel', child: Text('Batalkan')),
                  if (_open(r)) const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
                onMenu: (a) => _action(controller, r, a),
              )),
          ],
        );
      }),
    ),
  );
}

/// Pengeluaran dari Sales Order ERP (picking) atau manual tanpa dokumen.
Future<void> _chooseIssuingType() async {
  final choice = await Get.bottomSheet<String>(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text('Pengeluaran Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ),
          ListTile(
            minVerticalPadding: 14,
            leading: const Icon(Icons.request_quote_outlined, color: AppColors.primary, size: 30),
            title: const Text('Dari Sales Order (Picking)', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Scan / pilih SO dari ERP. Item & qty dicocokkan dengan SO, hasil dikirim ke ERP.'),
            onTap: () => Get.back(result: 'so'),
          ),
          ListTile(
            minVerticalPadding: 14,
            leading: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.info, size: 30),
            title: const Text('Pengeluaran Manual', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Tanpa dokumen SO (produksi, maintenance, kebutuhan internal).'),
            onTap: () => Get.back(result: 'manual'),
          ),
        ]),
      ),
    ),
  );
  if (choice == 'so') {
    await Get.to(() => ErpDocumentPickerPage(
          kind: ErpDocKind.outbound,
          onOpen: (doc) async => Get.to(() => IssuingFormPage(document: doc)),
        ));
  } else if (choice == 'manual') {
    await Get.to(() => const IssuingFormPage());
  }
}

bool _open(IssuingModel r) => r.status == IssuingStatus.draft || r.status == IssuingStatus.pending;

Future<void> _action(IssuingController c, IssuingModel r, String action) async {
  switch (action) {
    case 'complete':
      if (await confirmAction(
        title: 'Keluarkan stok?',
        message: 'Backend memilih batch AVAILABLE dengan expiry terdekat (FEFO). Batch expired & barang QC tidak dipakai.',
        confirmLabel: 'Keluarkan',
      )) {
        await c.changeStatus(r, IssuingStatus.completed);
      }
    case 'cancel':
      if (await confirmAction(title: 'Batalkan pengeluaran?', message: '${r.number} akan ditandai Cancelled.', confirmLabel: 'Batalkan', danger: true)) {
        await c.changeStatus(r, IssuingStatus.cancelled);
      }
    case 'delete':
      if (await confirmAction(title: 'Hapus transaksi?', message: '${r.number} akan dihapus.', confirmLabel: 'Hapus', danger: true)) {
        await c.deleteDraft(r);
      }
  }
}

void _showDetail(IssuingController c, IssuingModel r) {
  showDetailSheet(
    title: 'Detail Pengeluaran',
    badge: AppStatusBadge(label: IssuingController.statusLabel(r.status), color: IssuingController.statusColor(r.status)),
    children: [
      InfoRow('Nomor', r.number, bold: true),
      InfoRow('Tanggal', IssuingController.formatDate(r.date)),
      InfoRow('Tujuan', r.destination),
      if (r.documentRef != null) InfoRow('Dokumen SO', r.documentRef!, bold: true),
      InfoRow('Gudang asal', r.warehouseName),
      if (r.shippingStatus != null) InfoRow('Pengiriman', shippingStageLabel(r.shippingStatus), bold: true),
      if (r.packingNumber != null) InfoRow('Packing', r.packingNumber!),
      if (r.shipmentNumber != null) InfoRow('Shipment', r.shipmentNumber!),
      if (r.notes.isNotEmpty) InfoRow('Catatan', r.notes),
      const SectionTitle('Item'),
      ...r.items.map((i) => ItemLine(
        title: i.productName,
        subtitle: i.batchNumber == null ? '${i.sku} • FEFO otomatis' : '${i.sku} • Batch ${i.batchNumber}',
        trailing: '${i.quantity} ${i.unit}',
      )),
      if (r.allocations.isNotEmpty) ...[
        const SectionTitle('Alokasi batch (FEFO)'),
        ...r.allocations.map((a) => ItemLine(
          title: 'Batch ${a.batchNumber}',
          subtitle: '${a.locationCode}${a.expiryDate == null ? ' • Non-expiry' : ' • ED ${formatDate(a.expiryDate)}'}',
          trailing: '${a.quantity}',
        )),
      ],
    ],
    actions: _open(r)
        ? [
            OutlinedButton(onPressed: () { Get.back(); _action(c, r, 'cancel'); }, child: const Text('Batalkan')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () { Get.back(); _action(c, r, 'complete'); },
              child: const Text('Keluarkan'),
            ),
          ]
        : const [],
  );
}

/// Form pengeluaran berbasis scan item / batch.
class IssuingFormPage extends StatefulWidget {
  const IssuingFormPage({super.key, this.document});

  /// Picking terhadap dokumen SO (ERP): hanya item dokumen, tujuan = customer SO.
  final ErpDocument? document;

  @override
  State<IssuingFormPage> createState() => _IssuingFormPageState();
}

class _IssuingFormPageState extends State<IssuingFormPage> {
  final c = Get.find<IssuingController>();
  final destination = TextEditingController();
  final notes = TextEditingController();
  final lines = <OutboundLine>[];
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  DateTime date = DateTime.now();
  ScanRegistration? _scan;
  bool _busyScan = false;

  ErpDocument? get doc => widget.document;
  int countedFor(String productId) => lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.quantity);

  @override
  void initState() {
    super.initState();
    if (doc != null) destination.text = doc!.partyName.isNotEmpty ? doc!.partyName : doc!.displayNumber;
    _scan = ScannerService.instance.register(_onScan, label: 'Issuing form');
  }

  @override
  void dispose() {
    _scan?.cancel();
    destination.dispose();
    notes.dispose();
    super.dispose();
  }

  int _already(String productId, String? lotId) =>
      lines.where((l) => l.productId == productId && (lotId == null || l.lotId == lotId)).fold(0, (s, l) => s + l.quantity);

  void _add(OutboundLine? line) {
    if (line == null) return;
    if (doc != null && !doc!.contains(line.productId)) {
      ScanFeedback.error();
      Get.snackbar('Bukan item SO', '${line.productName} tidak ada di SO ${doc!.displayNumber}.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (doc != null && countedFor(line.productId) + line.quantity > doc!.availableFor(line.productId)) {
      ScanFeedback.error();
      Get.snackbar('Melebihi sisa SO', '${line.productName}: sisa SO ${doc!.availableFor(line.productId)} ${line.unit}.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() {
      final i = lines.indexWhere((l) => l.key == line.key);
      if (i >= 0) {
        final old = lines[i];
        lines[i] = OutboundLine(productId: old.productId, productName: old.productName, sku: old.sku, unit: old.unit,
            quantity: old.quantity + line.quantity, lotId: old.lotId, batchNumber: old.batchNumber);
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

  Future<void> _save({required bool complete}) async {
    if (destination.text.trim().isEmpty) {
      Get.snackbar('Data belum lengkap', 'Tujuan pengeluaran wajib diisi.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (lines.isEmpty) {
      Get.snackbar('Data belum lengkap', 'Scan minimal satu item.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (complete &&
        !await confirmAction(
          title: 'Simpan & keluarkan stok?',
          message: 'Stok AVAILABLE langsung dikurangi. Batch dipilih backend dengan FEFO.'
              '${doc != null ? ' Qty dicatat ke SO ${doc!.displayNumber} dan dikirim ke ERP sebagai Goods Issue.' : ''}',
          confirmLabel: 'Keluarkan',
        )) {
      return;
    }
    final record = await c.createIssuing(
      destination: destination.text,
      date: date,
      items: lines.map((l) => IssuingItemModel(productId: l.productId, productName: l.productName, sku: l.sku, unit: l.unit,
          quantity: l.quantity, lotId: l.lotId, batchNumber: l.batchNumber)).toList(),
      notes: notes.text,
      complete: complete,
      idempotencyKey: idempotencyKey,
      outboundDocumentId: doc?.id,
    );
    if (record == null || !mounted) return;
    Get.back();
    if (record.status == IssuingStatus.completed) {
      await IssuingController.showAllocations(record);
    } else {
      Get.snackbar('Berhasil', 'Pengeluaran ${record.number} tersimpan (Pending).', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(doc != null ? 'Picking ${doc!.displayNumber}' : 'Pengeluaran Baru', style: const TextStyle(fontWeight: FontWeight.w700))),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Obx(() => Row(children: [
          Expanded(child: SizedBox(height: 52, child: OutlinedButton(onPressed: c.isBusy.value ? null : () => _save(complete: false), child: const Text('Simpan')))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: c.isBusy.value ? null : () => _save(complete: true),
                child: Text(c.isBusy.value ? 'Memproses...' : 'Simpan & Keluarkan', style: const TextStyle(fontWeight: FontWeight.w800)),
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
        TextField(controller: destination, textCapitalization: TextCapitalization.words, readOnly: doc != null,
            decoration: InputDecoration(
              labelText: doc != null ? 'Tujuan (customer SO)' : 'Tujuan * (produksi / cabang / maintenance)',
              border: const OutlineInputBorder(),
              isDense: true,
            )),
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
        const ScanPromptCard(title: 'Scan item atau batch', subtitle: 'Item → batch FEFO otomatis • Batch → batch tersebut (wajib AVAILABLE)'),
        if (doc != null) ...[
          const SizedBox(height: 10),
          ErpDocumentProgress(document: doc!, countedFor: countedFor),
        ],
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
          const EmptyState(message: 'Belum ada item. Scan barcode untuk menambah.', icon: Icons.qr_code_scanner_rounded)
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
