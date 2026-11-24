/// Inventory lot/batch. A null expiryDate means the batch does not expire.
/// Data diambil dari `GET /api/products/:id/lots`.
class ProductStockLotModel {
  const ProductStockLotModel({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    required this.receivedAt,
    this.expiryDate,
  });

  final String id;
  final String productId;
  final String warehouseId;
  final String? locationId;
  final int quantity;
  final DateTime receivedAt;
  final DateTime? expiryDate;

  bool get hasExpiry => expiryDate != null;
  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return expiryDay.isBefore(today);
  }

  factory ProductStockLotModel.fromJson(Map<String, dynamic> json) => ProductStockLotModel(
    id: json['id'] as String,
    productId: json['productId'] as String,
    warehouseId: json['warehouseId'] as String,
    locationId: json['locationId'] as String?,
    quantity: (json['quantity'] as num).toInt(),
    receivedAt: DateTime.parse(json['receivedAt'] as String),
    expiryDate: json['expiryDate'] == null ? null : DateTime.parse(json['expiryDate'] as String),
  );
}

/// Ketersediaan stok produk di satu gudang (`GET /api/products/:id/availability`).
class ProductAvailabilityModel {
  const ProductAvailabilityModel({
    required this.productId,
    required this.warehouseId,
    required this.totalStock,
    required this.warehouseStock,
    required this.eligibleStock,
    required this.expiredStock,
    required this.unit,
  });

  final String productId;
  final String warehouseId;
  /// Stok produk di semua gudang.
  final int totalStock;
  /// Stok produk di gudang ini (termasuk batch kedaluwarsa).
  final int warehouseStock;
  /// Stok yang layak dikeluarkan (FEFO, tanpa batch kedaluwarsa).
  final int eligibleStock;
  final int expiredStock;
  final String unit;

  factory ProductAvailabilityModel.fromJson(Map<String, dynamic> json) => ProductAvailabilityModel(
    productId: json['productId'] as String,
    warehouseId: json['warehouseId'] as String,
    totalStock: (json['totalStock'] as num).toInt(),
    warehouseStock: (json['warehouseStock'] as num).toInt(),
    eligibleStock: (json['eligibleStock'] as num).toInt(),
    expiredStock: (json['expiredStock'] as num).toInt(),
    unit: (json['unit'] as String?) ?? '',
  );
}
