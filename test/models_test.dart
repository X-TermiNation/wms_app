import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/data/models/inventory_models.dart';
import 'package:warehouse_management_system/modules/issuing/models/issuing_model.dart';
import 'package:warehouse_management_system/modules/receiving/models/receiving_model.dart';
import 'package:warehouse_management_system/modules/stock_opname/models/stock_opname_model.dart';
import 'package:warehouse_management_system/modules/transfers/models/transfer_model.dart';

/// Bentuk JSON mengikuti respons backend (serializers.js & routes).
void main() {
  final balance = {
    'id': 1, 'lotId': 'L1', 'batchNumber': 'B261113-0001', 'supplierLot': 'SUP-1', 'expiryDate': '2027-06-30',
    'isExpired': false, 'productId': '2', 'productName': 'Adaptor 20W', 'sku': 'ELK-002', 'unit': 'PCS',
    'warehouseId': 'WH-001', 'warehouseName': 'Gudang Utama', 'locationId': 'LOC-QC', 'locationCode': 'QC-HOLD',
    'locationBarcode': 'WH-SBY-001-QC-HOLD', 'locationType': 'QC_HOLD', 'status': 'QC_PENDING', 'quantity': 100,
  };

  test('ScanResult batch + saldo', () {
    final r = ScanResult.fromJson({
      'type': 'BATCH',
      'code': 'B261113-0001',
      'product': {'id': '2', 'sku': 'ELK-002', 'barcode': '899', 'name': 'Adaptor 20W', 'unit': 'PCS', 'requiresQc': true, 'hasExpiry': true},
      'batch': {'id': 'L1', 'batchNumber': 'B261113-0001', 'productId': '2', 'productName': 'Adaptor 20W', 'sku': 'ELK-002', 'unit': 'PCS',
        'expiryDate': '2027-06-30', 'isExpired': false, 'receivedQuantity': 100, 'currentQuantity': 100},
      'balances': [balance],
    });
    expect(r.type, ScanType.batch);
    expect(r.product!.requiresQc, isTrue);
    expect(r.balances.single.status, InventoryStatus.qcPending);
    expect(r.balances.single.quantity, 100);
  });

  test('ScanResult produk + GS1 + stok eligible', () {
    final r = ScanResult.fromJson({
      'type': 'PRODUCT',
      'code': '(01)08991001000011(17)270630(10)LOT1',
      'product': {'id': '1', 'sku': 'ELK-001', 'barcode': '8991001000011', 'name': 'Kabel', 'unit': 'PCS'},
      'gs1': {'gtin': '08991001000011', 'lot': 'LOT1', 'expiryDate': '2027-06-30', 'serial': null},
      'stock': {'eligible': 125, 'available': 125, 'total': 125, 'byStatus': {}},
    });
    expect(r.gs1!.lot, 'LOT1');
    expect(r.gs1!.expiryDate, DateTime(2027, 6, 30));
    expect(r.availableQuantity, 125);
  });

  test('Receiving item membawa lot supplier & batch; toJson berisi expiry', () {
    final r = ReceivingModel.fromJson({
      'id': 'R1', 'number': 'RCV-2026-004', 'date': '2026-11-13', 'supplier': 'PT A', 'warehouseId': 'WH-001',
      'warehouseName': 'Gudang Utama', 'status': 'completed', 'notes': '',
      'items': [{'productId': '2', 'productName': 'Adaptor', 'sku': 'ELK-002', 'unit': 'PCS', 'quantity': 100,
        'supplierLot': 'SUP-1', 'expiryDate': '2027-06-30', 'requiresQc': true, 'lotId': 'L1', 'batchNumber': 'B261113-0001'}],
    });
    expect(r.items.single.batchNumber, 'B261113-0001');
    expect(r.items.single.toJson()['expiryDate'], '2027-06-30');
    final a = r.items.single;
    expect(a.sameLine(a.copyWith(quantity: 5)), isTrue);
  });

  test('Issuing alokasi FEFO & transfer status in_transit', () {
    final i = IssuingModel.fromJson({
      'id': 'I1', 'number': 'ISS-2026-004', 'date': '2026-11-13', 'destination': 'Produksi', 'warehouseId': 'WH-001',
      'warehouseName': 'Gudang Utama', 'status': 'completed', 'notes': '',
      'items': [{'productId': '4', 'productName': 'Baut', 'sku': 'BBK-001', 'unit': 'BOX', 'quantity': 15}],
      'allocations': [{'productId': '4', 'lotId': 'L9', 'batchNumber': 'B1', 'expiryDate': '2026-11-30', 'locationCode': 'A-01-02', 'quantity': 10}],
    });
    expect(i.allocations.single.quantity, 10);
    expect(TransferStatus.fromApi('in_transit'), TransferStatus.inTransit);
    final t = TransferModel.fromJson({
      'id': 'T1', 'number': 'TRF-2026-003', 'date': '2026-11-13', 'sourceWarehouseId': 'WH-001', 'sourceWarehouseName': 'A',
      'destinationWarehouseId': 'WH-002', 'destinationWarehouseName': 'B', 'status': 'in_transit', 'notes': '', 'items': [],
      'lots': [{'productId': '3', 'productName': 'Obeng', 'unit': 'SET', 'lotId': 'L2', 'batchNumber': 'B2', 'expiryDate': null, 'quantity': 30, 'receivedQuantity': 20}],
    });
    expect(t.remainingQuantity, 10);
  });

  test('Stock opname item per lokasi x batch x status', () {
    final o = StockOpnameModel.fromJson({
      'id': 'O1', 'number': 'OPN-2026-001', 'date': '2026-11-13', 'warehouseId': 'WH-001', 'warehouseName': 'Gudang Utama',
      'locationCode': 'A-01-02', 'status': 'draft', 'notes': '',
      'items': [{'productId': '3', 'productName': 'Obeng', 'sku': 'PRT-001', 'unit': 'SET', 'systemStock': 70, 'physicalStock': 68,
        'lotId': 'L2', 'batchNumber': 'B2', 'locationId': 'LOC-002', 'locationCode': 'A-01-02', 'inventoryStatus': 'AVAILABLE'}],
    });
    expect(o.items.single.difference, -2);
    expect(o.items.single.toJson(), {'lotId': 'L2', 'locationId': 'LOC-002', 'status': 'AVAILABLE', 'physicalStock': 68});
  });
}
