import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/data/models/inventory_models.dart';
import 'package:warehouse_management_system/services/printing/escpos_label.dart';

/// Indeks awal [needle] di [hay], -1 jika tidak ada.
int indexOf(List<int> hay, List<int> needle) {
  for (var i = 0; i <= hay.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

void main() {
  const batch = LabelData(type: 'BATCH', code: 'B261116-0001', symbology: 'CODE128', title: 'Kursi Kantor', lines: ['CHAIR-001 · 20 PCS']);
  const product = LabelData(type: 'PRODUCT', code: '2000000000015', symbology: 'EAN13', title: 'Adaptor 20W');
  const temp = LabelData(type: 'TEMPORARY', code: 'TMP261116-0001', symbology: 'CODE128', title: 'PENDING REGISTRATION');

  test('Code128 batch: set B untuk huruf, set C (2 digit/byte) untuk deret angka, diawali init ESC @', () {
    final bytes = EscPosLabel().build([batch]);
    expect(bytes.take(2), [0x1B, 0x40]);
    // B261116-0001 -> {B 'B' {C 26 11 16 {B '-' {C 00 01
    final data = [...'{BB{C'.codeUnits, 26, 11, 16, ...'{B-{C'.codeUnits, 0, 1];
    expect(EscPosLabel.code128Payload(batch.code).bytes, data);
    expect(EscPosLabel.code128Payload(batch.code).symbols, 10);
    final at = indexOf(bytes, [0x1D, 0x6B, 73, data.length, ...data]);
    expect(at, greaterThan(0));
    // deret angka ganjil: digit pertama di set B; '{' di-escape
    expect(EscPosLabel.code128Payload('A12345').bytes, [...'{BA1{C'.codeUnits, 23, 45]);
    expect(EscPosLabel.code128Payload('a{b').bytes, '{Ba{{b'.codeUnits);
    // karakter non-ASCII (·) diganti agar printer tidak mencetak sampah
    expect(indexOf(bytes, 'CHAIR-001 - 20 PCS'.codeUnits), greaterThan(0));
  });

  test('EAN-13 barcode internal dikirim 12 digit (check digit dihitung printer)', () {
    final bytes = EscPosLabel().build([product]);
    expect(indexOf(bytes, [0x1D, 0x6B, 67, 12, ...'200000000001'.codeUnits]), greaterThan(0));
  });

  test('Lebar modul menyesuaikan kertas; terlalu panjang -> QR, tidak terpotong', () {
    final b58 = EscPosLabel();
    expect(b58.moduleWidthFor(product), 3);
    expect(b58.moduleWidthFor(temp), 2, reason: 'TMP261116-0001 muat di 58 mm dengan modul 2');
    const long = LabelData(type: 'PACKAGE', code: 'PKG-SUPPLIER-0001-KARTON', symbology: 'CODE128', title: 'X');
    expect(b58.moduleWidthFor(long), isNull);
    final bytes = b58.build([long]);
    expect(indexOf(bytes, [0x1D, 0x28, 0x6B]), greaterThan(0), reason: 'QR dipakai');
    expect(indexOf(bytes, [0x1D, 0x6B, 73]), -1, reason: 'Code128 tidak dipakai bila tidak muat');
    const medium = LabelData(type: 'PACKAGE', code: 'PKG-SUPPLIER-KRT', symbology: 'CODE128', title: 'X');
    expect(b58.moduleWidthFor(medium), isNull, reason: '16 huruf tidak muat 58 mm');
    expect(EscPosLabel(dotsWidth: 576).moduleWidthFor(medium), 2, reason: 'muat di 80 mm');
  });

  test('Salinan & feed: 3 salinan = 3 barcode, feed sesuai pengaturan', () {
    final bytes = EscPosLabel(feedLines: 5).build([batch], copies: 3);
    var count = 0;
    for (var i = 0; i < bytes.length - 2; i++) {
      if (bytes[i] == 0x1D && bytes[i + 1] == 0x6B && bytes[i + 2] == 73) count++;
    }
    expect(count, 3);
    expect(indexOf(bytes, [0x1B, 0x64, 5]), greaterThan(0));
  });

  test('Judul panjang dipotong ke lebar baris', () {
    const l = LabelData(type: 'PRODUCT', code: 'X1', symbology: 'CODE128', title: 'Nama produk yang sangat panjang sekali melebihi lebar');
    final bytes = EscPosLabel().build([l]);
    expect(indexOf(bytes, 'Nama produk yang sangat panjang~'.codeUnits), greaterThan(0));
  });

  test('ScanResult kemasan & temporary', () {
    final pkg = ScanResult.fromJson({
      'type': 'PRODUCT', 'code': 'PKG-1',
      'product': {'id': '3', 'sku': 'PRT-001', 'barcode': '200', 'name': 'Obeng Set', 'unit': 'SET'},
      'package': {'id': 'k1', 'unitCode': 'BOX', 'conversionFactor': 10, 'barcode': 'PKG-1'},
      'packages': [{'id': 'k1', 'unitCode': 'BOX', 'conversionFactor': 10, 'barcode': 'PKG-1'}],
    });
    expect(pkg.package!.conversionFactor, 10);
    expect(pkg.packages.single.unitCode, 'BOX');
    final t = ScanResult.fromJson({
      'type': 'TEMPORARY', 'code': 'TMP261116-0001',
      'temporary': {
        'id': 't1', 'number': 'TMP261116-0001', 'tempBarcode': 'TMP261116-0001', 'warehouseId': 'WH-001', 'warehouseName': 'Gudang Utama',
        'unit': 'BOX', 'quantity': 2, 'status': 'MATCHED_EXISTING_PRODUCT', 'readyToReceive': true, 'productId': '3', 'baseQuantity': 20,
      },
    });
    expect(t.type, ScanType.temporary);
    expect(t.temporary!.readyToReceive, isTrue);
    expect(t.temporary!.baseQuantity, 20);
    expect(t.temporary!.statusLabel, 'Cocok produk lama');
  });
}
