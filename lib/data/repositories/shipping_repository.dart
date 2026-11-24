import '../../services/api/api_client.dart';
import '../models/shipping_models.dart';

/// Packing, loading, dispatch, dan POD (backend /api/packings & /api/shipments).
class ShippingRepository {
  ShippingRepository._();
  static final ShippingRepository instance = ShippingRepository._();

  final _api = ApiClient.instance;

  Packing _packing(dynamic d) => Packing.fromJson(d as Map<String, dynamic>);
  Shipment _shipment(dynamic d) => Shipment.fromJson(d as Map<String, dynamic>);

  // ------------------------------------------------------------------ packing
  /// Issuing siap packing + packing yang masih berjalan di gudang aktif.
  Future<(List<PackingQueueItem>, List<Packing>)> packingQueue(String warehouseId) async {
    final data = await _api.get('/packings/queue', query: {'warehouseId': warehouseId}) as Map<String, dynamic>;
    return (
      ((data['ready'] as List?) ?? const []).map((e) => PackingQueueItem.fromJson(e as Map<String, dynamic>)).toList(),
      ((data['open'] as List?) ?? const []).map(_packing).toList(),
    );
  }

  Future<Packing> packing(String idOrNumber) async => _packing(await _api.get('/packings/${Uri.encodeComponent(idOrNumber)}'));

  /// Mulai (atau lanjutkan) packing untuk issuing / nomor ISS.
  Future<Packing> startPacking(String issuingIdOrNumber) async =>
      _packing(await _api.post('/packings', {'issuingId': issuingIdOrNumber}, _api.newIdempotencyKey()));

  /// Scan barang ke koli. Respons berisi packing terbaru + `lastScan`.
  Future<(Packing, Map<String, dynamic>?)> scanToCarton(String packingId, String code, {int quantity = 1, String? cartonId}) async {
    final data = await _api.post('/packings/$packingId/scan', {'code': code, 'quantity': quantity, 'cartonId': ?cartonId},
        _api.newIdempotencyKey()) as Map<String, dynamic>;
    return (Packing.fromJson(data), data['lastScan'] as Map<String, dynamic>?);
  }

  Future<Packing> removeItem(String packingId, int itemId) async => _packing(await _api.delete('/packings/$packingId/items/$itemId'));

  Future<Packing> newCarton(String packingId) async => _packing(await _api.post('/packings/$packingId/cartons', {}, _api.newIdempotencyKey()));

  Future<Packing> updateCarton(String packingId, String cartonId, {double? weightKg, String? status}) async => _packing(
        await _api.patch('/packings/$packingId/cartons/$cartonId', {'weightKg': ?weightKg, 'status': ?status}),
      );

  Future<Packing> completePacking(String packingId) async =>
      _packing(await _api.post('/packings/$packingId/complete', {}, _api.newIdempotencyKey()));

  Future<Packing> cancelPacking(String packingId) async => _packing(await _api.post('/packings/$packingId/cancel', {}));

  // ------------------------------------------------------------------ shipment
  Future<List<Shipment>> shipments(String warehouseId, {String status = 'ACTIVE'}) async =>
      ((await _api.get('/shipments', query: {'warehouseId': warehouseId, 'status': status})) as List).map(_shipment).toList();

  Future<List<Packing>> readyPackings(String warehouseId) async =>
      ((await _api.get('/shipments/ready-packings', query: {'warehouseId': warehouseId})) as List).map(_packing).toList();

  Future<Shipment> shipment(String idOrNumber) async => _shipment(await _api.get('/shipments/${Uri.encodeComponent(idOrNumber)}'));

  Future<Shipment> createShipment(Map<String, dynamic> body) async =>
      _shipment(await _api.post('/shipments', body, _api.newIdempotencyKey()));

  Future<Shipment> addPacking(String shipmentId, String packingId) async =>
      _shipment(await _api.post('/shipments/$shipmentId/packings', {'packingId': packingId}));

  Future<Shipment> removePacking(String shipmentId, String packingId) async =>
      _shipment(await _api.delete('/shipments/$shipmentId/packings/$packingId'));

  /// Scan label koli saat dimuat. Respons berisi shipment terbaru + `lastScan`.
  Future<(Shipment, Map<String, dynamic>?)> loadCarton(String shipmentId, String code) async {
    final data = await _api.post('/shipments/$shipmentId/scan', {'code': code}, _api.newIdempotencyKey()) as Map<String, dynamic>;
    return (Shipment.fromJson(data), data['lastScan'] as Map<String, dynamic>?);
  }

  Future<Shipment> unloadCarton(String shipmentId, String code) async =>
      _shipment(await _api.post('/shipments/$shipmentId/unload', {'code': code}));

  Future<Shipment> dispatch(String shipmentId, {String? sealNumber}) async =>
      _shipment(await _api.post('/shipments/$shipmentId/dispatch', {'sealNumber': ?sealNumber}, _api.newIdempotencyKey()));

  Future<Shipment> deliver(String shipmentId, {required String receiverName, String notes = ''}) async =>
      _shipment(await _api.post('/shipments/$shipmentId/deliver', {'receiverName': receiverName, 'notes': notes}, _api.newIdempotencyKey()));

  Future<Shipment> cancelShipment(String shipmentId) async => _shipment(await _api.post('/shipments/$shipmentId/cancel', {}));
}
