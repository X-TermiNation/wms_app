/// draft -> pending -> inTransit (dikirim) -> completed (diterima penuh); draft/pending -> cancelled.
enum TransferStatus {
  draft('draft'),
  pending('pending'),
  inTransit('in_transit'),
  completed('completed'),
  cancelled('cancelled');

  const TransferStatus(this.apiValue);
  final String apiValue;

  static TransferStatus fromApi(String value) =>
      TransferStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => TransferStatus.draft);
}

class TransferItemModel {
  const TransferItemModel({
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

  factory TransferItemModel.fromJson(Map<String, dynamic> json) => TransferItemModel(
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

/// Batch yang dikirim (hasil FEFO) beserta qty yang sudah diterima gudang tujuan.
class TransferLotModel {
  const TransferLotModel({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.lotId,
    required this.batchNumber,
    required this.quantity,
    required this.receivedQuantity,
    this.expiryDate,
  });

  final String productId, productName, unit, lotId, batchNumber;
  final int quantity, receivedQuantity;
  final DateTime? expiryDate;
  int get remaining => quantity - receivedQuantity;

  factory TransferLotModel.fromJson(Map<String, dynamic> j) => TransferLotModel(
    productId: j['productId'] as String,
    productName: j['productName'] as String,
    unit: j['unit'] as String,
    lotId: j['lotId'] as String,
    batchNumber: j['batchNumber'] as String,
    quantity: (j['quantity'] as num).toInt(),
    receivedQuantity: (j['receivedQuantity'] as num).toInt(),
    expiryDate: j['expiryDate'] == null ? null : DateTime.parse(j['expiryDate'] as String),
  );
}

class TransferModel {
  const TransferModel({
    required this.id,
    required this.number,
    required this.date,
    required this.sourceWarehouseId,
    required this.sourceWarehouseName,
    required this.destinationWarehouseId,
    required this.destinationWarehouseName,
    required this.status,
    required this.items,
    this.lots = const [],
    this.notes = '',
  });
  final String id, number, sourceWarehouseId, sourceWarehouseName, destinationWarehouseId, destinationWarehouseName, notes;
  final DateTime date;
  final TransferStatus status;
  final List<TransferItemModel> items;
  final List<TransferLotModel> lots;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  int get remainingQuantity => lots.fold(0, (sum, l) => sum + l.remaining);

  factory TransferModel.fromJson(Map<String, dynamic> json) => TransferModel(
    id: json['id'] as String,
    number: json['number'] as String,
    date: DateTime.parse(json['date'] as String),
    sourceWarehouseId: json['sourceWarehouseId'] as String,
    sourceWarehouseName: (json['sourceWarehouseName'] as String?) ?? '-',
    destinationWarehouseId: json['destinationWarehouseId'] as String,
    destinationWarehouseName: (json['destinationWarehouseName'] as String?) ?? '-',
    status: TransferStatus.fromApi(json['status'] as String),
    items: ((json['items'] as List?) ?? const [])
        .map((e) => TransferItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    lots: ((json['lots'] as List?) ?? const [])
        .map((e) => TransferLotModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: (json['notes'] as String?) ?? '',
  );
}
