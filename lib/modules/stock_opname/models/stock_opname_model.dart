enum OpnameStatus { draft, completed, cancelled }

/// Satu baris hitung: batch x lokasi x status stok.
class StockOpnameItemModel {
  const StockOpnameItemModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.systemStock,
    required this.physicalStock,
    this.lotId,
    this.batchNumber,
    this.expiryDate,
    this.locationId,
    this.locationCode,
    this.inventoryStatus,
  });

  final String productId, productName, sku, unit;
  final int systemStock, physicalStock;
  final String? lotId, batchNumber, locationId, locationCode, inventoryStatus;
  final DateTime? expiryDate;
  int get difference => physicalStock - systemStock;

  factory StockOpnameItemModel.fromJson(Map<String, dynamic> json) => StockOpnameItemModel(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    sku: json['sku'] as String,
    unit: json['unit'] as String,
    systemStock: (json['systemStock'] as num).toInt(),
    physicalStock: (json['physicalStock'] as num).toInt(),
    lotId: json['lotId'] as String?,
    batchNumber: json['batchNumber'] as String?,
    expiryDate: json['expiryDate'] == null ? null : DateTime.parse(json['expiryDate'] as String),
    locationId: json['locationId'] as String?,
    locationCode: json['locationCode'] as String?,
    inventoryStatus: json['inventoryStatus'] as String?,
  );

  /// systemStock tidak dikirim: dihitung server dari saldo batch di lokasi tsb.
  Map<String, dynamic> toJson() => {
    'lotId': lotId,
    'locationId': locationId,
    'status': inventoryStatus,
    'physicalStock': physicalStock,
  };
}

class StockOpnameModel {
  const StockOpnameModel({
    required this.id,
    required this.number,
    required this.date,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.items,
    this.notes = '',
    this.locationCode,
  });

  final String id, number, warehouseId, warehouseName, notes;
  final String? locationCode;
  final DateTime date;
  final OpnameStatus status;
  final List<StockOpnameItemModel> items;

  int get totalDifference => items.fold(0, (s, i) => s + i.difference);

  factory StockOpnameModel.fromJson(Map<String, dynamic> json) => StockOpnameModel(
    id: json['id'] as String,
    number: json['number'] as String,
    date: DateTime.parse(json['date'] as String),
    warehouseId: json['warehouseId'] as String,
    warehouseName: (json['warehouseName'] as String?) ?? '-',
    status: OpnameStatus.values.byName(json['status'] as String),
    items: ((json['items'] as List?) ?? const [])
        .map((e) => StockOpnameItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: (json['notes'] as String?) ?? '',
    locationCode: json['locationCode'] as String?,
  );
}
