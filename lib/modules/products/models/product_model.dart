/// Master item (global). Di SUNMI hanya dibaca; registrasi & edit item
/// dilakukan dari aplikasi Desktop.
class ProductModel {
  ProductModel({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.category,
    required this.unit,
    required this.stock,
    required this.minimumStock,
    this.location = '-',
    this.warehouseId,
    this.locationId,
    this.categoryId,
    this.availableStock = 0,
    this.qcStock = 0,
    this.requiresQc = false,
    this.hasExpiry = false,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String category;
  final String unit;
  /// Total on-hand (semua status, termasuk QC).
  final int stock;
  final int minimumStock;
  final String location;
  final String? warehouseId;
  final String? locationId;
  final String? categoryId;
  /// Stok AVAILABLE yang layak dikeluarkan (belum kedaluwarsa).
  final int availableStock;
  /// Stok yang masih dalam proses QC.
  final int qcStock;
  final bool requiresQc;
  final bool hasExpiry;
  final String? imageUrl;
  final bool isActive;

  bool get isLowStock => availableStock <= minimumStock;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'] as String,
    sku: json['sku'] as String,
    barcode: json['barcode'] as String,
    name: json['name'] as String,
    category: (json['category'] as String?) ?? '-',
    categoryId: json['categoryId'] as String?,
    unit: (json['unit'] as String?) ?? 'PCS',
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    minimumStock: (json['minimumStock'] as num?)?.toInt() ?? 0,
    location: (json['location'] as String?) ?? '-',
    warehouseId: json['warehouseId'] as String?,
    locationId: json['locationId'] as String?,
    availableStock: (json['availableStock'] as num?)?.toInt() ?? 0,
    qcStock: (json['qcStock'] as num?)?.toInt() ?? 0,
    requiresQc: json['requiresQc'] == true,
    hasExpiry: json['hasExpiry'] == true,
    imageUrl: json['imageUrl'] as String?,
    isActive: json['isActive'] != false,
  );

  // Dibandingkan berdasarkan id agar Dropdown tetap valid setelah data
  // dimuat ulang dari server (instance baru, produk sama).
  @override
  bool operator ==(Object other) => other is ProductModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
