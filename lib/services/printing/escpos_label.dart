import 'dart:convert';

import '../../data/models/inventory_models.dart';

/// Pembentuk perintah ESC/POS untuk label barcode 50 x 30 mm pada printer thermal 58 mm (384 dot, 203 dpi).
///
/// Isi per label: judul tebal, barcode (Code128 / EAN-13, teks di bawah), 1-3 baris info, lalu feed ke label
/// berikutnya. Barcode yang terlalu panjang untuk lebar kertas otomatis dicetak sebagai QR agar tidak terpotong.
class EscPosLabel {
  EscPosLabel({this.dotsWidth = 384, this.charsPerLine = 32, this.feedLines = 3, this.barcodeHeight = 64});

  /// Lebar area cetak dalam dot (58 mm = 384, 80 mm = 576).
  final int dotsWidth;
  /// Karakter per baris Font A pada lebar tersebut.
  final int charsPerLine;
  /// Baris kosong setelah label agar sobekan/gap jatuh di antara label.
  final int feedLines;
  /// Tinggi barcode dalam dot (64 dot = 8 mm).
  final int barcodeHeight;

  static const _esc = 0x1B, _gs = 0x1D;

  /// Lebar modul (dot) terbaik yang masih muat; null = tidak muat -> pakai QR.
  int? moduleWidthFor(LabelData label) {
    final modules = _isEan13(label) ? 95 + 18 : 11 * code128Payload(label.code).symbols + 35 + 20; // + quiet zone
    for (final w in [3, 2]) {
      if (modules * w <= dotsWidth) return w;
    }
    return null;
  }

  /// Data ESC/POS Code128 (GS k 73) yang ringkas: deret >= 4 digit memakai code set C (2 digit per simbol,
  /// byte bernilai 0-99), sisanya code set B. [symbols] = jumlah simbol data termasuk pindah code set.
  static ({List<int> bytes, int symbols}) code128Payload(String raw) {
    final s = _ascii(raw);
    final bytes = <int>[];
    var symbols = 0;
    String? set;
    var i = 0;
    while (i < s.length) {
      var run = 0;
      while (i + run < s.length && _isDigit(s.codeUnitAt(i + run))) {
        run++;
      }
      if (run >= 4) {
        if (run.isOdd) {
          // digit pertama tetap di set B agar sisanya genap
          if (set != 'B') {
            bytes.addAll('{B'.codeUnits);
            if (set != null) symbols++;
            set = 'B';
          }
          bytes.add(s.codeUnitAt(i));
          symbols++;
          i++;
          run--;
        }
        if (set != 'C') {
          bytes.addAll('{C'.codeUnits);
          if (set != null) symbols++;
          set = 'C';
        }
        for (var k = 0; k < run; k += 2) {
          bytes.add(int.parse(s.substring(i + k, i + k + 2)));
          symbols++;
        }
        i += run;
      } else {
        if (set != 'B') {
          bytes.addAll('{B'.codeUnits);
          if (set != null) symbols++;
          set = 'B';
        }
        final ch = s.codeUnitAt(i);
        if (ch == 0x7B) bytes.add(0x7B); // '{' di-escape menjadi '{{'
        bytes.add(ch);
        symbols++;
        i++;
      }
    }
    return (bytes: bytes, symbols: symbols);
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  bool _isEan13(LabelData l) => l.symbology == 'EAN13' && RegExp(r'^\d{12,13}$').hasMatch(l.code);

  /// Bytes untuk [copies] salinan setiap label.
  List<int> build(List<LabelData> labels, {int copies = 1}) {
    final out = <int>[_esc, 0x40]; // init
    for (final label in labels) {
      for (var i = 0; i < copies; i++) {
        out.addAll(_label(label));
      }
    }
    return out;
  }

  List<int> _label(LabelData l) {
    final b = <int>[];
    b.addAll([_esc, 0x61, 0x01]); // rata tengah
    b.addAll([_esc, 0x45, 0x01]); // tebal
    b.addAll(_text(_fit(l.title)));
    b.addAll([_esc, 0x45, 0x00]);
    final w = moduleWidthFor(l);
    if (w != null) {
      b.addAll([_gs, 0x48, 0x02]); // HRI di bawah barcode
      b.addAll([_gs, 0x66, 0x00]); // HRI font A
      b.addAll([_gs, 0x68, barcodeHeight.clamp(24, 255)]);
      b.addAll([_gs, 0x77, w]);
      if (_isEan13(l)) {
        final digits = ascii.encode(l.code.substring(0, 12)); // printer menghitung check digit
        b.addAll([_gs, 0x6B, 67, digits.length, ...digits]);
      } else {
        final data = code128Payload(l.code).bytes;
        b.addAll([_gs, 0x6B, 73, data.length, ...data]);
      }
      b.add(0x0A);
    } else {
      b.addAll(_qr(l.code));
      b.addAll(_text(_fit(l.code)));
    }
    for (final line in l.lines.take(3)) {
      b.addAll(_text(_fit(line)));
    }
    b.addAll([_esc, 0x64, feedLines.clamp(0, 10)]); // feed n baris
    return b;
  }

  List<int> _qr(String code) {
    final data = ascii.encode(_ascii(code));
    final len = data.length + 3;
    return [
      _gs, 0x28, 0x6B, 4, 0, 49, 65, 50, 0, // model 2
      _gs, 0x28, 0x6B, 3, 0, 49, 67, 5, // ukuran modul 5
      _gs, 0x28, 0x6B, 3, 0, 49, 69, 49, // koreksi error M
      _gs, 0x28, 0x6B, len % 256, len ~/ 256, 49, 80, 48, ...data, // simpan data
      _gs, 0x28, 0x6B, 3, 0, 49, 81, 48, // cetak
      0x0A,
    ];
  }

  /// Potong ke lebar baris supaya tidak terbungkus ke label berikutnya.
  String _fit(String s) {
    final t = _ascii(s);
    return t.length <= charsPerLine ? t : '${t.substring(0, charsPerLine - 1)}~';
  }

  /// Printer thermal umumnya hanya ASCII; ganti karakter lain.
  static String _ascii(String s) => s
      .replaceAll('·', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('×', 'x')
      .runes
      .map((r) => r >= 32 && r < 127 ? String.fromCharCode(r) : '?')
      .join();

  List<int> _text(String s) => [...ascii.encode(s), 0x0A];
}
