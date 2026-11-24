import 'dart:async';

import 'package:flutter/services.dart';

/// Receives barcode broadcasts from the built-in SUNMI scanner.
///
/// The Android side (MainActivity.kt, tidak diubah) listens for:
/// com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED
/// and reads the `data` extra as the barcode value.
///
/// Konteks scan:
/// - Hanya handler yang terakhir didaftarkan (halaman / dialog paling atas)
///   yang menerima hasil scan. Saat dialog ditutup, handler halaman di
///   bawahnya aktif kembali. Ini mencegah satu scan diproses dua halaman.
/// - Barcode kosong diabaikan.
/// - Barcode yang sama dalam [duplicateWindow] dianggap pantulan scan ganda
///   dan diabaikan (bukan scan berulang yang disengaja).
class ScannerService {
  ScannerService._();

  static final ScannerService instance = ScannerService._();

  static const EventChannel _channel =
      EventChannel('com.mywms/scanner/events');

  static const duplicateWindow = Duration(milliseconds: 500);

  Stream<String>? _barcodeStream;
  StreamSubscription<String>? _dispatcher;
  final List<ScanRegistration> _stack = [];
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Emits one barcode string for each received SUNMI scan broadcast.
  ///
  /// This stream is Android/SUNMI-specific. On other platforms it emits no
  /// barcode events because the native broadcast receiver is Android-only.
  Stream<String> get onBarcodeScanned {
    _barcodeStream ??= _channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return (event['barcode'] ?? '').toString().trim();
      }
      return event.toString().trim();
    }).where((barcode) => barcode.isNotEmpty).asBroadcastStream();

    return _barcodeStream!;
  }

  /// Daftarkan handler scan untuk halaman/dialog yang sedang aktif.
  /// Wajib memanggil [ScanRegistration.cancel] di dispose / onClose.
  ScanRegistration register(
    void Function(String barcode) onBarcode, {
    void Function(Object error)? onError,
    String label = '',
  }) {
    final registration = ScanRegistration._(this, onBarcode, onError, label);
    _stack.add(registration);
    _dispatcher ??= onBarcodeScanned.listen(_dispatch, onError: _dispatchError);
    return registration;
  }

  /// Kompatibilitas API lama: sama dengan [register].
  ScanRegistration listen(
    void Function(String barcode) onBarcode, {
    Function? onError,
  }) =>
      register(onBarcode, onError: onError == null ? null : (e) => onError(e));

  /// Kirim barcode secara manual (input ketik / perangkat tanpa scanner).
  void simulate(String barcode) => _dispatch(barcode.trim(), manual: true);

  void _dispatch(String code, {bool manual = false}) {
    if (code.isEmpty || _stack.isEmpty) return;
    final now = DateTime.now();
    if (!manual && code == _lastCode && now.difference(_lastAt) < duplicateWindow) return;
    _lastCode = code;
    _lastAt = now;
    _stack.last._onBarcode(code);
  }

  void _dispatchError(Object error) {
    if (_stack.isNotEmpty) _stack.last._onError?.call(error);
  }

  void _remove(ScanRegistration registration) {
    _stack.remove(registration);
    if (_stack.isEmpty) {
      _dispatcher?.cancel();
      _dispatcher = null;
    }
  }
}

class ScanRegistration {
  ScanRegistration._(this._service, this._onBarcode, this._onError, this.label);

  final ScannerService _service;
  final void Function(String barcode) _onBarcode;
  final void Function(Object error)? _onError;
  final String label;
  bool _cancelled = false;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _service._remove(this);
  }
}

/// Feedback getar + suara singkat setelah scan diproses.
abstract final class ScanFeedback {
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }
}
