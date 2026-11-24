import 'package:flutter/material.dart';

import '../../application/constants/app_colors.dart';

/// Status stok (sama dengan backend). Hanya AVAILABLE yang boleh dikeluarkan.
abstract final class InventoryStatus {
  static const received = 'RECEIVED';
  static const qcPending = 'QC_PENDING';
  static const qcInProgress = 'QC_IN_PROGRESS';
  static const qcPassed = 'QC_PASSED';
  static const qcRejected = 'QC_REJECTED';
  static const qcHold = 'QC_HOLD';
  static const available = 'AVAILABLE';
  static const inTransit = 'IN_TRANSIT';

  static const countable = [available, received, qcPending, qcInProgress, qcPassed, qcHold, qcRejected];

  static String label(String status) => switch (status) {
    received => 'Diterima (belum putaway)',
    qcPending => 'Menunggu QC',
    qcInProgress => 'Sedang QC',
    qcPassed => 'Lolos QC (belum putaway)',
    qcRejected => 'Gagal QC',
    qcHold => 'QC Hold',
    available => 'Available',
    inTransit => 'Dalam perjalanan',
    _ => status,
  };

  static String shortLabel(String status) => switch (status) {
    received => 'RECEIVED',
    qcPending => 'QC PENDING',
    qcInProgress => 'QC PROSES',
    qcPassed => 'QC PASS',
    qcRejected => 'QC REJECT',
    qcHold => 'QC HOLD',
    available => 'AVAILABLE',
    inTransit => 'IN TRANSIT',
    _ => status,
  };

  static Color color(String status) => switch (status) {
    available => AppColors.success,
    received => AppColors.info,
    qcPassed => const Color(0xFF2E9D6A),
    qcRejected => AppColors.danger,
    qcHold => AppColors.warning,
    inTransit => const Color(0xFF6B5BD2),
    _ => const Color(0xFFE69A16),
  };
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

String formatDate(DateTime? d) => d == null
    ? '-'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatDateTime(DateTime? d) => d == null
    ? '-'
    : '${formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Ringkasan produk dari hasil lookup barcode.
class ProductBrief {
  const ProductBrief({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.unit,
    this.category,
    this.requiresQc = false,
    this.hasExpiry = false,
    this.imageUrl,
  });

  final String id, sku, barcode, name, unit;
  final String? category, imageUrl;
  final bool requiresQc, hasExpiry;

  factory ProductBrief.fromJson(Map<String, dynamic> j) => ProductBrief(
    id: j['id'] as String,
    sku: j['sku'] as String,
    barcode: (j['barcode'] as String?) ?? '',
    name: j['name'] as String,
    unit: (j['unit'] as String?) ?? 'PCS',
    category: j['category'] as String?,
    requiresQc: j['requiresQc'] == true,
    hasExpiry: j['hasExpiry'] == true,
    imageUrl: j['imageUrl'] as String?,
  );
}

/// Batch / lot.
class BatchInfo {
  const BatchInfo({
    required this.id,
    required this.batchNumber,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    this.supplierLot,
    this.expiryDate,
    this.isExpired = false,
    this.receivedQuantity = 0,
    this.currentQuantity = 0,
  });

  final String id, batchNumber, productId, productName, sku, unit;
  final String? supplierLot;
  final DateTime? expiryDate;
  final bool isExpired;
  final int receivedQuantity, currentQuantity;

  factory BatchInfo.fromJson(Map<String, dynamic> j) => BatchInfo(
    id: j['id'] as String,
    batchNumber: j['batchNumber'] as String,
    productId: j['productId'] as String,
    productName: (j['productName'] as String?) ?? '',
    sku: (j['sku'] as String?) ?? '',
    unit: (j['unit'] as String?) ?? '',
    supplierLot: j['supplierLot'] as String?,
    expiryDate: _date(j['expiryDate']),
    isExpired: j['isExpired'] == true,
    receivedQuantity: _int(j['receivedQuantity']),
    currentQuantity: _int(j['currentQuantity']),
  );
}

/// Saldo: qty satu batch di satu lokasi dengan satu status.
class InventoryBalance {
  const InventoryBalance({
    required this.lotId,
    required this.batchNumber,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.warehouseId,
    required this.locationId,
    required this.locationCode,
    required this.locationType,
    required this.status,
    required this.quantity,
    this.supplierLot,
    this.expiryDate,
    this.isExpired = false,
    this.locationBarcode,
  });

  final String lotId, batchNumber, productId, productName, sku, unit;
  final String warehouseId, locationId, locationCode, locationType, status;
  final String? supplierLot, locationBarcode;
  final DateTime? expiryDate;
  final bool isExpired;
  final int quantity;

  factory InventoryBalance.fromJson(Map<String, dynamic> j) => InventoryBalance(
    lotId: j['lotId'] as String,
    batchNumber: j['batchNumber'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    sku: j['sku'] as String,
    unit: j['unit'] as String,
    warehouseId: j['warehouseId'] as String,
    locationId: j['locationId'] as String,
    locationCode: j['locationCode'] as String,
    locationType: (j['locationType'] as String?) ?? 'STORAGE',
    locationBarcode: j['locationBarcode'] as String?,
    status: j['status'] as String,
    quantity: _int(j['quantity']),
    supplierLot: j['supplierLot'] as String?,
    expiryDate: _date(j['expiryDate']),
    isExpired: j['isExpired'] == true,
  );
}

/// Lokasi gudang (hasil scan barcode lokasi).
class LocationInfo {
  const LocationInfo({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.type,
    this.barcode,
    this.status = 'available',
    this.isActive = true,
    this.description = '',
  });

  final String id, warehouseId, code, type, status, description;
  final String? barcode;
  final bool isActive;

  bool get isStorage => type == 'STORAGE';

  factory LocationInfo.fromJson(Map<String, dynamic> j) => LocationInfo(
    id: j['id'] as String,
    warehouseId: j['warehouseId'] as String,
    code: j['code'] as String,
    type: (j['type'] as String?) ?? 'STORAGE',
    barcode: j['barcode'] as String?,
    status: (j['status'] as String?) ?? 'available',
    isActive: j['isActive'] != false,
    description: (j['description'] as String?) ?? '',
  );

  static String typeLabel(String type) => switch (type) {
    'RECEIVING' => 'Area Receiving',
    'QC_HOLD' => 'QC Hold',
    'QC_INSPECTION' => 'QC Inspection',
    'QC_PASS' => 'QC Pass',
    'QC_REJECT' => 'QC Reject',
    'QC_QUARANTINE' => 'QC Karantina',
    'TRANSIT' => 'Transit',
    _ => 'Rak',
  };
}

/// Data GS1 (GS1-128 / DataMatrix) hasil parsing backend. Field bisa kosong.
class Gs1Data {
  const Gs1Data({required this.gtin, this.lot, this.expiryDate, this.serial});

  final String gtin;
  final String? lot, serial;
  final DateTime? expiryDate;

  factory Gs1Data.fromJson(Map<String, dynamic> j) => Gs1Data(
    gtin: j['gtin'] as String,
    lot: j['lot'] as String?,
    expiryDate: _date(j['expiryDate']),
    serial: j['serial'] as String?,
  );
}

enum ScanType { product, batch, location, temporary }

/// Konversi kemasan produk: 1 [unitCode] = [conversionFactor] x base unit.
class PackageInfo {
  const PackageInfo({required this.id, required this.unitCode, required this.conversionFactor, this.barcode});

  final String id, unitCode;
  final int conversionFactor;
  final String? barcode;

  factory PackageInfo.fromJson(Map<String, dynamic> j) => PackageInfo(
    id: j['id'] as String,
    unitCode: j['unitCode'] as String,
    conversionFactor: _int(j['conversionFactor']),
    barcode: j['barcode'] as String?,
  );
}

/// Barang tiba fisik tetapi belum terdaftar di master item (Temporary Receiving).
class TemporaryReceiving {
  const TemporaryReceiving({
    required this.id,
    required this.number,
    required this.tempBarcode,
    required this.warehouseId,
    required this.warehouseName,
    required this.unit,
    required this.quantity,
    required this.status,
    required this.readyToReceive,
    this.categoryName,
    this.supplierId,
    this.supplierName,
    this.supplierBarcode,
    this.hasPhoto = false,
    this.productId,
    this.productName,
    this.productSku,
    this.productUnit,
    this.baseQuantity,
    this.rejectReason,
    this.receivingNumber,
    this.createdAt,
  });

  final String id, number, tempBarcode, warehouseId, warehouseName, unit, status;
  final int quantity;
  final bool readyToReceive, hasPhoto;
  final String? categoryName, supplierId, supplierName, supplierBarcode;
  final String? productId, productName, productSku, productUnit, rejectReason, receivingNumber;
  final int? baseQuantity;
  final DateTime? createdAt;

  static const statusLabels = {
    'PENDING_REGISTRATION': 'Menunggu registrasi',
    'REGISTERED': 'Produk baru terdaftar',
    'MATCHED_EXISTING_PRODUCT': 'Cocok produk lama',
    'REJECTED': 'Ditolak',
  };
  String get statusLabel => receivingNumber != null ? 'Sudah diterima' : (statusLabels[status] ?? status);

  factory TemporaryReceiving.fromJson(Map<String, dynamic> j) => TemporaryReceiving(
    id: j['id'] as String,
    number: j['number'] as String,
    tempBarcode: j['tempBarcode'] as String,
    warehouseId: j['warehouseId'] as String,
    warehouseName: (j['warehouseName'] as String?) ?? '-',
    unit: j['unit'] as String,
    quantity: _int(j['quantity']),
    status: j['status'] as String,
    readyToReceive: j['readyToReceive'] == true,
    categoryName: j['categoryName'] as String?,
    supplierId: j['supplierId'] as String?,
    supplierName: j['supplierName'] as String?,
    supplierBarcode: j['supplierBarcode'] as String?,
    hasPhoto: j['hasPhoto'] == true,
    productId: j['productId'] as String?,
    productName: j['productName'] as String?,
    productSku: j['productSku'] as String?,
    productUnit: j['productUnit'] as String?,
    baseQuantity: j['baseQuantity'] == null ? null : _int(j['baseQuantity']),
    rejectReason: j['rejectReason'] as String?,
    receivingNumber: j['receivingNumber'] as String?,
    createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'] as String)?.toLocal(),
  );
}

/// Isi label barcode dari `GET /api/labels` (sama untuk SUNMI & Desktop).
class LabelData {
  const LabelData({required this.type, required this.code, required this.symbology, required this.title, this.lines = const []});

  final String type, code, symbology, title;
  final List<String> lines;

  factory LabelData.fromJson(Map<String, dynamic> j) => LabelData(
    type: j['type'] as String,
    code: j['code'] as String,
    symbology: (j['symbology'] as String?) ?? 'CODE128',
    title: (j['title'] as String?) ?? '',
    lines: ((j['lines'] as List?) ?? const []).map((e) => e.toString()).toList(),
  );
}

/// Hasil `GET /api/scan/:code`.
class ScanResult {
  const ScanResult({
    required this.type,
    required this.code,
    this.product,
    this.batch,
    this.location,
    this.gs1,
    this.balances = const [],
    this.availableQuantity,
    this.package,
    this.packages = const [],
    this.temporary,
  });

  final ScanType type;
  final String code;
  final ProductBrief? product;
  final BatchInfo? batch;
  final LocationInfo? location;
  final Gs1Data? gs1;
  final List<InventoryBalance> balances;
  /// Untuk scan produk: stok AVAILABLE layak keluar di gudang aktif.
  final int? availableQuantity;
  /// Barcode yang discan adalah barcode kemasan (karton/box): 1 scan = conversionFactor x base unit.
  final PackageInfo? package;
  /// Semua kemasan aktif produk (pilihan satuan).
  final List<PackageInfo> packages;
  final TemporaryReceiving? temporary;

  factory ScanResult.fromJson(Map<String, dynamic> j) {
    final type = switch (j['type']) {
      'BATCH' => ScanType.batch,
      'LOCATION' => ScanType.location,
      'TEMPORARY' => ScanType.temporary,
      _ => ScanType.product,
    };
    final stock = j['stock'] as Map<String, dynamic>?;
    return ScanResult(
      type: type,
      code: j['code'] as String,
      product: j['product'] == null ? null : ProductBrief.fromJson(j['product'] as Map<String, dynamic>),
      batch: j['batch'] == null ? null : BatchInfo.fromJson(j['batch'] as Map<String, dynamic>),
      location: j['location'] == null ? null : LocationInfo.fromJson(j['location'] as Map<String, dynamic>),
      gs1: j['gs1'] == null ? null : Gs1Data.fromJson(j['gs1'] as Map<String, dynamic>),
      balances: ((j['balances'] as List?) ?? const [])
          .map((e) => InventoryBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableQuantity: stock == null ? null : _int(stock['eligible']),
      package: j['package'] == null ? null : PackageInfo.fromJson(j['package'] as Map<String, dynamic>),
      packages: ((j['packages'] as List?) ?? const []).map((e) => PackageInfo.fromJson(e as Map<String, dynamic>)).toList(),
      temporary: j['temporary'] == null ? null : TemporaryReceiving.fromJson(j['temporary'] as Map<String, dynamic>),
    );
  }
}

/// Riwayat pergerakan stok (audit trail).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.direction,
    required this.productName,
    required this.quantity,
    this.unit,
    this.batchNumber,
    this.fromLocationCode,
    this.toLocationCode,
    this.fromStatus,
    this.toStatus,
    this.fromWarehouseName,
    this.toWarehouseName,
    this.referenceNumber,
    this.notes,
    this.userName,
    this.createdAt,
  });

  final int id, quantity;
  final String type, direction, productName;
  final String? unit, batchNumber, fromLocationCode, toLocationCode, fromStatus, toStatus;
  final String? fromWarehouseName, toWarehouseName, referenceNumber, notes, userName;
  final DateTime? createdAt;

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    id: _int(j['id']),
    type: j['type'] as String,
    direction: (j['direction'] as String?) ?? 'MOVE',
    productName: j['productName'] as String,
    quantity: _int(j['quantity']),
    unit: j['unit'] as String?,
    batchNumber: j['batchNumber'] as String?,
    fromLocationCode: j['fromLocationCode'] as String?,
    toLocationCode: j['toLocationCode'] as String?,
    fromStatus: j['fromStatus'] as String?,
    toStatus: j['toStatus'] as String?,
    fromWarehouseName: j['fromWarehouseName'] as String?,
    toWarehouseName: j['toWarehouseName'] as String?,
    referenceNumber: j['referenceNumber'] as String?,
    notes: j['notes'] as String?,
    userName: j['userName'] as String?,
    createdAt: _date(j['createdAt']),
  );

  static String typeLabel(String type) => switch (type) {
    'receiving' => 'Receiving',
    'putaway' => 'Putaway',
    'qc_transfer' => 'QC Transfer',
    'qc_inspection' => 'QC Inspection',
    'qc_release' => 'QC Release',
    'qc_return' => 'Retur Supplier',
    'qc_scrap' => 'Scrap / Write Off',
    'qc_rework' => 'Rework',
    'qc_reinspect' => 'Reinspeksi',
    'issuing' => 'Issuing',
    'transfer_out' => 'Transfer Kirim',
    'transfer_in' => 'Transfer Terima',
    'opname_adjustment' => 'Penyesuaian Opname',
    'opening_balance' => 'Saldo Awal',
    _ => type,
  };
}

/// Riwayat pemeriksaan QC.
class QcInspection {
  const QcInspection({
    required this.id,
    required this.number,
    required this.batchNumber,
    required this.productName,
    required this.result,
    required this.quantityInspected,
    required this.quantityPassed,
    required this.quantityFailed,
    required this.quantityHeld,
    this.sourceStatus,
    this.rejectionReason,
    this.holdReason,
    this.notes,
    this.inspectorName,
    this.inspectedAt,
    this.parentInspectionId,
  });

  final String id, number, batchNumber, productName, result;
  final int quantityInspected, quantityPassed, quantityFailed, quantityHeld;
  final String? sourceStatus, rejectionReason, holdReason, notes, inspectorName, parentInspectionId;
  final DateTime? inspectedAt;

  factory QcInspection.fromJson(Map<String, dynamic> j) => QcInspection(
    id: j['id'] as String,
    number: j['number'] as String,
    batchNumber: (j['batchNumber'] as String?) ?? '-',
    productName: (j['productName'] as String?) ?? '-',
    result: j['result'] as String,
    quantityInspected: _int(j['quantityInspected']),
    quantityPassed: _int(j['quantityPassed']),
    quantityFailed: _int(j['quantityFailed']),
    quantityHeld: _int(j['quantityHeld']),
    sourceStatus: j['sourceStatus'] as String?,
    rejectionReason: j['rejectionReason'] as String?,
    holdReason: j['holdReason'] as String?,
    notes: j['notes'] as String?,
    inspectorName: j['inspectorName'] as String?,
    inspectedAt: _date(j['inspectedAt']),
    parentInspectionId: j['parentInspectionId'] as String?,
  );
}
