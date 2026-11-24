import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../data/models/inventory_models.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../modules/products/controllers/products_controller.dart';
import '../../services/api/api_client.dart';
import '../../services/scanner/scanner_service.dart';
import 'product_picker.dart';
import 'scan_widgets.dart';

/// Baris barang keluar (issuing / transfer). lotId kosong = backend memilih FEFO.
class OutboundLine {
  const OutboundLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
    this.lotId,
    this.batchNumber,
  });

  final String productId, productName, sku, unit;
  final int quantity;
  final String? lotId, batchNumber;

  String get key => '$productId|${lotId ?? ''}';
}

/// Proses hasil scan untuk barang keluar: item -> FEFO, batch -> batch tersebut.
/// [alreadyAdded] = qty yang sudah ada di daftar untuk produk/batch yang sama.
Future<OutboundLine?> scanOutboundLine(
  String code, {
  required String warehouseId,
  required int Function(String productId, String? lotId) alreadyAdded,
}) async {
  try {
    final result = await InventoryRepository.instance.scan(code, warehouseId: warehouseId);
    switch (result.type) {
      case ScanType.location:
        ScanFeedback.error();
        Get.snackbar('Bukan barcode item', 'Lokasi ${result.location!.code} discan. Scan item atau batch.', snackPosition: SnackPosition.BOTTOM);
        return null;
      case ScanType.temporary:
        ScanFeedback.error();
        Get.snackbar('Barang belum terdaftar', 'Label sementara ${result.temporary!.number} belum menjadi stok dan tidak dapat dikeluarkan.',
            snackPosition: SnackPosition.BOTTOM);
        return null;
      case ScanType.batch:
        final batch = result.batch!;
        final available = result.balances
            .where((b) => b.warehouseId == warehouseId && b.status == InventoryStatus.available && !b.isExpired)
            .fold<int>(0, (s, b) => s + b.quantity);
        final blocked = result.balances.where((b) => b.warehouseId == warehouseId && b.status != InventoryStatus.available).toList();
        if (batch.isExpired) {
          ScanFeedback.error();
          Get.snackbar('Batch kedaluwarsa', 'Batch ${batch.batchNumber} sudah expired dan tidak dapat dikeluarkan.', snackPosition: SnackPosition.BOTTOM);
          return null;
        }
        if (available <= 0) {
          ScanFeedback.error();
          Get.snackbar('Batch tidak AVAILABLE',
              blocked.isEmpty
                  ? 'Batch ${batch.batchNumber} tidak memiliki stok di gudang ini.'
                  : 'Batch ${batch.batchNumber} berstatus ${blocked.map((b) => InventoryStatus.shortLabel(b.status)).toSet().join(', ')}. Hanya stok AVAILABLE yang boleh dikeluarkan.',
              snackPosition: SnackPosition.BOTTOM);
          return null;
        }
        ScanFeedback.success();
        return _qtySheet(
          productId: batch.productId, productName: batch.productName, sku: batch.sku, unit: batch.unit,
          lotId: batch.id, batchNumber: batch.batchNumber, expiry: batch.expiryDate,
          available: available - alreadyAdded(batch.productId, batch.id),
        );
      case ScanType.product:
        final p = result.product!;
        final available = (result.availableQuantity ?? 0) - alreadyAdded(p.id, null);
        if (available <= 0) {
          ScanFeedback.error();
          Get.snackbar('Stok tidak tersedia', 'Stok AVAILABLE ${p.name} di gudang ini habis. Barang QC/HOLD/REJECT/expired tidak dapat dikeluarkan.', snackPosition: SnackPosition.BOTTOM);
          return null;
        }
        ScanFeedback.success();
        return _qtySheet(productId: p.id, productName: p.name, sku: p.sku, unit: p.unit, available: available);
    }
  } on ApiException catch (e) {
    ScanFeedback.error();
    if (e.statusCode == 404) {
      await showNotRegistered(e.message);
    } else {
      Get.snackbar('Scan gagal', e.message, snackPosition: SnackPosition.BOTTOM);
    }
    return null;
  }
}

/// Pilih produk manual lalu isi qty (FEFO di backend).
Future<OutboundLine?> pickOutboundLine({required String warehouseId, required int Function(String productId, String? lotId) alreadyAdded}) async {
  final p = await pickProductManually();
  if (p == null) return null;
  try {
    final a = await Get.find<ProductsController>().availability(p.id, warehouseId);
    final available = a.eligibleStock - alreadyAdded(p.id, null);
    if (available <= 0) {
      Get.snackbar('Stok tidak tersedia', 'Stok AVAILABLE ${p.name} di gudang ini habis.', snackPosition: SnackPosition.BOTTOM);
      return null;
    }
    return _qtySheet(productId: p.id, productName: p.name, sku: p.sku, unit: p.unit, available: available);
  } on ApiException catch (e) {
    Get.snackbar('Gagal memeriksa stok', e.message, snackPosition: SnackPosition.BOTTOM);
    return null;
  }
}

Future<OutboundLine?> _qtySheet({
  required String productId,
  required String productName,
  required String sku,
  required String unit,
  required int available,
  String? lotId,
  String? batchNumber,
  DateTime? expiry,
}) {
  var qty = 1;
  return Get.bottomSheet<OutboundLine>(
    StatefulBuilder(builder: (context, setState) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(productName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            lotId == null
                ? '$sku • Batch dipilih otomatis (FEFO)'
                : '$sku • Batch $batchNumber${expiry == null ? '' : ' • ED ${formatDate(expiry)}'}',
            style: TextStyle(fontSize: 11.5, color: lotId == null ? AppColors.info : Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          QtyStepper(label: 'Jumlah dikeluarkan', value: qty, min: 1, max: available, unit: unit, onChanged: (v) => setState(() => qty = v)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Get.back(result: OutboundLine(
                productId: productId, productName: productName, sku: sku, unit: unit, quantity: qty, lotId: lotId, batchNumber: batchNumber,
              )),
              child: Text('Tambahkan $qty $unit', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    )),
    isScrollControlled: true,
  );
}
