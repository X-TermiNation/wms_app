import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../common/helpers/api_feedback.dart';
import '../../common/widgets/scan_widgets.dart';
import '../../data/models/inventory_models.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../services/auth/warehouse_context.dart';
import '../../services/scanner/scanner_service.dart';

/// Riwayat transaksi operasional (stock movement). Scan batch untuk melihat
/// jejak lengkap batch tersebut sejak receiving.
class HistoryController extends GetxController {
  final _repo = InventoryRepository.instance;
  final movements = <StockMovement>[].obs;
  final filterBatch = Rxn<BatchInfo>();
  final isLoading = false.obs;
  ScanRegistration? _scan;

  String get warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void onInit() {
    super.onInit();
    _scan = ScannerService.instance.register(onScan, label: 'Riwayat');
    load();
  }

  @override
  void onClose() {
    _scan?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final batch = filterBatch.value;
      movements.assignAll(batch == null
          ? await _repo.movements(warehouseId: warehouseId.isEmpty ? null : warehouseId, limit: 150)
          : await _repo.movements(lotId: batch.id, limit: 300));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat riwayat');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onScan(String code) async {
    try {
      final result = await _repo.scan(code, warehouseId: warehouseId);
      if (result.type != ScanType.batch) {
        ScanFeedback.error();
        Get.snackbar('Riwayat', 'Scan barcode batch untuk melihat jejak batch.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      ScanFeedback.success();
      filterBatch.value = result.batch;
      await load();
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Scan tidak dapat diproses');
    }
  }

  void clearFilter() {
    filterBatch.value = null;
    load();
  }
}

class HistoryBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<HistoryController>(() => HistoryController());
}

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.w700))),
    body: RefreshIndicator(
      onRefresh: controller.load,
      child: Obx(() {
        final batch = controller.filterBatch.value;
        // Riwayat batch ditampilkan kronologis (lama -> baru) agar alurnya terbaca.
        final list = batch == null ? controller.movements : controller.movements.reversed.toList();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            ScanPromptCard(
              title: 'Scan batch untuk jejak lengkap',
              subtitle: 'Tanpa scan: 150 transaksi terakhir di ${WarehouseContext.instance.activeName}',
              done: batch != null,
              doneText: batch == null ? null : 'Jejak batch ${batch.batchNumber}',
              onReset: controller.clearFilter,
            ),
            if (batch != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${batch.productName} • diterima ${batch.receivedQuantity} ${batch.unit} • sisa ${batch.currentQuantity} ${batch.unit}'
                    '${batch.expiryDate == null ? '' : ' • ED ${formatDate(batch.expiryDate)}'}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
            const SizedBox(height: 12),
            if (controller.isLoading.value && list.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const EmptyState(message: 'Belum ada transaksi.', icon: Icons.history_rounded)
            else
              ...list.map((m) => _MovementTile(m)),
          ],
        );
      }),
    ),
  );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile(this.m);
  final StockMovement m;

  @override
  Widget build(BuildContext context) {
    final color = switch (m.direction) {
      'IN' => AppColors.success,
      'OUT' => AppColors.danger,
      _ => AppColors.info,
    };
    final icon = switch (m.direction) {
      'IN' => Icons.south_west_rounded,
      'OUT' => Icons.north_east_rounded,
      _ => Icons.swap_horiz_rounded,
    };
    final from = [m.fromWarehouseName != m.toWarehouseName ? m.fromWarehouseName : null, m.fromLocationCode, m.fromStatus]
        .whereType<String>().join(' • ');
    final to = [m.fromWarehouseName != m.toWarehouseName ? m.toWarehouseName : null, m.toLocationCode, m.toStatus]
        .whereType<String>().join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(StockMovement.typeLabel(m.type), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
            Text('${m.direction == 'OUT' ? '-' : m.direction == 'IN' ? '+' : ''}${m.quantity} ${m.unit ?? ''}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ]),
          Text('${m.productName}${m.batchNumber == null ? '' : ' • ${m.batchNumber}'}', style: const TextStyle(fontSize: 11)),
          if (from.isNotEmpty || to.isNotEmpty)
            Text('${from.isEmpty ? '-' : from}  →  ${to.isEmpty ? '-' : to}', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
          if (m.notes != null && m.notes!.isNotEmpty) Text(m.notes!, style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
          Text('${m.referenceNumber ?? ''}  ${m.userName ?? ''}  ${formatDateTime(m.createdAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.black38)),
        ])),
      ]),
    );
  }
}
