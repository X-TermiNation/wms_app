enum LocationStatus { available, occupied, blocked }

class WarehouseLocationModel {
  const WarehouseLocationModel({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.zone,
    required this.rack,
    required this.bin,
    required this.status,
    this.description = '',
  });

  final String id;
  final String warehouseId;
  final String code;
  final String zone;
  final String rack;
  final String bin;
  final LocationStatus status;
  final String description;
}
