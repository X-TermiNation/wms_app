import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../services/auth/warehouse_context.dart';
import '../controllers/qc_inspection_controller.dart';

class QcInspectionView extends GetView<QcInspectionController> {
  const QcInspectionView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('QC Inspection', style: TextStyle(fontWeight: FontWeight.w700)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(22),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Obx(() => Text('Gudang: ${WarehouseContext.instance.activeName}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ),
      ),
    ),
    bottomNavigationBar: Obx(() => BottomActionBar(
      label: 'Simpan Hasil QC',
      icon: Icons.fact_check_rounded,
      busy: controller.isBusy.value,
      onPressed: controller.selected.value != null && controller.canInspect ? controller.submit : null,
    )),
    body: RefreshIndicator(
      onRefresh: controller.loadQueue,
      child: Obx(() {
        final s = controller.selected.value;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            if (!controller.canInspect)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(10)),
                child: const Text('Akun Anda tidak memiliki hak QC. Hubungi supervisor.', style: TextStyle(fontSize: 11, color: AppColors.danger)),
              ),
            ScanPromptCard(
              title: 'Scan barcode batch di area QC',
              subtitle: 'Barang berstatus QC PENDING / QC PROSES / QC HOLD',
              done: s != null,
              doneText: s == null ? null : 'Batch ${s.batchNumber}',
              onReset: controller.reset,
            ),
            if (s != null) ...[
              const SizedBox(height: 8),
              BalanceTile(balance: s, selected: true),
              const SizedBox(height: 14),
              const Text('Hasil pemeriksaan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Total ${controller.total} dari ${s.quantity} ${s.unit}. Sisa yang belum diperiksa tetap di ${s.locationCode}.',
                  style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              const SizedBox(height: 10),
              _ResultStepper(label: 'PASS', color: AppColors.success, value: controller.passed.value, max: s.quantity - controller.failed.value - controller.held.value, unit: s.unit, onChanged: controller.setPassed),
              _ResultStepper(label: 'FAIL', color: AppColors.danger, value: controller.failed.value, max: s.quantity - controller.held.value, unit: s.unit, onChanged: controller.setFailed),
              if (controller.failed.value > 0)
                _Field(controller: controller.rejectionReason, label: 'Alasan penolakan *'),
              _ResultStepper(label: 'HOLD', color: AppColors.warning, value: controller.held.value, max: s.quantity - controller.failed.value, unit: s.unit, onChanged: controller.setHeld),
              if (controller.held.value > 0) ...[
                _Field(controller: controller.holdReason, label: 'Alasan HOLD *'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: controller.recheck.value,
                  onChanged: (v) => controller.recheck.value = v ?? false,
                  title: const Text('Tandai sebagai RECHECK (perlu pemeriksaan ulang)', style: TextStyle(fontSize: 12)),
                ),
              ],
              _Field(controller: controller.notes, label: 'Catatan (opsional)'),
              const Text('Lampiran foto: belum tersedia di versi ini.', style: TextStyle(fontSize: 10, color: Colors.black45)),
              if (controller.history.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Riwayat QC batch ini', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                ...controller.history.map((h) => _HistoryTile(h)),
              ],
            ],
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('Antrean QC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Text('${controller.queue.length} batch', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
            const SizedBox(height: 8),
            if (controller.isLoading.value && controller.queue.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (controller.queue.isEmpty)
              const EmptyState(message: 'Tidak ada barang menunggu QC.', icon: Icons.science_outlined)
            else
              ...controller.queue.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BalanceTile(balance: b, onTap: () => controller.select(b), selected: s?.lotId == b.lotId && s?.locationId == b.locationId),
              )),
          ],
        );
      }),
    ),
  );
}

class _ResultStepper extends StatelessWidget {
  const _ResultStepper({required this.label, required this.color, required this.value, required this.max, required this.unit, required this.onChanged});
  final String label, unit;
  final Color color;
  final int value, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
      const SizedBox(width: 8),
      Expanded(child: QtyStepper(value: value, max: max < 0 ? 0 : max, unit: unit, onChanged: onChanged, label: null)),
    ]),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.h);
  final QcInspection h;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${h.number} • ${h.result}${h.parentInspectionId != null ? ' (recheck)' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      Text('PASS ${h.quantityPassed} • FAIL ${h.quantityFailed} • HOLD ${h.quantityHeld} dari ${h.quantityInspected}', style: const TextStyle(fontSize: 11)),
      if (h.rejectionReason != null) Text('Alasan reject: ${h.rejectionReason}', style: const TextStyle(fontSize: 10.5, color: AppColors.danger)),
      if (h.holdReason != null) Text('Alasan hold: ${h.holdReason}', style: const TextStyle(fontSize: 10.5, color: AppColors.warning)),
      Text('${h.inspectorName ?? '-'} • ${formatDateTime(h.inspectedAt)}', style: const TextStyle(fontSize: 10, color: Colors.black45)),
    ]),
  );
}
