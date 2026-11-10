# Module Pengeluaran Barang

Module pengeluaran barang menggunakan GetX dan dummy data, dengan integrasi stok ke `ProductsController`.

## Fitur
- Daftar transaksi, pencarian, filter status, ringkasan kuantitas.
- Form transaksi dengan tujuan, gudang asal, tanggal, beberapa produk, kuantitas, dan catatan.
- Validasi kuantitas terhadap stok yang tersedia, termasuk jika produk yang sama dimasukkan lebih dari sekali.
- Status Draft, Pending, Completed, dan Cancelled.
- Penyelesaian transaksi mengurangi stok produk; transaksi Completed/Cancelled dikunci.
- Draft dapat dihapus.

## Catatan
Data masih in-memory/dummy dan akan kembali ke data awal saat aplikasi dimulai ulang. Belum ada API atau database.
