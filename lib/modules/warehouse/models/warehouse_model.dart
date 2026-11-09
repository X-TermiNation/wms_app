class WarehouseModel {
  const WarehouseModel({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String address;
  final bool isActive;
}
