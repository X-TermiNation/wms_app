import '../../services/api/api_client.dart';
import '../models/erp_document_models.dart';

/// Dokumen PO / SO dari ERP. SUNMI hanya membaca; dokumen dibuat ERP (atau admin di Desktop).
class ErpDocumentRepository {
  ErpDocumentRepository._();
  static final ErpDocumentRepository instance = ErpDocumentRepository._();

  final _api = ApiClient.instance;

  /// Dokumen yang belum selesai (OPEN / IN_PROGRESS) di gudang aktif.
  Future<List<ErpDocument>> openDocuments(ErpDocKind kind, {required String warehouseId, String? search}) =>
      _api.getList(kind.path, ErpDocument.fromJson, query: {'warehouseId': warehouseId, 'status': 'open', 'search': search});

  /// Cari dari hasil scan: nomor PO/SO ERP, nomor WMS (IBD-/OBD-), atau id.
  Future<ErpDocument> find(ErpDocKind kind, String code) async =>
      ErpDocument.fromJson(await _api.get('${kind.path}/${Uri.encodeComponent(code)}') as Map<String, dynamic>);
}
