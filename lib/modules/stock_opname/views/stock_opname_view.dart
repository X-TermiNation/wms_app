import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/stock_opname_controller.dart';
import '../models/stock_opname_model.dart';

class StockOpnameView extends GetView<StockOpnameController> {
  const StockOpnameView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Stock Opname', style: TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () => Get.to(() => const OpnameFormPage()),
      icon: const Icon(Icons.fact_check_outlined),
      label: const Text('Hitung Lokasi'),
    ),
    body: RefreshIndicator(
      onRefresh: controller.fetchRecords,
      child: Obx(() {
        final rows = controller.filteredRecords;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            SummaryBanner(
              icon: Icons.fact_check_outlined,
              title: 'Stock opname ${WarehouseContext.instance.activeName}',
              value: '${controller.draftCount} menunggu persetujuan',
              subtitle: '${controller.completedCount} disetujui • ${controller.totalDifferences} baris berselisih',
            ),
            const SizedBox(height: 14),
            AppSearchField(hint: 'Cari nomor atau lokasi...', controller: controller.searchController, onChanged: controller.updateSearch),
            const SizedBox(height: 10),
            StatusFilterChips(options: const ['Semua', 'Draft', 'Completed', 'Cancelled'], selected: controller.selectedStatus),
            const SizedBox(height: 8),
            if (rows.isEmpty && controller.isLoading.value)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (rows.isEmpty)
              const EmptyState(message: 'Belum ada stock opname.', icon: Icons.fact_check_outlined)
            else
              ...rows.map((r) => DocumentCard(
                icon: Icons.fact_check_outlined,
                number: r.number,
                date: StockOpnameController.formatDate(r.date),
                statusLabel: StockOpnameController.statusLabel(r.status),
                statusColor: StockOpnameController.statusColor(r.status),
                title: 'Lokasi ${r.locationCode ?? '-'}',
                subtitle: '${r.items.length} baris • ${r.items.where((i) => i.difference != 0).length} berselisih',
                trailing: '${r.totalDifference > 0 ? '+' : ''}${r.totalDifference}',
                onTap: () => _detail(controller, r),
                menu: [
                  if (r.status == OpnameStatus.draft && controller.canApprove) const PopupMenuItem(value: 'complete', child: Text('Setujui & sesuaikan stok')),
                  if (r.status == OpnameStatus.draft) const PopupMenuItem(value: 'cancel', child: Text('Batalkan')),
                  if (r.status == OpnameStatus.draft) const PopupMenuItem(value: 'delete', child: Text('Hapus draft')),
                ],
                onMenu: (a) => _action(controller, r, a),
              )),
          ],
        );
      }),
    ),
  );
}

Future<void> _action(StockOpnameController c, StockOpnameModel r, String action) async {
  switch (action) {
    case 'complete':
      if (await confirmAction(
        title: 'Setujui stock opname?',
        message: 'Stok ${r.items.where((i) => i.difference != 0).length} baris akan disesuaikan dengan hasil fisik. Jika stok sistem sudah berubah sejak dihitung, persetujuan ditolak.',
        confirmLabel: 'Setujui',
      )) {
        await c.complete(r);
      }
    case 'cancel':
      if (await confirmAction(title: 'Batalkan opname?', message: '${r.number} dibatalkan tanpa mengubah stok.', confirmLabel: 'Batalkan', danger: true)) {
        await c.cancel(r);
      }
    case 'delete':
      if (await confirmAction(title: 'Hapus draft?', message: '${r.number} akan dihapus.', confirmLabel: 'Hapus', danger: true)) {
        await c.deleteDraft(r);
      }
  }
}

void _detail(StockOpnameController c, StockOpnameModel r) {
  showDetailSheet(
    title: 'Detail Stock Opname',
    badge: AppStatusBadge(label: StockOpnameController.statusLabel(r.status), color: StockOpnameController.statusColor(r.status)),
    children: [
      InfoRow('Nomor', r.number, bold: true),
      InfoRow('Tanggal', StockOpnameController.formatDate(r.date)),
      InfoRow('Gudang', r.warehouseName),
      InfoRow('Lokasi', r.locationCode ?? '-'),
      if (r.notes.isNotEmpty) InfoRow('Catatan', r.notes),
      const SectionTitle('Hasil hitung'),
      ...r.items.map((i) => ItemLine(
        title: '${i.productName} • ${i.batchNumber ?? '-'}',
        subtitle: '${i.locationCode ?? '-'} • ${InventoryStatus.shortLabel(i.inventoryStatus ?? '-')} • Sistem ${i.systemStock} / Fisik ${i.physicalStock}',
        trailing: '${i.difference > 0 ? '+' : ''}${i.difference}',
      )),
    ],
    actions: r.status == OpnameStatus.draft && c.canApprove
        ? [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () { Get.back(); _action(c, r, 'complete'); },
              child: const Text('Setujui & Sesuaikan'),
            ),
          ]
        : const [],
  );
}

class _CountLine {
  _CountLine({required this.lotId, required this.batchNumber, required this.productId, required this.productName,
      required this.sku, required this.unit, required this.status, required this.system, this.expiry});
  final String lotId, batchNumber, productId, productName, sku, unit;
  String status;
  int system;
  int physical = 0;
  final DateTime? expiry;
}

/// Hitung fisik satu lokasi: scan lokasi -> scan batch (scan ulang = +1).
class OpnameFormPage extends StatefulWidget {
  const OpnameFormPage({super.key});

  @override
  State<OpnameFormPage> createState() => _OpnameFormPageState();
}

class _OpnameFormPageState extends State<OpnameFormPage> {
  final c = Get.find<StockOpnameController>();
  final notes = TextEditingController();
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  final lines = <_CountLine>[];
  LocationInfo? location;
  List<InventoryBalance> systemBalances = const [];
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Stock opname');
  }

  @override
  void dispose() {
    _scan?.cancel();
    notes.dispose();
    super.dispose();
  }

  int _systemQty(String lotId, String status) =>
      systemBalances.where((b) => b.lotId == lotId && b.status == status).fold(0, (s, b) => s + b.quantity);

  Future<void> _onScan(String code) async {
    try {
      final result = await InventoryRepository.instance.scan(code, warehouseId: c.warehouseId);
      if (result.type == ScanType.location) {
        if (lines.isNotEmpty && location != null && result.location!.id != location!.id) {
          throw const ApiException('Satu opname untuk satu lokasi. Simpan hitungan lokasi ini terlebih dahulu.');
        }
        final balances = await InventoryRepository.instance.balances(warehouseId: c.warehouseId, locationId: result.location!.id);
        setState(() {
          location = result.location;
          systemBalances = balances;
        });
        ScanFeedback.success();
        return;
      }
      if (location == null) throw const ApiException('Scan barcode lokasi terlebih dahulu.');
      if (result.type == ScanType.product) {
        throw const ApiException('Scan barcode batch (label batch internal) agar stok terhitung per batch.');
      }
      final batch = result.batch!;
      final existing = lines.where((l) => l.lotId == batch.id).toList();
      if (existing.isNotEmpty) {
        setState(() => existing.last.physical++);
        ScanFeedback.success();
        return;
      }
      final statusesHere = systemBalances.where((b) => b.lotId == batch.id).map((b) => b.status).toSet().toList();
      final status = statusesHere.isEmpty ? InventoryStatus.available : statusesHere.first;
      setState(() => lines.add(_CountLine(
        lotId: batch.id, batchNumber: batch.batchNumber, productId: batch.productId, productName: batch.productName,
        sku: batch.sku, unit: batch.unit, status: status, system: _systemQty(batch.id, status), expiry: batch.expiryDate,
      )..physical = 1));
      ScanFeedback.success();
    } on ApiException catch (e) {
      ScanFeedback.error();
      Get.snackbar('Stock opname', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      ScanFeedback.error();
      showApiError(e);
    }
  }

  void _addFromSystem(InventoryBalance b) {
    if (lines.any((l) => l.lotId == b.lotId && l.status == b.status)) return;
    setState(() => lines.add(_CountLine(
      lotId: b.lotId, batchNumber: b.batchNumber, productId: b.productId, productName: b.productName,
      sku: b.sku, unit: b.unit, status: b.status, system: b.quantity, expiry: b.expiryDate,
    )));
  }

  Future<void> _save() async {
    if (location == null || lines.isEmpty) {
      Get.snackbar('Data belum lengkap', 'Scan lokasi dan minimal satu batch.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final keys = lines.map((l) => '${l.lotId}|${l.status}').toSet();
    if (keys.length != lines.length) {
      Get.snackbar('Data ganda', 'Batch dengan status yang sama hanya boleh satu baris.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final uncounted = systemBalances.where((b) => !lines.any((l) => l.lotId == b.lotId && l.status == b.status)).length;
    if (!await confirmAction(
      title: 'Simpan hasil hitung?',
      message: '${lines.length} baris di ${location!.code} disimpan sebagai Draft.'
          '${uncounted > 0 ? ' $uncounted saldo sistem di lokasi ini tidak ikut dihitung.' : ''} Stok belum berubah sampai disetujui.',
      confirmLabel: 'Simpan Draft',
    )) {
      return;
    }
    final ok = await c.createOpname(
      locationId: location!.id,
      date: DateTime.now(),
      items: lines.map((l) => StockOpnameItemModel(
        productId: l.productId, productName: l.productName, sku: l.sku, unit: l.unit,
        systemStock: l.system, physicalStock: l.physical, lotId: l.lotId, locationId: location!.id, inventoryStatus: l.status,
      )).toList(),
      notes: notes.text,
      idempotencyKey: idempotencyKey,
    );
    if (ok && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Hitung Stok Lokasi', style: TextStyle(fontWeight: FontWeight.w700))),
    bottomNavigationBar: Obx(() => BottomActionBar(label: 'Simpan Draft Opname', busy: c.isBusy.value, onPressed: lines.isEmpty ? null : _save)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ScanPromptCard(
          title: '1. Scan barcode lokasi',
          icon: Icons.location_searching_rounded,
          done: location != null,
          doneText: location == null ? null : 'Lokasi ${location!.code} (${LocationInfo.typeLabel(location!.type)})',
          onReset: lines.isEmpty ? () => setState(() { location = null; systemBalances = const []; }) : null,
        ),
        if (location != null) ...[
          const SizedBox(height: 10),
          const ScanPromptCard(title: '2. Scan batch', subtitle: 'Scan ulang batch yang sama = qty fisik +1', icon: Icons.qr_code_2_rounded),
          const SectionTitle('Hasil hitung'),
          if (lines.isEmpty) const EmptyState(message: 'Belum ada batch dihitung.', icon: Icons.qr_code_2_rounded),
          ...lines.asMap().entries.map((e) => _CountTile(
            key: ObjectKey(e.value),
            line: e.value,
            onStatus: (s) => setState(() {
              e.value.status = s;
              e.value.system = _systemQty(e.value.lotId, s);
            }),
            onPhysical: (v) => setState(() => e.value.physical = v),
            onRemove: () => setState(() => lines.removeAt(e.key)),
          )),
          SectionTitle('Saldo sistem di ${location!.code} (${systemBalances.length})'),
          const Text('Ketuk untuk menambah baris hitung (qty fisik mulai dari 0).', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
          const SizedBox(height: 6),
          ...systemBalances.map((b) => Padding(padding: const EdgeInsets.only(bottom: 7), child: BalanceTile(balance: b, onTap: () => _addFromSystem(b)))),
          const SizedBox(height: 8),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder(), isDense: true)),
        ],
      ],
    ),
  );
}

class _CountTile extends StatelessWidget {
  const _CountTile({super.key, required this.line, required this.onStatus, required this.onPhysical, required this.onRemove});
  final _CountLine line;
  final ValueChanged<String> onStatus;
  final ValueChanged<int> onPhysical;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final diff = line.physical - line.system;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${line.productName}\n${line.batchNumber}${line.expiry == null ? '' : ' • ED ${formatDate(line.expiry)}'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
        ]),
        DropdownButtonFormField<String>(
          initialValue: line.status,
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status stok yang dihitung', border: OutlineInputBorder(), isDense: true),
          items: InventoryStatus.countable.map((s) => DropdownMenuItem(value: s, child: Text(InventoryStatus.label(s), style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) { if (v != null) onStatus(v); },
        ),
        const SizedBox(height: 8),
        QtyStepper(label: 'Qty fisik', value: line.physical, unit: line.unit, onChanged: onPhysical),
        const SizedBox(height: 4),
        Text('Sistem ${line.system} • Selisih ${diff > 0 ? '+' : ''}$diff',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: diff == 0 ? AppColors.success : diff > 0 ? AppColors.info : AppColors.danger)),
      ]),
    );
  }
}
