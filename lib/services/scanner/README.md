# SUNMI Barcode Scanner

Aplikasi menerima hasil scan dari SUNMI melalui Android broadcast: `com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED`.

- Output perangkat: Broadcast aktif, Keystroke: No Text Output.
- Extra barcode: `data` (String).
- Extra raw bytes: `source_byte` (ByteArray).
- Native Android: `MainActivity.kt` mendaftarkan BroadcastReceiver ketika Flutter mulai listen pada EventChannel.
- Flutter: `ScannerService.instance.listen((barcode) { ... })`.

## Perilaku UI saat ini

- Produk: scan mengisi pencarian barcode/SKU dan menampilkan hasil.
- Transfer Baru: scan menambahkan produk dengan qty 1; scan ulang produk yang sama menambah qty 1.
- Stock Opname Baru: scan menambahkan stok fisik awal 1; scan ulang produk yang sama menambah hitungan 1.
- Barcode yang tidak cocok dengan `ProductModel.barcode` atau `ProductModel.sku` menampilkan notifikasi.

Receiver hanya aktif selama halaman yang berlangganan stream terbuka. Pastikan aplikasi scanner SUNMI mengirim broadcast ke action dan key di atas.
