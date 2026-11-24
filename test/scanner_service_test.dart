import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warehouse_management_system/services/scanner/scanner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('com.mywms/scanner/events');
  late MockStreamHandlerEventSink sink;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (args, events) => sink = events),
    );
  });

  Future<void> emit(String barcode) async {
    sink.success({'barcode': barcode, 'rawBytes': null});
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  test('hanya handler paling atas (halaman/dialog aktif) yang menerima scan', () async {
    final page = <String>[];
    final dialog = <String>[];
    final pageReg = ScannerService.instance.register(page.add, label: 'page');
    final dialogReg = ScannerService.instance.register(dialog.add, label: 'dialog');

    await emit('BATCH-1');
    expect(dialog, ['BATCH-1']);
    expect(page, isEmpty);

    await dialogReg.cancel(); // dialog ditutup -> halaman aktif lagi
    await Future<void>.delayed(ScannerService.duplicateWindow);
    await emit('BATCH-2');
    expect(page, ['BATCH-2']);
    await pageReg.cancel();
  });

  test('scan ganda dalam jendela 500 ms diabaikan, barcode kosong diabaikan', () async {
    final got = <String>[];
    final reg = ScannerService.instance.register(got.add);
    await emit('X-1');
    await emit('X-1'); // pantulan broadcast ganda
    await emit('   ');
    expect(got, ['X-1']);
    await Future<void>.delayed(ScannerService.duplicateWindow);
    await emit('X-1'); // scan ulang disengaja setelah jeda
    expect(got, ['X-1', 'X-1']);
    await reg.cancel();
  });

  test('input manual selalu diproses (tidak terkena anti duplikat)', () async {
    final got = <String>[];
    final reg = ScannerService.instance.register(got.add);
    ScannerService.instance.simulate('MANUAL-1');
    ScannerService.instance.simulate('MANUAL-1');
    expect(got, ['MANUAL-1', 'MANUAL-1']);
    await reg.cancel();
  });
}
