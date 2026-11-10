enum IssuingStatus { draft, pending, completed, cancelled }

class IssuingItemModel {
  const IssuingItemModel({
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
    this.notes = '',
  });

  final String id;
  final String number;
  final DateTime date;
  final String destination;
  final String warehouseId;
  final String warehouseName;
  final IssuingStatus status;
  final List<IssuingItemModel> items;
  final String notes;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  IssuingModel copyWith({IssuingStatus? status}) => IssuingModel(
    id: id,
    number: number,
    date: date,
    destination: destination,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    status: status ?? this.status,
    items: items,
    notes: notes,
  );
}
