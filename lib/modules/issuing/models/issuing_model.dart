enum IssuingStatus { draft, pending, completed, cancelled }

class IssuingItemModel {
  const IssuingItemModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
    this.lotId,
    this.batchNumber,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final int quantity;
  /// Diisi jika staff scan batch tertentu; kosong = backend memilih FEFO.
  final String? lotId;
  final String? batchNumber;

  IssuingItemModel copyWith({int? quantity}) => IssuingItemModel(
    productId: productId, productName: productName, sku: sku, unit: unit,
    quantity: quantity ?? this.quantity, lotId: lotId, batchNumber: batchNumber,
  );

  factory IssuingItemModel.fromJson(Map<String, dynamic> json) => IssuingItemModel(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    sku: json['sku'] as String,
    unit: json['unit'] as String,
    quantity: (json['quantity'] as num).toInt(),
    lotId: json['lotId'] as String?,
    batchNumber: json['batchNumber'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    if (lotId != null) 'lotId': lotId,
  };
}

/// Alokasi batch hasil FEFO (tercatat untuk traceability).
class IssuingAllocation {
  const IssuingAllocation({required this.productId, required this.batchNumber, required this.locationCode, required this.quantity, this.expiryDate});

  final String productId, batchNumber, locationCode;
  final int quantity;
  final DateTime? expiryDate;

  factory IssuingAllocation.fromJson(Map<String, dynamic> j) => IssuingAllocation(
    productId: j['productId'] as String,
    batchNumber: j['batchNumber'] as String,
    locationCode: j['locationCode'] as String,
    quantity: (j['quantity'] as num).toInt(),
    expiryDate: j['expiryDate'] == null ? null : DateTime.parse(j['expiryDate'] as String),
  );
}

class IssuingModel {
  const IssuingModel({
    required this.id,
    required this.number,
    required this.date,
    required this.destination,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.items,
    this.allocations = const [],
    this.notes = '',
    this.documentRef,
    this.shippingStatus,
    this.packingNumber,
    this.shipmentNumber,
  });

  final String id;
  final String number;
  final DateTime date;
  final String destination;
  final String warehouseId;
  final String warehouseName;
  final IssuingStatus status;
  final List<IssuingItemModel> items;
  final List<IssuingAllocation> allocations;
  final String notes;

  /// Nomor PO / SO ERP (atau dokumen WMS manual) yang menjadi acuan; null = tanpa dokumen.
  final String? documentRef;

  /// Tahap pengiriman setelah picking: PICKED, PACKED, LOADED, DISPATCHED, DELIVERED (null = transaksi lama).
  final String? shippingStatus;
  final String? packingNumber;
  final String? shipmentNumber;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  factory IssuingModel.fromJson(Map<String, dynamic> json) => IssuingModel(
    id: json['id'] as String,
    number: json['number'] as String,
    date: DateTime.parse(json['date'] as String),
    destination: json['destination'] as String,
    warehouseId: json['warehouseId'] as String,
    warehouseName: (json['warehouseName'] as String?) ?? '-',
    status: IssuingStatus.values.byName(json['status'] as String),
    items: ((json['items'] as List?) ?? const [])
        .map((e) => IssuingItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    allocations: ((json['allocations'] as List?) ?? const [])
        .map((e) => IssuingAllocation.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: (json['notes'] as String?) ?? '',
    documentRef: (json['erpDocumentNo'] ?? json['outboundDocumentNumber']) as String?,
    shippingStatus: json['shippingStatus'] as String?,
    packingNumber: json['packingNumber'] as String?,
    shipmentNumber: json['shipmentNumber'] as String?,
  );

  IssuingModel copyWith({IssuingStatus? status}) => IssuingModel(
    id: id,
    number: number,
    date: date,
    destination: destination,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    status: status ?? this.status,
    items: items,
    allocations: allocations,
    notes: notes,
    documentRef: documentRef,
    shippingStatus: shippingStatus,
    packingNumber: packingNumber,
    shipmentNumber: shipmentNumber,
  );
}
