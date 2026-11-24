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
    this.type = 'STORAGE',
    this.barcode,
    this.isActive = true,
  });

  final String id;
  final String warehouseId;
  final String code;
  final String zone;
  final String rack;
  final String bin;
  final LocationStatus status;
  final String description;
  /// RECEIVING, QC_HOLD, QC_INSPECTION, QC_PASS, QC_REJECT, QC_QUARANTINE, STORAGE, TRANSIT.
  final String type;
  /// Barcode lokasi (dibuat dari Desktop), dipakai untuk scan.
  final String? barcode;
  final bool isActive;

  bool get isSystem => type != 'STORAGE';

  factory WarehouseLocationModel.fromJson(Map<String, dynamic> json) => WarehouseLocationModel(
    id: json['id'] as String,
    warehouseId: json['warehouseId'] as String,
    code: json['code'] as String,
    zone: json['zone'] as String,
    rack: json['rack'] as String,
    bin: json['bin'] as String,
    status: LocationStatus.values.byName(json['status'] as String),
    description: (json['description'] as String?) ?? '',
    type: (json['type'] as String?) ?? 'STORAGE',
    barcode: json['barcode'] as String?,
    isActive: json['isActive'] != false,
  );
}
