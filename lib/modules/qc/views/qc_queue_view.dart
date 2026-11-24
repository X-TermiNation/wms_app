import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../services/auth/warehouse_context.dart';
import '../controllers/qc_queue_controller.dart';

/// QC Hold / Recheck dan QC Rejected.
class QcQueueView extends StatelessWidget {
  const QcQueueView({super.key, required this.mode});
  final QcQueueMode mode;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<QcQueueController>(tag: mode.name);
    final isHold = mode == QcQueueMode.hold;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Obx(() => Text('Gudang: ${WarehouseContext.instance.activeName}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: c.load,
        child: Obx(() {
          final total = c.items.fold<int>(0, (s, b) => s + b.quantity);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              SummaryBanner(
                icon: isHold ? Icons.pause_circle_outline_rounded : Icons.block_rounded,
                title: isHold ? 'Barang ditahan QC' : 'Barang gagal QC',
                value: '${c.items.length} batch',
                subtitle: '$total unit • tidak dapat digunakan untuk issuing',
              ),
              const SizedBox(height: 12),
              ScanPromptCard(
                title: 'Scan batch',
                subtitle: isHold ? 'Untuk memulai pemeriksaan ulang (recheck)' : 'Untuk retur / scrap / rework / reinspeksi',
              ),
              const SizedBox(height: 12),
              if (c.isLoading.value && c.items.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (c.items.isEmpty)
                EmptyState(message: isHold ? 'Tidak ada barang QC HOLD.' : 'Tidak ada barang QC REJECT.')
              else
                ...c.items.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BalanceTile(
                    balance: b,
                    selected: c.highlightLotId.value == b.lotId,
                    onTap: () => c.open(b),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => _showHistory(c, b), child: const Text('Riwayat', style: TextStyle(fontSize: 11))),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary, visualDensity: VisualDensity.compact),
                        onPressed: () => c.open(b),
                        child: Text(isHold ? 'Recheck' : 'Tindak lanjut', style: const TextStyle(fontSize: 11)),
                      ),
                    ]),
                  ),
                )),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _showHistory(QcQueueController c, InventoryBalance b) async {
    List<QcInspection> list = const [];
    try {
      list = await c.historyOf(b.lotId);
    } catch (_) {}
    await showDetailSheet(
      title: 'Riwayat QC',
      children: [
        InfoRow('Batch', b.batchNumber, bold: true),
        InfoRow('Produk', b.productName),
        const SectionTitle('Pemeriksaan'),
        if (list.isEmpty) const Text('Belum ada riwayat pemeriksaan.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ...list.map((h) => ItemLine(
          title: '${h.number} • ${h.result}',
          subtitle: 'PASS ${h.quantityPassed} / FAIL ${h.quantityFailed} / HOLD ${h.quantityHeld}'
              '${h.rejectionReason != null ? '\nReject: ${h.rejectionReason}' : ''}'
              '${h.holdReason != null ? '\nHold: ${h.holdReason}' : ''}\n${h.inspectorName ?? '-'} • ${formatDateTime(h.inspectedAt)}',
          trailing: '${h.quantityInspected}',
        )),
      ],
    );
  }
}
