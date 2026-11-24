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

  factory WarehouseModel.fromJson(Map<String, dynamic> json) => WarehouseModel(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    address: (json['address'] as String?) ?? '',
    isActive: json['isActive'] == true,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'address': address,
    'isActive': isActive,
  };
}
