/// Dokumen inbound (PO dari ERP) & outbound (SO dari ERP) untuk Tally receiving / picking issuing.
/// Qty sisa & validasi akhir dihitung backend; SUNMI memakai angka ini untuk panduan petugas.
enum ErpDocKind { inbound, outbound }

extension ErpDocKindX on ErpDocKind {
  String get path => this == ErpDocKind.inbound ? '/inbound-documents' : '/outbound-documents';
  String get erpLabel => this == ErpDocKind.inbound ? 'PO' : 'SO';
  String get partyLabel => this == ErpDocKind.inbound ? 'Supplier' : 'Customer';
  String get processedLabel => this == ErpDocKind.inbound ? 'diterima' : 'dikeluarkan';
}

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _f(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
DateTime? _d(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

class ErpDocLine {
  const ErpDocLine({
    required this.lineNo,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.orderedQuantity,
    required this.processedQuantity,
    required this.pendingQuantity,
    required this.remainingQuantity,
  });

  factory ErpDocLine.fromJson(Map<String, dynamic> j) => ErpDocLine(
        lineNo: _i(j['lineNo']),
        productId: '${j['productId']}',
        productName: '${j['productName']}',
        sku: '${j['sku']}',
        unit: '${j['unit']}',
        orderedQuantity: _i(j['orderedQuantity']),
        processedQuantity: _i(j['processedQuantity']),
        pendingQuantity: _i(j['pendingQuantity']),
        remainingQuantity: _i(j['remainingQuantity']),
      );

  final int lineNo;
  final String productId, productName, sku, unit;
  final int orderedQuantity, processedQuantity, pendingQuantity, remainingQuantity;

  /// Sisa yang masih bisa diproses (dikurangi transaksi lain yang belum dikonfirmasi).
  int get available => (remainingQuantity - pendingQuantity).clamp(0, remainingQuantity);
}

class ErpDocument {
  const ErpDocument({
    required this.id,
    required this.kind,
    required this.number,
    required this.source,
    required this.docType,
    required this.warehouseId,
    required this.partyName,
    required this.status,
    required this.totalOrdered,
    required this.totalProcessed,
    required this.percentage,
    required this.lines,
    this.erpDocumentNo,
    this.documentDate,
    this.expectedDate,
    this.remarks = '',
  });

  factory ErpDocument.fromJson(Map<String, dynamic> j) => ErpDocument(
        id: '${j['id']}',
        kind: j['kind'] == 'outbound' ? ErpDocKind.outbound : ErpDocKind.inbound,
        number: '${j['number']}',
        source: '${j['source']}',
        erpDocumentNo: j['erpDocumentNo'] as String?,
        docType: '${j['docType']}',
        warehouseId: '${j['warehouseId']}',
        partyName: (j['partyName'] as String?) ?? '',
        documentDate: _d(j['documentDate']),
        expectedDate: _d(j['expectedDate']),
        status: '${j['status']}',
        remarks: (j['remarks'] as String?) ?? '',
        totalOrdered: _i(j['totalOrdered']),
        totalProcessed: _i(j['totalProcessed']),
        percentage: _f(j['percentage']),
        lines: ((j['lines'] as List?) ?? const []).map((e) => ErpDocLine.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final String id, number, source, docType, warehouseId, partyName, status, remarks;
  final ErpDocKind kind;
  final String? erpDocumentNo;
  final DateTime? documentDate, expectedDate;
  final int totalOrdered, totalProcessed;
  final double percentage;
  final List<ErpDocLine> lines;

  bool get isOpen => status == 'OPEN' || status == 'IN_PROGRESS';

  /// Nomor yang dikenal petugas: nomor PO/SO ERP, atau nomor WMS untuk dokumen manual.
  String get displayNumber => erpDocumentNo ?? number;

  /// Total sisa per produk (produk bisa muncul di beberapa baris).
  int availableFor(String productId) => lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.available);
  int remainingFor(String productId) => lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.remainingQuantity);
  bool contains(String productId) => lines.any((l) => l.productId == productId);

  String get statusLabel => switch (status) {
        'OPEN' => 'Open',
        'IN_PROGRESS' => 'In Progress',
        'COMPLETED' => 'Completed',
        'CLOSED' => 'Closed',
        _ => 'Cancelled',
      };
}
