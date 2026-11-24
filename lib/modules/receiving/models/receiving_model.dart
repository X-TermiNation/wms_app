import '../../../services/api/api_client.dart';

enum ReceivingStatus { draft, pending, completed, cancelled }

class ReceivingItemModel {
  const ReceivingItemModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
    this.expiryDate,
    this.supplierLot,
    this.batchNumber,
    this.requiresQc,
    this.packageUnit,
    this.packageQuantity,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final int quantity;
  final DateTime? expiryDate;
  /// Nomor lot dari supplier (opsional).
  final String? supplierLot;
  /// Batch internal yang dibuat backend saat penerimaan dikonfirmasi.
  final String? batchNumber;
  final bool? requiresQc;
  /// Diterima dalam kemasan (mis. 3 BOX); [quantity] tetap dalam base unit.
  final String? packageUnit;
  final int? packageQuantity;

  ReceivingItemModel copyWith({int? quantity}) => ReceivingItemModel(
    productId: productId,
    productName: productName,
    sku: sku,
    unit: unit,
    quantity: quantity ?? this.quantity,
    expiryDate: expiryDate,
    supplierLot: supplierLot,
    batchNumber: batchNumber,
    requiresQc: requiresQc,
  );

  /// Baris dengan produk + lot supplier + expiry yang sama digabung.
  bool sameLine(ReceivingItemModel o) =>
      productId == o.productId &&
      (supplierLot ?? '') == (o.supplierLot ?? '') &&
      expiryDate?.toIso8601String().substring(0, 10) == o.expiryDate?.toIso8601String().substring(0, 10);

  factory ReceivingItemModel.fromJson(Map<String, dynamic> json) => ReceivingItemModel(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    sku: json['sku'] as String,
    unit: json['unit'] as String,
    quantity: (json['quantity'] as num).toInt(),
    expiryDate: json['expiryDate'] == null ? null : DateTime.parse(json['expiryDate'] as String),
    supplierLot: json['supplierLot'] as String?,
    batchNumber: json['batchNumber'] as String?,
    requiresQc: json['requiresQc'] as bool?,
    packageUnit: json['packageUnit'] as String?,
    packageQuantity: (json['packageQuantity'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'supplierLot': supplierLot,
    'expiryDate': expiryDate == null ? null : ApiClient.formatDate(expiryDate!),
  };
}

class ReceivingModel {
  const ReceivingModel({
    required this.id,
    required this.number,
    required this.date,
    required this.supplier,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.items,
    this.notes = '',
    this.documentRef,
  });

  final String id;
  final String number;
  final DateTime date;
  final String supplier;
  final String warehouseId;
  final String warehouseName;
  final ReceivingStatus status;
  final List<ReceivingItemModel> items;
  final String notes;

  /// Nomor PO / SO ERP (atau dokumen WMS manual) yang menjadi acuan; null = tanpa dokumen.
  final String? documentRef;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  factory ReceivingModel.fromJson(Map<String, dynamic> json) => ReceivingModel(
    id: json['id'] as String,
    number: json['number'] as String,
    date: DateTime.parse(json['date'] as String),
    supplier: json['supplier'] as String,
    warehouseId: json['warehouseId'] as String,
    warehouseName: (json['warehouseName'] as String?) ?? '-',
    status: ReceivingStatus.values.byName(json['status'] as String),
    items: ((json['items'] as List?) ?? const [])
        .map((e) => ReceivingItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: (json['notes'] as String?) ?? '',
    documentRef: (json['erpDocumentNo'] ?? json['inboundDocumentNumber']) as String?,
  );

  ReceivingModel copyWith({ReceivingStatus? status}) => ReceivingModel(
    id: id,
    number: number,
    date: date,
    supplier: supplier,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    status: status ?? this.status,
    items: items,
    notes: notes,
    documentRef: documentRef,
  );
}

/// Batch yang dibuat backend saat penerimaan dikonfirmasi.
class CreatedBatch {
  const CreatedBatch({required this.batchNumber, required this.productName, required this.quantity, required this.status, required this.locationCode});

  final String batchNumber, productName, status, locationCode;
  final int quantity;

  factory CreatedBatch.fromJson(Map<String, dynamic> j) => CreatedBatch(
    batchNumber: j['batchNumber'] as String,
    productName: j['productName'] as String,
    quantity: (j['quantity'] as num).toInt(),
    status: j['status'] as String,
    locationCode: j['locationCode'] as String,
  );
}
