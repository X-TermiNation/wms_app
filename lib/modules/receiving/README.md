# Modul Penerimaan Barang

Frontend dummy untuk transaksi penerimaan barang.

## Fitur
- Ringkasan total transaksi, transaksi menunggu, dan total unit pada transaksi selesai.
- Pencarian nomor penerimaan, supplier, dan gudang.
- Filter status Draft, Pending, Completed, dan Cancelled.
- Pembuatan transaksi dengan supplier, gudang aktif, tanggal, item produk, kuantitas, dan catatan.
- Detail transaksi.
- Perubahan status Pending/Draft menjadi Completed atau Cancelled.
- Penghapusan transaksi Draft.
- Saat transaksi diselesaikan, kuantitas item ditambahkan ke stok produk pada `ProductsController`.

## Catatan
Data masih dummy dan disimpan di memori selama aplikasi berjalan. Belum ada API, database, purchase order, validasi dokumen supplier, atau proses scan barcode.
