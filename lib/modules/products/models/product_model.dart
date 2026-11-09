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
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String category;
  final String unit;
  final int stock;
  final int minimumStock;
  final String location;

  bool get isLowStock => stock <= minimumStock;
}
