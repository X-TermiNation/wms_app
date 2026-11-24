import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../services/auth/warehouse_context.dart';
import '../controllers/stock_move_controller.dart';

/// Halaman Putaway / QC Transfer / QC Release (scan-first).
class StockMoveView extends StatelessWidget {
  const StockMoveView({super.key, required this.mode});
  final StockMoveMode mode;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<StockMoveController>(tag: mode.name);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(mode.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Obx(() => Text('Gudang: ${WarehouseContext.instance.activeName}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
          ),
        ),
      ),
      bottomNavigationBar: Obx(() => BottomActionBar(
        label: 'Konfirmasi ${mode.title}',
        busy: c.isBusy.value,
        onPressed: c.canSubmit ? c.submit : null,
      )),
      body: RefreshIndicator(
        onRefresh: c.loadPending,
        child: Obx(() {
          final s = c.selected.value;
          final d = c.destination.value;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(mode.hint, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 12),
              ScanPromptCard(
                title: '1. Scan barcode batch',
                subtitle: 'Atau pilih dari daftar di bawah',
                icon: Icons.qr_code_2_rounded,
                done: s != null,
                doneText: s == null ? null : 'Batch ${s.batchNumber}',
                onReset: c.resetSource,
              ),
              if (s != null) ...[
                const SizedBox(height: 8),
                BalanceTile(balance: s, selected: true),
                const SizedBox(height: 12),
                ScanPromptCard(
                  title: '2. Scan lokasi tujuan',
                  subtitle: 'Lokasi: ${mode.destinationLabel}',
                  icon: Icons.location_searching_rounded,
                  done: d != null,
                  doneText: d == null ? null : 'Tujuan ${d.code} (${LocationInfo.typeLabel(d.type)})',
                  onReset: () => c.destination.value = null,
                ),
                const SizedBox(height: 14),
                QtyStepper(
                  label: '3. Jumlah dipindahkan',
                  value: c.quantity.value,
                  min: 1,
                  max: s.quantity,
                  unit: s.unit,
                  onChanged: (v) => c.quantity.value = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c.notesController,
                  decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder(), isDense: true),
                ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text(_pendingTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                Text('${c.pending.length} batch', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
              const SizedBox(height: 8),
              if (c.isLoading.value && c.pending.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (c.pending.isEmpty)
                EmptyState(message: _emptyText, icon: mode.icon)
              else
                ...c.pending.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BalanceTile(
                    balance: b,
                    selected: s?.lotId == b.lotId && s?.locationId == b.locationId && s?.status == b.status,
                    onTap: () => c.selectSource(b),
                  ),
                )),
            ],
          );
        }),
      ),
    );
  }

  String get _pendingTitle => switch (mode) {
    StockMoveMode.putaway => 'Menunggu putaway',
    StockMoveMode.qcTransfer => 'Barang baru diterima',
    StockMoveMode.qcRelease => 'Lolos QC, menunggu release',
  };

  String get _emptyText => switch (mode) {
    StockMoveMode.putaway => 'Tidak ada barang di area receiving.',
    StockMoveMode.qcTransfer => 'Tidak ada barang berstatus RECEIVED. Scan batch AVAILABLE untuk sampling QC.',
    StockMoveMode.qcRelease => 'Tidak ada barang QC PASS yang menunggu release.',
  };
}
