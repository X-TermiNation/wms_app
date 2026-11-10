import 'dart:async';

import 'package:flutter/services.dart';

/// Receives barcode broadcasts from the built-in SUNMI scanner.
///
/// The Android side listens for:
/// com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED
/// and reads the `data` extra as the barcode value.
class ScannerService {
  ScannerService._();

  static final ScannerService instance = ScannerService._();

  static const EventChannel _channel =
      EventChannel('com.mywms/scanner/events');

  Stream<String>? _barcodeStream;

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

  /// Convenience subscription helper for screens and forms.
  StreamSubscription<String> listen(
    void Function(String barcode) onBarcode, {
    Function? onError,
  }) {
    return onBarcodeScanned.listen(onBarcode, onError: onError);
  }
}
