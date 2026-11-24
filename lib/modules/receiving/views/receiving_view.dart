import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/label_widgets.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../services/auth/warehouse_context.dart';
import '../controllers/receiving_controller.dart';
import '../../../data/models/inventory_models.dart' show formatDate;
import '../models/receiving_model.dart';
import 'smart_receiving_pages.dart';

class ReceivingView extends GetView<ReceivingController> {
  const ReceivingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Receiving', style: TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () async {
        await Get.to(() => const ReceivingStartPage());
        await controller.fetchReceivings();
      },
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: const Text('Penerimaan Baru'),
    ),
    body: RefreshIndicator(
      onRefresh: controller.fetchReceivings,
      child: Obx(() {
        final records = controller.filteredReceivings;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            SummaryBanner(
              icon: Icons.move_to_inbox_rounded,
              title: 'Diterima di ${WarehouseContext.instance.activeName}',
              value: '${controller.totalReceivedQuantity} unit',
              subtitle: '${controller.completedCount} dikonfirmasi • ${controller.pendingCount} belum dikonfirmasi',
            ),
            const SizedBox(height: 14),
            AppSearchField(hint: 'Cari nomor, supplier, produk, batch...', controller: controller.searchController, onChanged: controller.updateSearch),
            const SizedBox(height: 10),
            StatusFilterChips(options: const ['Semua', 'Draft', 'Pending', 'Completed', 'Cancelled'], selected: controller.selectedStatus),
            const SizedBox(height: 8),
            if (records.isEmpty && controller.isLoading.value)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (records.isEmpty)
              const EmptyState(message: 'Tidak ada transaksi penerimaan.', icon: Icons.move_to_inbox_outlined)
            else
              ...records.map((r) => DocumentCard(
                icon: Icons.receipt_long_outlined,
                number: r.number,
                date: ReceivingController.formatDate(r.date),
                statusLabel: ReceivingController.statusLabel(r.status),
                statusColor: ReceivingController.statusColor(r.status),
                title: r.supplier,
                subtitle: r.warehouseName,
                trailing: '${r.items.length} item • ${r.totalQuantity} unit',
                onTap: () => _showDetail(controller, r),
                menu: [
                  if (_open(r)) const PopupMenuItem(value: 'confirm', child: Text('Konfirmasi penerimaan')),
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

bool _open(ReceivingModel r) => r.status == ReceivingStatus.draft || r.status == ReceivingStatus.pending;

Future<void> _action(ReceivingController c, ReceivingModel r, String action) async {
  switch (action) {
    case 'confirm':
      if (await confirmAction(
        title: 'Konfirmasi penerimaan?',
        message: 'Backend akan membuat batch untuk ${r.items.length} item ${r.number}. '
            'Barang wajib QC masuk QC-HOLD, lainnya masuk area RECEIVING untuk putaway. Stok belum AVAILABLE.',
        confirmLabel: 'Konfirmasi',
      )) {
        await c.confirm(r);
      }
    case 'cancel':
      if (await confirmAction(title: 'Batalkan penerimaan?', message: '${r.number} akan ditandai Cancelled.', confirmLabel: 'Batalkan', danger: true)) {
        await c.cancel(r);
      }
    case 'delete':
      if (await confirmAction(title: 'Hapus transaksi?', message: '${r.number} belum dikonfirmasi dan akan dihapus.', confirmLabel: 'Hapus', danger: true)) {
        await c.deleteDraft(r);
      }
  }
}

void _showDetail(ReceivingController c, ReceivingModel r) {
  showDetailSheet(
    title: 'Detail Penerimaan',
    badge: AppStatusBadge(label: ReceivingController.statusLabel(r.status), color: ReceivingController.statusColor(r.status)),
    children: [
      InfoRow('Nomor', r.number, bold: true),
      InfoRow('Tanggal', ReceivingController.formatDate(r.date)),
      InfoRow('Supplier', r.supplier),
      if (r.documentRef != null) InfoRow('Dokumen PO', r.documentRef!, bold: true),
      InfoRow('Gudang', r.warehouseName),
      if (r.notes.isNotEmpty) InfoRow('Catatan', r.notes),
      const SectionTitle('Item & Batch'),
      ...r.items.map((i) => ItemLine(
        title: i.productName,
        subtitle: [
          i.sku,
          if (i.supplierLot != null) 'Lot ${i.supplierLot}',
          i.expiryDate == null ? 'Non-expiry' : 'ED ${formatDate(i.expiryDate)}',
          if (i.batchNumber != null) 'Batch ${i.batchNumber}${i.requiresQc == true ? ' (QC)' : ''}',
        ].join(' • '),
        trailing: i.packageUnit == null ? '${i.quantity} ${i.unit}' : '${i.packageQuantity} ${i.packageUnit} = ${i.quantity} ${i.unit}',
      )),
    ],
    actions: r.status == ReceivingStatus.completed && r.items.any((i) => i.batchNumber != null)
        ? [
            OutlinedButton.icon(
              onPressed: () => printFromBackend([for (final i in r.items) ('PRODUCT', i.productId)], title: 'Label Produk'),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Label Produk'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => printFromBackend([for (final i in r.items) if (i.batchNumber != null) ('BATCH', i.batchNumber!)], title: 'Cetak Ulang Label Batch'),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Label Batch'),
            ),
          ]
        : _open(r)
        ? [
            OutlinedButton(onPressed: () { Get.back(); _action(c, r, 'cancel'); }, child: const Text('Batalkan')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () { Get.back(); _action(c, r, 'confirm'); },
              child: const Text('Konfirmasi'),
            ),
          ]
        : const [],
  );
}
