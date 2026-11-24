import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/common/widgets/erp_document_picker.dart';
import 'package:warehouse_management_system/data/models/erp_document_models.dart';

/// JSON mengikuti erp-document.service.js (mapDocument / mapLine).
final _json = {
  'id': 'd1', 'kind': 'inbound', 'number': 'IBD-2026-001', 'source': 'ERP', 'erpDocumentNo': 'PO-2026-0001-PANJANG-SEKALI',
  'docType': 'PURCHASE_ORDER', 'warehouseId': 'WH-001', 'partyName': 'PT Sumber Makmur Sentosa Abadi Jaya Perkasa',
  'documentDate': '2026-11-23', 'expectedDate': '2026-11-25', 'status': 'IN_PROGRESS', 'totalOrdered': 130, 'totalProcessed': 60,
  'percentage': 46.2,
  'lines': [
    {'lineNo': 10, 'productId': '5', 'productName': 'Kardus Sedang Ukuran Besar Sekali Untuk Pengiriman', 'sku': 'KMS-001', 'unit': 'PCS',
      'orderedQuantity': 100, 'processedQuantity': 60, 'pendingQuantity': 15, 'remainingQuantity': 40},
    {'lineNo': 20, 'productId': '5', 'productName': 'Kardus Sedang', 'sku': 'KMS-001', 'unit': 'PCS',
      'orderedQuantity': 10, 'processedQuantity': 0, 'pendingQuantity': 0, 'remainingQuantity': 10},
    {'lineNo': 30, 'productId': '3', 'productName': 'Obeng Set', 'sku': 'PRT-001', 'unit': 'SET',
      'orderedQuantity': 20, 'processedQuantity': 0, 'pendingQuantity': 0, 'remainingQuantity': 20},
  ],
};

void main() {
  test('sisa per produk memperhitungkan transaksi pending & produk di banyak baris', () {
    final d = ErpDocument.fromJson(_json);
    expect(d.kind, ErpDocKind.inbound);
    expect(d.isOpen, isTrue);
    expect(d.displayNumber, 'PO-2026-0001-PANJANG-SEKALI');
    expect(d.contains('5'), isTrue);
    expect(d.contains('1'), isFalse);
    expect(d.remainingFor('5'), 50);
    expect(d.availableFor('5'), 35, reason: '40 - 15 pending + 10 baris kedua');
    expect(d.availableFor('3'), 20);
    final manual = ErpDocument.fromJson({..._json, 'erpDocumentNo': null, 'source': 'MANUAL', 'status': 'COMPLETED'});
    expect(manual.displayNumber, 'IBD-2026-001');
    expect(manual.isOpen, isFalse);
  });

  for (final size in const [Size(320, 568), Size(360, 720)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('kartu & progres dokumen tanpa overflow ${size.width.toInt()}dp font ${(scale * 100).round()}%', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final d = ErpDocument.fromJson(_json);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: ListView(padding: const EdgeInsets.all(16), children: [
                ErpDocumentCard(document: d),
                ErpDocumentProgress(document: d, countedFor: (id) => id == '5' ? 40 : 0),
              ]),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('40 / 35 PCS'), findsNWidgets(2), reason: 'Qty melebihi sisa tampil per baris produk');
      });
    }
  }
}
