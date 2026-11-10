
enum ReceivingStatus { draft, pending, completed, cancelled }

class ReceivingItemModel {
  const ReceivingItemModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final int quantity;
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

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

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
  );
}
