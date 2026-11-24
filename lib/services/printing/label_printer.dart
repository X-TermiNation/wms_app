import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/inventory_models.dart';
import '../../data/repositories/receiving_repository.dart';
import 'escpos_label.dart';

class PrintResult {
  const PrintResult(this.success, this.message);
  final bool success;
  final String message;
}

class PrinterDevice {
  const PrinterDevice(this.name, this.mac);
  final String name;
  final String mac;
}

/// Abstraksi printer label. Implementasi saat ini: printer thermal Bluetooth ESC/POS.
/// Kegagalan cetak tidak pernah membatalkan transaksi; label dapat dicetak ulang dengan identitas yang sama.
class LabelPrinter {
  LabelPrinter._();
  static final LabelPrinter instance = LabelPrinter._();

  static const _kMac = 'printer.mac', _kName = 'printer.name', _kFeed = 'printer.feed', _kDots = 'printer.dots';

  String? mac;
  String? name;
  int feedLines = 3;
  /// 384 = kertas/label 58 mm, 576 = 80 mm.
  int dotsWidth = 384;
  bool _loaded = false;

  bool get isConfigured => mac != null && mac!.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    mac = p.getString(_kMac);
    name = p.getString(_kName);
    feedLines = p.getInt(_kFeed) ?? 3;
    dotsWidth = p.getInt(_kDots) ?? 384;
    _loaded = true;
  }

  Future<void> save({required String mac, required String name, int? feedLines, int? dotsWidth}) async {
    final p = await SharedPreferences.getInstance();
    this.mac = mac;
    this.name = name;
    if (feedLines != null) this.feedLines = feedLines;
    if (dotsWidth != null) this.dotsWidth = dotsWidth;
    await p.setString(_kMac, mac);
    await p.setString(_kName, name);
    await p.setInt(_kFeed, this.feedLines);
    await p.setInt(_kDots, this.dotsWidth);
  }

  EscPosLabel get builder => EscPosLabel(
        dotsWidth: dotsWidth,
        charsPerLine: dotsWidth >= 576 ? 48 : 32,
        feedLines: feedLines,
      );

  /// Printer Bluetooth yang sudah di-pair di pengaturan Android.
  Future<List<PrinterDevice>> pairedDevices() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrintResult(false, 'Izin Bluetooth belum diberikan.');
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrintResult(false, 'Bluetooth belum aktif. Nyalakan Bluetooth perangkat.');
    }
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => PrinterDevice(d.name, d.macAdress)).toList();
  }

  Future<PrintResult> _ensureConnected() async {
    await load();
    if (!isConfigured) return const PrintResult(false, 'Printer belum dipilih. Buka Pengaturan Printer.');
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      return const PrintResult(false, 'Izin Bluetooth belum diberikan.');
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      return const PrintResult(false, 'Bluetooth belum aktif.');
    }
    if (await PrintBluetoothThermal.connectionStatus) return const PrintResult(true, '');
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac!);
    return ok ? const PrintResult(true, '') : PrintResult(false, 'Tidak dapat terhubung ke printer ${name ?? mac}. Pastikan printer menyala.');
  }

  /// Cetak [labels] masing-masing [copies] salinan, lalu catat ke riwayat cetak backend.
  Future<PrintResult> print(List<LabelData> labels, {int copies = 1}) async {
    PrintResult result;
    try {
      final conn = await _ensureConnected();
      if (!conn.success) {
        result = conn;
      } else {
        final ok = await PrintBluetoothThermal.writeBytes(builder.build(labels, copies: copies));
        result = ok
            ? PrintResult(true, '${labels.length * copies} label terkirim ke ${name ?? 'printer'}.')
            : const PrintResult(false, 'Printer menolak data. Periksa kertas/label dan coba lagi.');
      }
    } catch (e) {
      result = PrintResult(false, 'Gagal mencetak: $e');
    }
    for (final l in labels) {
      ReceivingRepository.instance.logPrint(
        label: l, copies: copies, success: result.success, printer: name, message: result.success ? null : result.message,
      );
    }
    return result;
  }

  Future<PrintResult> testPrint() => print(const [
        LabelData(type: 'PRODUCT', code: 'TEST-123456', symbology: 'CODE128', title: 'TES PRINTER WMS', lines: ['Label 50 x 30 mm', 'Scan barcode ini']),
      ]);
}
