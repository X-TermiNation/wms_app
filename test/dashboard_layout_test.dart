import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:warehouse_management_system/modules/dashboard/controllers/dashboard_controller.dart';
import 'package:warehouse_management_system/modules/dashboard/views/dashboard_view.dart';
import 'package:warehouse_management_system/services/auth/warehouse_context.dart';

/// Controller tanpa jaringan: data ringkasan diisi langsung.
class _FakeDashboardController extends DashboardController {
  _FakeDashboardController(this.name);
  final String name;

  @override
  String get userName => name;

  @override
  Future<void> refreshAll() async {}
}

const _sizes = <String, Size>{
  'HP kecil 320x568': Size(320, 568),
  'SUNMI L2KS 360x720': Size(360, 720),
  'HP besar 412x915': Size(412, 915),
  'Tablet 800x1280': Size(800, 1280),
  'Landscape 1280x720': Size(1280, 720),
};

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
    final ctx = WarehouseContext.instance;
    ctx.warehouses.assignAll(const [
      AccessibleWarehouse(id: 'WH-001', code: 'WH-SBY-001', name: 'Gudang Utama Surabaya Rungkut Industri', isActive: true),
      AccessibleWarehouse(id: 'WH-002', code: 'WH-SBY-002', name: 'Gudang Surabaya', isActive: true),
    ]);
    ctx.activeId.value = 'WH-001';
    ctx.role.value = 'supervisor';
  });

  Future<void> pumpDashboard(WidgetTester tester, Size size, double textScale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = Get.put<DashboardController>(_FakeDashboardController('Petugas Gudang Utama Dengan Nama Sangat Panjang'));
    c.summary.value = const OperationalSummary({
      'available': {'batches': 120, 'quantity': 1234567},
      'qcPending': {'batches': 12, 'quantity': 45000},
      'qcHold': {'batches': 3, 'quantity': 300},
      'qcPassedAwaitingRelease': {'batches': 4, 'quantity': 410},
      'qcRejected': {'batches': 2, 'quantity': 20},
      'inTransitInbound': {'batches': 5, 'quantity': 98765},
      'putawayPending': {'batches': 150, 'quantity': 900},
      'expiringIn30Days': {'batches': 27, 'quantity': 600},
      'openDocuments': {'receivings': 1200, 'issuings': 8, 'transfersInbound': 3, 'stockOpnames': 2},
    });
    await tester.pumpWidget(GetMaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: const DashboardView(),
      ),
    ));
    await tester.pump();
  }

  for (final entry in _sizes.entries) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('tanpa overflow: ${entry.key}, font ${(scale * 100).round()}%', (tester) async {
        await pumpDashboard(tester, entry.value, scale);
        expect(tester.takeException(), isNull);
        // seluruh 13 menu dapat digulir dan dirender tanpa overflow
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('menu sejajar: ikon di setiap baris berada pada tinggi yang sama', (tester) async {
    await pumpDashboard(tester, const Size(360, 720), 1.0);
    final receiving = tester.getTopLeft(find.byIcon(Icons.move_to_inbox_outlined)).dy;
    final putaway = tester.getTopLeft(find.byIcon(Icons.move_down_rounded)).dy;
    final qcTransfer = tester.getTopLeft(find.byIcon(Icons.science_outlined)).dy;
    expect(putaway, receiving);
    expect(qcTransfer, receiving);
  });
}
