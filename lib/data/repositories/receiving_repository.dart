import 'dart:convert';

import '../../services/api/api_client.dart';
import '../models/inventory_models.dart';

/// Pilihan dropdown dari master data (supplier, kategori, satuan).
class OptionItem {
  const OptionItem(this.id, this.label);
  final String id;
  final String label;
}

/// Produk + kemasan untuk receiving tanpa barcode / package.
class ProductWithPackages {
  const ProductWithPackages(this.product, this.packages);
  final ProductBrief product;
  final List<PackageInfo> packages;
}

/// Receiving pintar, temporary receiving, dan data label. Semua aturan (konversi, batch,
/// keunikan barcode) dihitung di backend; SUNMI hanya mengirim pilihan petugas.
class ReceivingRepository {
  ReceivingRepository._();
  static final ReceivingRepository instance = ReceivingRepository._();

  final _api = ApiClient.instance;

  List<Map<String, dynamic>> _list(Object? data) => ((data as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<List<OptionItem>> suppliers() async => _list(await _api.get('/suppliers', query: {'active': 'true'}))
      .map((s) => OptionItem(s['id'] as String, s['name'] as String))
      .toList();

  Future<List<OptionItem>> categories() async =>
      _list(await _api.get('/categories')).map((c) => OptionItem(c['id'] as String, c['name'] as String)).toList();

  /// id = kode satuan (PCS, BOX, KG).
  Future<List<OptionItem>> units() async => _list(await _api.get('/units', query: {'active': 'true'}))
      .map((u) => OptionItem(u['code'] as String, '${u['code']} · ${u['name']}'))
      .toList();

  Future<ProductWithPackages> product(String id) async {
    final j = await _api.get('/products/$id') as Map<String, dynamic>;
    return ProductWithPackages(
      ProductBrief.fromJson(j),
      _list(j['packages']).map(PackageInfo.fromJson).toList(),
    );
  }

  // ---------------------------------------------------------------- temporary receiving
  Future<TemporaryReceiving> createTemporary({
    required String warehouseId,
    required String unit,
    required int quantity,
    String? categoryId,
    String? supplierId,
    String? supplierBarcode,
    required String idempotencyKey,
  }) async =>
      TemporaryReceiving.fromJson(await _api.post('/temporary-receivings', {
        'warehouseId': warehouseId,
        'unit': unit,
        'quantity': quantity,
        'categoryId': categoryId,
        'supplierId': supplierId,
        'supplierBarcode': supplierBarcode,
      }, idempotencyKey) as Map<String, dynamic>);

  Future<TemporaryReceiving> uploadPhoto(String id, List<int> bytes, {String mimeType = 'image/jpeg'}) async =>
      TemporaryReceiving.fromJson(await _api.post('/temporary-receivings/$id/photo', {
        'imageBase64': base64Encode(bytes),
        'mimeType': mimeType,
      }) as Map<String, dynamic>);

  Future<List<TemporaryReceiving>> temporaries({String? warehouseId, bool readyOnly = false}) async =>
      _list(await _api.get('/temporary-receivings', query: {
        'warehouseId': warehouseId,
        if (readyOnly) 'readyToReceive': 'true',
      })).map(TemporaryReceiving.fromJson).toList();

  Future<TemporaryReceiving> temporary(String idOrBarcode) async =>
      TemporaryReceiving.fromJson(await _api.get('/temporary-receivings/${Uri.encodeComponent(idOrBarcode)}') as Map<String, dynamic>);

  // ---------------------------------------------------------------- label
  /// type: PRODUCT | BATCH | TEMPORARY | PACKAGE | LOCATION. Tidak pernah membuat ID baru.
  Future<LabelData> label(String type, String code) async =>
      LabelData.fromJson(await _api.get('/labels', query: {'type': type, 'code': code}) as Map<String, dynamic>);

  /// Riwayat cetak (gagal dicatat pun tidak memengaruhi transaksi).
  Future<void> logPrint({required LabelData label, required int copies, required bool success, String? printer, String? message}) async {
    try {
      await _api.post('/labels/print-log', {
        'labelType': label.type,
        'code': label.code,
        'copies': copies,
        'source': 'SUNMI',
        'printer': printer,
        'status': success ? 'SUCCESS' : 'FAILED',
        'message': message,
      });
    } catch (_) {
      // Log cetak bersifat tambahan; jangan ganggu petugas bila gagal.
    }
  }
}
