/// Model alur pengiriman (backend 006): Picking (issuing) -> Packing -> Loading -> Dispatch -> Delivered.
library;

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
double? _d(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<Map<String, dynamic>> _maps(Object? v) => ((v as List?) ?? const []).cast<Map<String, dynamic>>();

/// Label tahap pengiriman issuing (issuings.shipping_status).
String shippingStageLabel(String? s) => switch (s) {
      'PICKED' => 'Siap packing',
      'PACKED' => 'Siap dimuat',
      'LOADED' => 'Sudah dimuat',
      'DISPATCHED' => 'Dalam pengiriman',
      'DELIVERED' => 'Diterima customer',
      _ => '-',
    };

/// Issuing yang sudah di-pick dan menunggu packing.
class PackingQueueItem {
  const PackingQueueItem({
    required this.issuingId, required this.issuingNumber, required this.destination, required this.totalQuantity,
    required this.totalLines, this.erpDocumentNo, this.outboundDocumentNumber, this.date,
  });
  factory PackingQueueItem.fromJson(Map<String, dynamic> j) => PackingQueueItem(
        issuingId: '${j['issuingId']}', issuingNumber: '${j['issuingNumber']}', destination: '${j['destination'] ?? ''}',
        totalQuantity: _i(j['totalQuantity']), totalLines: _i(j['totalLines']), erpDocumentNo: _s(j['erpDocumentNo']),
        outboundDocumentNumber: _s(j['outboundDocumentNumber']), date: _dt(j['date']),
      );
  final String issuingId, issuingNumber, destination;
  final int totalQuantity, totalLines;
  final String? erpDocumentNo, outboundDocumentNumber;
  final DateTime? date;
}

/// Baris rencana packing = hasil picking FEFO (produk x batch).
class PackingLine {
  const PackingLine({
    required this.productId, required this.sku, required this.productName, required this.unit, this.lotId, this.batchNumber,
    this.expiryDate, required this.pickedQuantity, required this.packedQuantity, required this.remainingQuantity,
  });
  factory PackingLine.fromJson(Map<String, dynamic> j) => PackingLine(
        productId: '${j['productId']}', sku: '${j['sku']}', productName: '${j['productName']}', unit: '${j['unit'] ?? ''}',
        lotId: _s(j['lotId']), batchNumber: _s(j['batchNumber']), expiryDate: _dt(j['expiryDate']),
        pickedQuantity: _i(j['pickedQuantity']), packedQuantity: _i(j['packedQuantity']), remainingQuantity: _i(j['remainingQuantity']),
      );
  final String productId, sku, productName, unit;
  final String? lotId, batchNumber;
  final DateTime? expiryDate;
  final int pickedQuantity, packedQuantity, remainingQuantity;
  bool get done => remainingQuantity == 0;
}

class CartonItem {
  const CartonItem({required this.id, required this.sku, required this.productName, required this.unit, this.batchNumber, required this.quantity});
  factory CartonItem.fromJson(Map<String, dynamic> j) => CartonItem(
        id: _i(j['id']), sku: '${j['sku']}', productName: '${j['productName']}', unit: '${j['unit'] ?? ''}',
        batchNumber: _s(j['batchNumber']), quantity: _i(j['quantity']),
      );
  final int id, quantity;
  final String sku, productName, unit;
  final String? batchNumber;
}

class Carton {
  const Carton({
    required this.id, required this.seq, required this.code, required this.status, this.weightKg, this.loadedAt,
    required this.totalQuantity, this.items = const [],
  });
  factory Carton.fromJson(Map<String, dynamic> j) => Carton(
        id: '${j['id']}', seq: _i(j['seq']), code: '${j['code']}', status: '${j['status']}', weightKg: _d(j['weightKg']),
        loadedAt: _dt(j['loadedAt']), totalQuantity: _i(j['totalQuantity']), items: _maps(j['items']).map(CartonItem.fromJson).toList(),
      );
  final String id, code, status;
  final int seq, totalQuantity;
  final double? weightKg;
  final DateTime? loadedAt;
  final List<CartonItem> items;
  bool get isOpen => status == 'OPEN';
  bool get loaded => loadedAt != null;
}

class Packing {
  const Packing({
    required this.id, required this.number, required this.status, required this.issuingId, required this.issuingNumber,
    required this.destination, this.erpDocumentNo, this.outboundDocumentNumber, this.shipmentNumber, required this.totalPicked,
    required this.totalPacked, required this.totalRemaining, required this.totalCartons, required this.loadedCartons,
    required this.totalWeightKg, this.lines = const [], this.cartons = const [],
  });
  factory Packing.fromJson(Map<String, dynamic> j) => Packing(
        id: '${j['id']}', number: '${j['number']}', status: '${j['status']}', issuingId: '${j['issuingId']}',
        issuingNumber: '${j['issuingNumber']}', destination: '${j['destination'] ?? ''}', erpDocumentNo: _s(j['erpDocumentNo']),
        outboundDocumentNumber: _s(j['outboundDocumentNumber']), shipmentNumber: _s(j['shipmentNumber']),
        totalPicked: _i(j['totalPicked']), totalPacked: _i(j['totalPacked']), totalRemaining: _i(j['totalRemaining']),
        totalCartons: _i(j['totalCartons']), loadedCartons: _i(j['loadedCartons']), totalWeightKg: _d(j['totalWeightKg']) ?? 0,
        lines: _maps(j['lines']).map(PackingLine.fromJson).toList(), cartons: _maps(j['cartons']).map(Carton.fromJson).toList(),
      );
  final String id, number, status, issuingId, issuingNumber, destination;
  final String? erpDocumentNo, outboundDocumentNumber, shipmentNumber;
  final int totalPicked, totalPacked, totalRemaining, totalCartons, loadedCartons;
  final double totalWeightKg;
  final List<PackingLine> lines;
  final List<Carton> cartons;

  bool get isOpen => status == 'OPEN';
  bool get complete => totalPicked > 0 && totalRemaining == 0;

  /// Nomor yang dikenal customer: SO ERP bila ada, selain itu nomor issuing.
  String get reference => erpDocumentNo ?? outboundDocumentNumber ?? issuingNumber;

  /// Koli tujuan scan berikutnya: koli OPEN terakhir.
  Carton? get currentCarton {
    final open = cartons.where((c) => c.isOpen).toList();
    return open.isEmpty ? null : open.last;
  }

  String get statusLabel => switch (status) { 'OPEN' => 'Sedang packing', 'PACKED' => 'Selesai packing', _ => 'Dibatalkan' };
}

class Shipment {
  const Shipment({
    required this.id, required this.number, required this.status, required this.warehouseId, this.plannedDate, required this.carrier,
    required this.vehicleType, required this.vehiclePlate, required this.driverName, required this.driverPhone, required this.dock,
    this.sealNumber, this.dispatchedAt, this.deliveredAt, this.receiverName, required this.totalPackings, required this.totalCartons,
    required this.loadedCartons, required this.totalQuantity, required this.totalWeightKg, this.destinations = const [],
    this.documents = const [], this.packings = const [], this.cartons = const [],
  });
  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        id: '${j['id']}', number: '${j['number']}', status: '${j['status']}', warehouseId: '${j['warehouseId']}',
        plannedDate: _dt(j['plannedDate']), carrier: '${j['carrier'] ?? ''}', vehicleType: '${j['vehicleType'] ?? ''}',
        vehiclePlate: '${j['vehiclePlate'] ?? ''}', driverName: '${j['driverName'] ?? ''}', driverPhone: '${j['driverPhone'] ?? ''}',
        dock: '${j['dock'] ?? ''}', sealNumber: _s(j['sealNumber']), dispatchedAt: _dt(j['dispatchedAt']), deliveredAt: _dt(j['deliveredAt']),
        receiverName: _s(j['receiverName']), totalPackings: _i(j['totalPackings']), totalCartons: _i(j['totalCartons']),
        loadedCartons: _i(j['loadedCartons']), totalQuantity: _i(j['totalQuantity']), totalWeightKg: _d(j['totalWeightKg']) ?? 0,
        destinations: ((j['destinations'] as List?) ?? const []).map((e) => '$e').toList(),
        documents: ((j['documents'] as List?) ?? const []).map((e) => '$e').toList(),
        packings: _maps(j['packings']).map(Packing.fromJson).toList(),
        cartons: _maps(j['cartons']).map(Carton.fromJson).toList(),
      );
  final String id, number, status, warehouseId, carrier, vehicleType, vehiclePlate, driverName, driverPhone, dock;
  final DateTime? plannedDate, dispatchedAt, deliveredAt;
  final String? sealNumber, receiverName;
  final int totalPackings, totalCartons, loadedCartons, totalQuantity;
  final double totalWeightKg;
  final List<String> destinations, documents;
  final List<Packing> packings;
  final List<Carton> cartons;

  bool get editable => status == 'PLANNED' || status == 'LOADING';
  bool get allLoaded => totalCartons > 0 && loadedCartons == totalCartons;

  String get statusLabel => switch (status) {
        'PLANNED' => 'Direncanakan',
        'LOADING' => 'Sedang dimuat',
        'DISPATCHED' => 'Dalam pengiriman',
        'DELIVERED' => 'Diterima',
        _ => 'Dibatalkan',
      };

  String get vehicleLabel => [vehiclePlate, vehicleType].where((e) => e.isNotEmpty).join(' · ');
}
