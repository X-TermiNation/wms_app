enum TransferStatus { draft, pending, completed, cancelled }

class TransferItemModel {
  const TransferItemModel({required this.productId, required this.productName, required this.sku, required this.unit, required this.quantity});
  final String productId, productName, sku, unit;
  final int quantity;
}

class TransferModel {
  const TransferModel({required this.id, required this.number, required this.date, required this.sourceWarehouseId, required this.sourceWarehouseName, required this.destinationWarehouseId, required this.destinationWarehouseName, required this.status, required this.items, this.notes = ''});
  final String id, number, sourceWarehouseId, sourceWarehouseName, destinationWarehouseId, destinationWarehouseName, notes;
  final DateTime date;
  final TransferStatus status;
  final List<TransferItemModel> items;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  TransferModel copyWith({TransferStatus? status}) => TransferModel(id: id, number: number, date: date, sourceWarehouseId: sourceWarehouseId, sourceWarehouseName: sourceWarehouseName, destinationWarehouseId: destinationWarehouseId, destinationWarehouseName: destinationWarehouseName, status: status ?? this.status, items: items, notes: notes);
}
