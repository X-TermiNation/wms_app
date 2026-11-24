import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_management_system/data/models/shipping_models.dart';
import 'package:warehouse_management_system/modules/shipping/views/packing_pages.dart';
import 'package:warehouse_management_system/modules/shipping/views/shipment_pages.dart';
import 'package:warehouse_management_system/services/api/api_client.dart';
import 'package:warehouse_management_system/services/auth/warehouse_context.dart';
import 'package:warehouse_management_system/services/scanner/scanner_service.dart';
import 'package:warehouse_management_system/services/storage/session_storage.dart';

/// JSON mengikuti shipping.service.js (fetchPackings / fetchShipments, detail = true).
Map<String, dynamic> _packing({int packed = 18, bool withSecondCarton = false}) => {
      'id': 'p1', 'number': 'PCK-2026-001', 'status': 'OPEN', 'warehouseId': 'WH-001', 'issuingId': 'i1', 'issuingNumber': 'ISS-2026-010',
      'destination': 'PT Sentosa Retail Nusantara Cabang Surabaya Timur', 'outboundDocumentNumber': 'OBD-2026-004', 'erpDocumentNo': 'SO-2026-0004',
      'totalPicked': 30, 'totalPacked': packed, 'totalRemaining': 30 - packed, 'totalCartons': withSecondCarton ? 2 : 1, 'loadedCartons': 0,
      'totalWeightKg': 9.5,
      'lines': [
        {'productId': '5', 'sku': 'KMS-001', 'productName': 'Kardus Sedang Ukuran Besar Untuk Pengiriman Antar Kota', 'unit': 'PCS',
          'lotId': 'l1', 'batchNumber': 'B261118-0001', 'expiryDate': '2027-11-18', 'pickedQuantity': 30, 'packedQuantity': packed,
          'remainingQuantity': 30 - packed},
      ],
      'cartons': [
        {'id': 'c1', 'seq': 1, 'code': 'CTN-2026-001', 'status': withSecondCarton ? 'CLOSED' : 'OPEN', 'weightKg': 9.5, 'loadedAt': null,
          'totalQuantity': packed, 'items': [
            {'id': 1, 'productId': '5', 'sku': 'KMS-001', 'productName': 'Kardus Sedang', 'unit': 'PCS', 'batchNumber': 'B261118-0001', 'quantity': packed},
          ]},
        if (withSecondCarton)
          {'id': 'c2', 'seq': 2, 'code': 'CTN-2026-002', 'status': 'OPEN', 'weightKg': null, 'loadedAt': null, 'totalQuantity': 0, 'items': []},
      ],
    };

Map<String, dynamic> _shipment({int loaded = 1}) => {
      'id': 's1', 'number': 'SHP-2026-001', 'status': 'LOADING', 'warehouseId': 'WH-001', 'plannedDate': '2026-11-24', 'carrier': 'Armada Sendiri',
      'vehicleType': 'CDD Box', 'vehiclePlate': 'L 1234 AB', 'driverName': 'Pak Slamet', 'driverPhone': '0812000111', 'dock': 'D2',
      'totalPackings': 1, 'totalCartons': 2, 'loadedCartons': loaded, 'totalQuantity': 30, 'totalWeightKg': 15.5,
      'destinations': ['PT Sentosa Retail Nusantara'], 'documents': ['SO-2026-0004'],
      'packings': [
        {..._packing(packed: 30), 'status': 'PACKED', 'totalCartons': 2, 'loadedCartons': loaded, 'cartons': [
          {'id': 'c1', 'seq': 1, 'code': 'CTN-2026-001', 'status': 'CLOSED', 'loadedAt': '2026-11-24T03:00:00Z', 'totalQuantity': 18},
          {'id': 'c2', 'seq': 2, 'code': 'CTN-2026-002', 'status': 'CLOSED', 'loadedAt': loaded > 1 ? '2026-11-24T03:01:00Z' : null, 'totalQuantity': 12},
        ]},
      ],
    };

void main() {
  final calls = <String>[];
  late http.Response Function(http.Request req) handler;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('com.mywms/scanner/events'), MockStreamHandler.inline(onListen: (_, _) {}));
    SharedPreferences.setMockInitialValues({'auth_token': 't', 'api_base_url': 'http://wms/api'});
    await SessionStorage.instance.init();
    // ApiClient singleton dibuat di zona MockClient -> semua request test lewat [handler].
    http.runWithClient(() => ApiClient.instance, () => MockClient((req) async {
          calls.add('${req.method} ${req.url.path}');
          return handler(req);
        }));
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    calls.clear();
    WarehouseContext.instance.activeId.value = 'WH-001';
  });

  http.Response json(Object data) => http.Response(jsonEncode({'success': true, 'message': 'OK', 'data': data}), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  test('model packing & shipment', () {
    final p = Packing.fromJson(_packing());
    expect(p.reference, 'SO-2026-0004');
    expect(p.currentCarton!.code, 'CTN-2026-001');
    expect(p.complete, isFalse);
    expect(Packing.fromJson(_packing(packed: 30)).complete, isTrue);
    final s = Shipment.fromJson(_shipment());
    expect(s.editable, isTrue);
    expect(s.allLoaded, isFalse);
    expect(Shipment.fromJson(_shipment(loaded: 2)).allLoaded, isTrue);
    expect(s.vehicleLabel, 'L 1234 AB · CDD Box');
    expect(shippingStageLabel('PACKED'), 'Siap dimuat');
  });

  Future<void> pump(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: page));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  for (final size in const [Size(320, 568), Size(360, 720)]) {
    testWidgets('packing: render tanpa overflow & scan masuk koli (${size.width.toInt()}dp)', (tester) async {
      var packed = 18;
      handler = (req) {
        if (req.method == 'POST' && req.url.path.endsWith('/scan')) {
          packed += (jsonDecode(req.body) as Map)['quantity'] as int;
          return json({..._packing(packed: packed), 'lastScan': {'productName': 'Kardus Sedang', 'unit': 'PCS', 'quantity': 1, 'cartonCode': 'CTN-2026-001'}});
        }
        return json(_packing(packed: packed));
      };
      await pump(tester, const PackingPage(packingId: 'p1'), size);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('CTN-2026-001'), findsWidgets);
      expect(find.textContaining('Sisa 12 unit'), findsOneWidget, reason: 'Tombol selesai nonaktif selama masih ada sisa');

      ScannerService.instance.simulate('KMS-001');
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(calls, contains('POST /api/packings/p1/scan'));
      expect(find.textContaining('+1 PCS Kardus Sedang'), findsOneWidget);
      expect(find.textContaining('Sisa 11 unit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading: progres koli & dispatch aktif bila semua dimuat (${size.width.toInt()}dp)', (tester) async {
      var loaded = 1;
      handler = (req) {
        if (req.url.path.endsWith('/scan')) {
          loaded = 2;
          return json({..._shipment(loaded: 2), 'lastScan': {'cartonCode': 'CTN-2026-002', 'packingNumber': 'PCK-2026-001'}});
        }
        return json(_shipment(loaded: loaded));
      };
      await pump(tester, const LoadingPage(shipmentId: 's1'), size);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Muat 1 koli lagi'), findsOneWidget);
      ScannerService.instance.simulate('CTN-2026-002');
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.textContaining('Dispatch • 2 koli'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
