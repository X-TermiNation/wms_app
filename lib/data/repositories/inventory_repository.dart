import '../../services/api/api_client.dart';
import '../models/inventory_models.dart';

/// Akses API operasional gudang: scan lookup, saldo batch, putaway, QC, riwayat.
/// Semua perubahan stok terjadi di backend; Flutter hanya mengirim perintah.
class InventoryRepository {
  InventoryRepository._();
  static final InventoryRepository instance = InventoryRepository._();

  final _api = ApiClient.instance;

  /// Lookup barcode (produk / GS1 / batch / lokasi). 404 = item belum terdaftar.
  Future<ScanResult> scan(String code, {String? warehouseId}) async {
    final data = await _api.get('/scan/${Uri.encodeComponent(code)}', query: {'warehouseId': warehouseId});
    return ScanResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InventoryBalance>> balances({
    String? warehouseId,
    List<String>? statuses,
    String? locationId,
    String? locationType,
    String? productId,
    String? lotId,
    String? search,
  }) =>
      _api.getList('/inventory/balances', InventoryBalance.fromJson, query: {
        'warehouseId': warehouseId,
        'status': statuses?.join(','),
        'locationId': locationId,
        'locationType': locationType,
        'productId': productId,
        'lotId': lotId,
        'search': search,
      });

  Future<List<StockMovement>> movements({String? warehouseId, String? lotId, String? productId, int limit = 100}) =>
      _api.getList('/stock-movements', StockMovement.fromJson,
          query: {'warehouseId': warehouseId, 'lotId': lotId, 'productId': productId, 'limit': limit});

  Future<List<QcInspection>> inspections({String? warehouseId, String? lotId, int limit = 50}) =>
      _api.getList('/qc/inspections', QcInspection.fromJson,
          query: {'warehouseId': warehouseId, 'lotId': lotId, 'limit': limit});

  /// Putaway / QC transfer / QC release memakai bentuk request yang sama.
  Future<Map<String, dynamic>> move(
    String endpoint, {
    required String warehouseId,
    required InventoryBalance source,
    required LocationInfo destination,
    required int quantity,
    String notes = '',
    required String idempotencyKey,
  }) async {
    final data = await _api.post(endpoint, {
      'warehouseId': warehouseId,
      'lotId': source.lotId,
      'fromLocationId': source.locationId,
      'fromStatus': source.status,
      'toLocationId': destination.id,
      'quantity': quantity,
      'notes': notes,
    }, idempotencyKey);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<QcInspection> inspect({
    required String warehouseId,
    required InventoryBalance source,
    required int passed,
    required int failed,
    required int held,
    bool recheck = false,
    String rejectionReason = '',
    String holdReason = '',
    String notes = '',
    required String idempotencyKey,
  }) async {
    final data = await _api.post('/qc/inspections', {
      'warehouseId': warehouseId,
      'lotId': source.lotId,
      'fromLocationId': source.locationId,
      'fromStatus': source.status,
      'passed': passed,
      'failed': failed,
      'held': held,
      'recheck': recheck,
      'rejectionReason': rejectionReason,
      'holdReason': holdReason,
      'notes': notes,
    }, idempotencyKey);
    return QcInspection.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> disposition({
    required String warehouseId,
    required InventoryBalance source,
    required int quantity,
    required String action,
    required String reason,
    String notes = '',
    required String idempotencyKey,
  }) async {
    final data = await _api.post('/qc/dispositions', {
      'warehouseId': warehouseId,
      'lotId': source.lotId,
      'fromLocationId': source.locationId,
      'quantity': quantity,
      'action': action,
      'reason': reason,
      'notes': notes,
    }, idempotencyKey);
    return Map<String, dynamic>.from(data as Map);
  }
}
