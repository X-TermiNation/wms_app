# Update WMS Aplikasi AIDC — Scan, Batch, QC, FEFO, Multi-Branch

Dokumen ini merangkum audit, perubahan, API, migration, hasil pengujian, panduan uji di perangkat,
dan pekerjaan yang masih tersisa. Backend ada di folder `../warehouse_management_backend`
(lihat README di sana untuk detail endpoint).

## 1. Audit sebelum implementasi

| Area | Kondisi awal | Keputusan |
|---|---|---|
| Arsitektur Flutter | GetX (binding/controller/view per modul), sudah terhubung ke REST API | Dipertahankan |
| Scanner | `ScannerService` + EventChannel `com.mywms/scanner/events` + BroadcastReceiver di `MainActivity.kt` | Native **tidak diubah**. Dart: konteks halaman aktif, anti scan ganda, feedback |
| Stok | `products.stock` + lot per gudang tanpa lokasi/status; stok "untracked" | Diganti saldo per batch × gudang × lokasi × status |
| Receiving | Selesai = stok langsung bertambah | Konfirmasi → batch + barcode batch → RECEIVING / QC-HOLD |
| Putaway, QC | Tidak ada | Modul baru |
| Issuing | FEFO ada, alokasi tidak disimpan, tanpa status | Hanya AVAILABLE, alokasi tersimpan, scan batch langsung |
| Transfer | Pindah langsung | IN_TRANSIT + konfirmasi terima di gudang tujuan |
| Stock opname | Per produk | Per lokasi × batch × status + persetujuan |
| Master item di Aplikasi AIDC | Bisa tambah/edit produk, kategori, gudang, lokasi | Dijadikan hanya-baca (lookup) |
| Hak akses cabang | Tidak ada | `user_warehouses` + validasi backend di setiap transaksi |
| Idempotency | Tidak ada | Header `Idempotency-Key` |
| Offline | Tidak ada | Dievaluasi — lihat bagian 8 |

Risiko yang diidentifikasi: konversi stok lama (ditangani dengan batch `LEGACY-<SKU>`), perubahan
semantik `products.stock` (sekarang = total semua status; tampilan memakai `availableStock`),
dan endpoint lama yang berubah perilaku (receiving tidak lagi langsung AVAILABLE).

## 2. Perubahan backend

- **Migration** `database/migrations/002_scan_batch_qc.js` + runner `src/db/migrate.js`
  (non-destruktif, idempotent, rollback teruji).
- **Service inti**: `inventory.service.js` (semua perubahan stok + audit trail + FEFO),
  `location.service.js`, `access.service.js`, `barcode.service.js` (nomor batch, SKU/EAN otomatis, GS1),
  `serializers.js`, middleware `idempotency.js`.
- **Modul baru**: `scan`, `batches` (saldo, detail batch, riwayat), `qc` (putaway, QC transfer/inspection/
  release/disposisi, inventory moves), `users` (user + akses gudang, cabang).
- **Modul ditulis ulang**: receivings, issuings, transfers, stock-opnames, products, warehouses, locations,
  dashboard; categories & master data dibatasi admin.
- `stock.service.js` lama dihapus.

## 3. Perubahan Flutter (file)

| File | Perubahan |
|---|---|
| `services/scanner/scanner_service.dart` | `register()` stack handler (halaman/dialog teratas), anti duplikat 500 ms, `simulate()` input manual, `ScanFeedback` getar/suara |
| `services/api/api_client.dart` | `Idempotency-Key`, `newIdempotencyKey()`, status `connection` (Online/Offline) |
| `services/auth/warehouse_context.dart` (baru) | Gudang yang boleh diakses + gudang aktif tersimpan |
| `services/auth/auth_service.dart`, `storage/session_storage.dart` | Simpan akses gudang & gudang aktif |
| `data/models/inventory_models.dart` (baru) | ScanResult, BatchInfo, InventoryBalance, LocationInfo, Gs1Data, StockMovement, QcInspection, label/warna status |
| `data/repositories/inventory_repository.dart` (baru) | Scan, saldo, riwayat, putaway/QC |
| `common/widgets/scan_widgets.dart` (baru) | ScanPromptCard (+input manual), QtyStepper besar, BalanceTile, StatusPill, BottomActionBar, konfirmasi |
| `common/widgets/document_widgets.dart` (baru) | Komponen daftar & detail transaksi |
| `common/widgets/product_picker.dart`, `outbound_item_sheet.dart` (baru) | Cari produk manual, dialog item belum terdaftar, scan item/batch untuk barang keluar |
| `modules/stock_move/*` (baru) | Putaway, QC Transfer, QC Release (satu modul, 3 mode) |
| `modules/qc/*` (baru) | QC Inspection (parsial, recheck, riwayat), QC Hold, QC Rejected (disposisi) |
| `modules/history/history_module.dart` (baru) | Riwayat transaksi + jejak batch |
| `modules/receiving/*` | Form scan-first, GS1 prefill lot/expiry, validasi expiry, konfirmasi → daftar batch |
| `modules/issuing/*` | Scan item (FEFO) / batch, alokasi batch ditampilkan |
| `modules/transfers/*` | Status IN_TRANSIT, kirim, halaman terima (scan batch + rak opsional) |
| `modules/stock_opname/*` | Scan lokasi → batch, status per baris, draft + persetujuan |
| `modules/products/*` | Lookup hanya-baca + stok per batch/lokasi/status; form produk/kategori dihapus |
| `modules/warehouse/*` | Hanya-baca, tipe & barcode lokasi; form gudang/lokasi dihapus |
| `modules/dashboard/*` | Dashboard operasional: gudang aktif, Online/Offline, antrean, 13 menu |
| `application/routes/*` | Route baru: putaway, qc-transfer, qc-inspection, qc-release, qc-hold, qc-rejected, history |
| `test/models_test.dart`, `test/scanner_service_test.dart` (baru) | Unit test |

## 4. Migration database

`npm run migrate` → `002_scan_batch_qc`:

- Tabel baru: `branches`, `user_warehouses`, `product_identifiers`, `inventory_balances`, `inventory_moves`,
  `qc_inspections`, `issuing_item_lots`, `transfer_item_lots`, `idempotency_keys`, `schema_migrations`.
- Kolom baru: `products.requires_qc/has_expiry/image_url/is_active`, `warehouses.branch_id`,
  `warehouse_locations.location_type/barcode/is_active`, `product_stock_lots.batch_number/supplier_lot/receiving_id`,
  `stock_movements.direction/unit/from_*/to_*`, item receiving/issuing/transfer/opname (lot, lokasi, status).
- ENUM diperluas: `users.role` (+supervisor, qc), `transfers.status` (+in_transit).
- Data: lokasi sistem per gudang; stok lama → batch `LEGACY-<SKU>` AVAILABLE + movement `opening_balance`.

## 5. Hasil pengujian

- `flutter analyze` → **No issues found**.
- `flutter test` → **8/8 lulus** (parsing model, konteks scanner, anti duplikat, input manual).
- Backend `npm run test:scenarios` (database `wms_db_test`) → **11/11 lulus**:
  A receiving normal + putaway · B receiving QC · C QC parsial 60/30/10 + release · D QC PASS belum putaway
  tidak bisa issue · E recheck + riwayat · F FEFO (expired & QC tidak dipakai, tanpa expiry paling akhir) ·
  G transfer IN_TRANSIT + terima parsial · H idempotency · I hak akses cabang · opname · GS1.
  Invarian dicek setiap skenario: `products.stock` = `lot.quantity` = Σ saldo, tidak ada saldo negatif.
- Migration: up → down (skema identik dengan awal) → up → up (tidak ada perubahan).
- **Belum diuji**: aplikasi Flutter di perangkat AIDC / emulator (UI, scanner fisik, layout).

## 6. Panduan uji di Aplikasi AIDC

1. Backend: `npm run migrate` di database yang dipakai, lalu `npm run dev`.
2. Set produk uji wajib QC/expiry (sementara, sampai Desktop tersedia), mis. via phpMyAdmin:
   `UPDATE products SET requires_qc = 1, has_expiry = 1 WHERE sku = 'ELK-002';`
3. Login di Aplikasi AIDC → pilih gudang aktif di dashboard → indikator harus **Online**.
4. **Receiving**: Penerimaan Baru → scan barcode item (ketik manual `8991001000041` jika perlu) → qty →
   Simpan & Konfirmasi → catat nomor batch (`B…`).
5. **Putaway**: scan batch → scan lokasi rak (barcode `WH-SBY-001-A-01-02`) → konfirmasi → cek Lookup Produk: AVAILABLE bertambah.
6. **QC**: receiving ELK-002 → QC Inspection: scan batch → PASS/FAIL/HOLD → QC Release: scan batch → scan rak.
   QC Hold → Recheck. QC Rejected → Tindak lanjut.
7. **Issuing**: scan item → qty → Simpan & Keluarkan → lihat batch FEFO yang dipilih.
8. **Transfer**: buat & kirim ke gudang lain → login user gudang tujuan → Transfer → "Perlu Diterima" → Terima → scan batch.
9. **Stock opname**: Hitung Lokasi → scan lokasi → scan batch berulang → Simpan Draft → setujui (supervisor/admin).
10. **Riwayat**: scan batch untuk melihat jejak lengkap sejak receiving.
11. Uji scan ganda: tekan tombol scan cepat pada barcode yang sama — hanya satu yang diproses.
12. Uji barcode tidak terdaftar: muncul "Item belum terdaftar. Silakan hubungi administrator…".

Lokasi sistem & barcode-nya terlihat di menu **Lokasi**. Barcode batch/lokasi perlu dicetak sebagai
label (Code128) dari Desktop — Aplikasi AIDC tidak mencetak label.

## 7. Pekerjaan yang masih diperlukan

- ~~Desktop Application~~ → **sudah diperbarui** (lihat bagian 9).
- ~~Master supplier & satuan~~ → migration `003_suppliers_units` + endpoint `/units`, `/suppliers`.
- **Cetak label** barcode batch/lokasi belum ada.
- **Lampiran foto QC**: kolom `attachment_url` sudah ada, endpoint upload & UI belum.
- ~~Laporan manajemen agregat~~ → `/reports/overview`, `/reports/stock`, `/reports/movements`.
- **Receiving di Aplikasi AIDC** masih mengetik supplier sebagai teks (backend mencocokkan nama ke master supplier);
  pemilihan supplier dari daftar master di Aplikasi AIDC belum dibuat.
- **Transfer**: penutupan selisih (barang diterima kurang dari dikirim) belum ada; sisa tetap IN_TRANSIT.
  Transfer barang berstatus QC antar gudang sengaja ditolak (perlu workflow & otorisasi khusus).
- **Offline queue** belum dibuat (bagian 8).

## 8. Offline & sinkronisasi (evaluasi)

Yang **sudah** ada: indikator Online/Offline di dashboard dan `Idempotency-Key` pada setiap transaksi,
sehingga retry setelah koneksi putus tidak membuat transaksi ganda.

Yang **belum** ada: cache master data lokal, antrean transaksi offline, status Pending Sync / Sync Failed.
Saat offline, transaksi **tidak tersimpan** dan harus diulang ketika koneksi kembali. Implementasi offline
yang aman membutuhkan penyimpanan lokal (mis. sqflite), antrean dengan idempotency key per transaksi,
dan penanganan konflik stok dari backend — belum dikerjakan.

## 9. Update Desktop (WMS Management) — 13 Nov 2026

Project: `C:\Work\NVT\Warehouse Management Dashboard\wms_dashboard`.

**Audit awal**: aplikasi read-only dengan data dummy (`dummy_data.dart`), tanpa login dan tanpa koneksi API,
9 menu (Stock Monitoring, Products, Warehouse, 4 laporan, Stock Movement, Users). Belum ada master supplier/satuan,
laporan agregat, maupun filter cabang/periode di backend.

**Backend**
- Migration `003_suppliers_units` (non-destruktif, rollback teruji): tabel `suppliers`, `units`,
  kolom `receivings.supplier_id`; seed dari data lama.
- Modul baru `masters` (`/units`, `/suppliers`) dan `reports` (`/reports/overview|stock|movements`, admin/supervisor).
- Receiving menerima `supplierId` (teks `supplier` tetap didukung dan dicocokkan ke master).
- Produk hanya boleh memakai satuan yang terdaftar & aktif.
- Filter baru: `branchId`, `dateFrom/dateTo` pada daftar dokumen; `branchId`, `expiry`, `expiringDays`, `limit` pada saldo;
  `branchId`, `direction`, `dateFrom/dateTo`, `search` pada stock movements.

**Desktop**: login (admin/supervisor) + pengaturan server, Overview seluruh cabang, laporan stok per
cabang/gudang/lokasi/produk/batch × status, batch & expiry, QC & barang tertahan, monitoring receiving/issuing/
transfer/opname (+ persetujuan opname), laporan pergerakan, CRUD master (produk + SKU/EAN otomatis + barcode supplier,
kategori, satuan, supplier, cabang, gudang, lokasi, user & akses gudang). File lama berbasis dummy tidak dihapus
(berisi perubahan belum di-commit) dan tidak lagi dipakai.

**Pengujian**
- Backend `npm run test:scenarios` → **13/13 lulus** (11 lama + 2 skenario Desktop: master supplier/satuan,
  laporan = Σ saldo untuk setiap groupBy, filter expiry & periode).
- Migration 003: down → up, skema identik.
- Desktop `flutter analyze` → No issues; `flutter test` → 9/9 lulus; uji integrasi ke backend sungguhan
  (`wms_db_test`) → 2/2 lulus, 0 error 5xx.
- **Belum diuji**: menjalankan aplikasi Desktop secara visual. `flutter build windows` membutuhkan
  Developer Mode Windows (symlink untuk plugin) yang belum aktif di PC ini.
- Data `wms_db`: tabel `branches` masih kosong, jadi semua gudang tampil "Tanpa cabang" sampai cabang dibuat
  dan dipasangkan ke gudang dari menu Gudang.

## 10. Smart Receiving, Barcode Internal & Cetak Label — 16 Nov 2026

**Audit**: master item, SKU otomatis, barcode internal EAN-13 (prefix 200) saat registrasi, barcode alternatif,
batch barcode, batch per receiving, QC/putaway sudah ada dan **tidak diubah**. Yang belum ada: generate barcode untuk
produk lama/massal (5 dari 6 produk memakai barcode pabrik sebagai barcode utama), konversi kemasan, receiving 3 mode,
hitung scan + undo, temporary receiving + foto, approval registrasi, dan cetak label di kedua aplikasi.

Keputusan (disetujui): barcode internal jadi barcode utama, barcode pabrik lama dipindah ke barcode alternatif;
temporary yang disetujui dilanjutkan petugas di Aplikasi AIDC; printer label Bluetooth ESC/POS, label 50 × 30 mm.

**Backend** — migration `004_smart_receiving_labels` (non-destruktif, rollback teruji): `product_packages`,
`temporary_receivings`, `label_print_logs`, kolom kemasan & temporary di `receiving_items`. Endpoint baru: generate
barcode internal (satuan/massal, idempotent), CRUD kemasan, temporary receiving (+ foto, match/register/reject),
data label & riwayat cetak. `/scan` mengenali barcode kemasan & temporary barcode; `/receivings` menerima qty kemasan
(dikonversi ke base unit di backend) dan `temporaryReceivingId` (sekali saja, qty harus sama dengan hasil approval).

**Aplikasi AIDC** — menu Penerimaan Baru: Scan Barcode (scan berulang menambah qty, barcode kemasan × konversi, Undo Last Scan,
barcode tak dikenal → pilih produk / temporary), Barang Tanpa Barcode (pilih produk, counter + / −), Package / Bulk
(satuan kemasan, tampil konversi), Barang Belum Terdaftar (dropdown kategori/supplier/satuan, counter, scan barcode
supplier, foto kamera, label sementara; daftar status & "Terima Sekarang" setelah disetujui). Supplier & gudang dari
dropdown. Cetak label batch/produk/keduanya setelah konfirmasi, cetak ulang dari detail receiving & Lookup Produk,
Pengaturan Printer (pilih printer Bluetooth, lebar kertas, feed, tes cetak). Native perangkat tidak diubah.

**Desktop** — Produk & Barcode: kolom status barcode internal, filter, pilih banyak → Generate barcode / Cetak label,
"Generate semua yang belum", detail produk dengan generate, cetak label, barcode alternatif (+ cetak), kemasan/konversi
(+ cetak label kemasan). Menu baru **Registrasi Produk Tertunda** (foto, cocokkan produk lama, buat produk baru, tolak
dengan alasan). Cetak label batch dari dialog riwayat batch. Overview menampilkan registrasi tertunda & temporary siap
diterima. Cetak = PDF 50 × 30 mm ke printer Windows (+ simpan PDF).

**Pengujian**
- Backend `npm run test:scenarios` → **19/19 lulus** (13 lama + S1 barcode pabrik→alternate & batch label, S2 generate
  massal idempotent, S3 temporary → register produk baru → receiving sekali (QC_PENDING, tidak bisa di-issue),
  S3b match + konversi kemasan & reject, S4 kemasan × konversi ke base unit, S5 cetak ulang & log tidak membuat ID baru).
- Migration 004 down → up identik; upload & unduh foto diuji (tanpa token ditolak 401).
- Aplikasi AIDC `flutter analyze` bersih, `flutter test` **14/14** (termasuk perintah ESC/POS: Code128 set B/C, EAN-13, QR bila
  tidak muat, salinan, feed), `flutter build apk --debug` berhasil.
- Desktop `flutter analyze` bersih, `flutter test` **11/11** (PDF label 1 halaman per label per salinan), uji integrasi
  ke backend sungguhan **3/3**.
- **Belum diuji**: cetak fisik ke printer Bluetooth ESC/POS dan printer label Windows, kamera perangkat AIDC, tampilan UI di
  perangkat. Ukuran barcode di label perlu dicek dengan scanner setelah printer tersedia (atur Feed di Pengaturan Printer).

**Catatan**
- Qty tetap bilangan bulat dalam base unit; barang curah pecahan memerlukan base unit lebih kecil (mis. gram).
- Desktop memakai `image <4.11` karena `image 4.11.0` tidak kompatibel dengan batas `archive` dari paket `pdf`.

## 11. Integrasi ERP: PO → Receiving/Tally → Goods Receipt, SO → Issuing → Goods Issue (23 Nov 2026)

### Alur nyata
1. ERP membuat **Purchase Order**.
2. WMS menerima PO sebagai **Dokumen Inbound** (`IBD-…`). Endpoint: `POST /api/integration/v1/inbound-documents`.
3. Gudang melakukan **Receiving / Tally** di Aplikasi AIDC dengan mengacu pada dokumen tersebut.
4. WMS mencatat barang aktual yang diterima: qty, batch, ED, dan lot supplier.
5. WMS mengirim **Goods Receipt** ke ERP. Penerimaan boleh parsial; setiap receiving menjadi satu GR.
6. Stok mengikuti status: QC-HOLD bila wajib QC, RECEIVING lalu putaway menjadi AVAILABLE.

Sales Order mengikuti alur yang sama:

- SO dari ERP masuk sebagai **Dokumen Outbound** (`OBD-…`).
- Gudang melakukan picking / Issuing FEFO di Aplikasi AIDC.
- WMS mengirim **Goods Issue** ke ERP.

### Aplikasi AIDC
- **Receiving → Terima dari PO (Tally):**
  - Scan nomor PO atau pilih dari daftar PO terbuka di gudang aktif.
  - Scan barang. Item di luar PO ditolak.
  - Panel PO menampilkan "dihitung / sisa" per item.
  - Supplier otomatis dari PO.
  - Confirm Receiving.
- **Issuing → Dari Sales Order (Picking):**
  - Scan atau pilih SO. Tujuan otomatis dari customer SO.
  - Scan item atau batch. Item di luar SO dan qty melebihi sisa ditolak.
  - Batch tetap dipilih dengan FEFO.
- Penerimaan/pengeluaran tanpa dokumen (manual, temporary receiving) tetap tersedia.
- Badge Receiving/Issuing di dashboard ikut menghitung PO/SO yang belum selesai.

### Desktop
- **Dokumen ERP → Dokumen Inbound (PO) / Dokumen Outbound (SO):**
  - Daftar dengan persentase pemenuhan: hijau = 100%, merah = melebihi dokumen.
  - Detail item: dokumen / diterima / pending / sisa.
  - Transaksi gudang beserta status kirim ke ERP.
  - Aksi: short close dan batal.
  - Dokumen manual untuk retur/produksi; dokumen manual tidak dikirim ke ERP.
- **Sinkronisasi ERP:**
  - Antrean GR/GI (Menunggu / Terkirim / Gagal), percobaan, dan error.
  - Lihat payload; kirim ulang.
- Monitor Receiving/Issuing menampilkan kolom Ref. PO / SO. Overview menampilkan jumlah PO/SO terbuka dan sinkronisasi gagal.

### ERP Simulator (`../erp_simulator`)
- Tanpa dependency. Jalankan `npm start`, lalu buka http://localhost:4000.
- Fitur:
  - Membuat PO/SO dari master item WMS dan mengirimnya ke WMS.
  - Menerima GR/GI dan memperbarui progres PO/SO.
  - Log integrasi.
- Kunci sudah dipasangkan di `.env` simulator dan `.env` backend.

### Langkah setelah update
1. Backend: `npm run migrate`. Migration 005 hanya menambah tabel/kolom baru. Lalu `npm run dev`.
2. ERP simulator: `cd erp_simulator && npm start`.
3. Pengujian: backend 24/24 skenario (termasuk E1–E4 dari ujung ke ujung dengan simulator), Aplikasi AIDC 35 tes, Desktop 15 tes.

---

## 12. Pengiriman: Picking → Packing → Loading → Dispatch → POD (24 Nov 2026)

Barang keluar kini tidak berhenti di Issuing. Setelah barang di-pick, gudang mengemasnya ke koli berlabel, memuat koli ke kendaraan dengan scan, lalu memberangkatkan kendaraan. **Goods Issue baru dikirim ke ERP saat dispatch**, bersama data kendaraan.

### Aplikasi AIDC: dua menu baru
| Menu | Isi |
|---|---|
| **Packing** | Daftar *Siap packing* (issuing yang sudah di-pick) dan *Sedang dikemas*. Layar packing: scan barang/batch masuk ke koli aktif, qty per scan, tutup koli & buka koli baru, berat koli, panel *dikemas / di-pick* per batch, cetak label koli `CTN-…` (printer Bluetooth). |
| **Loading** | Daftar shipment (dimuat / dikirim) dan jumlah packing siap dimuat. **Shipment baru**: no. polisi, jenis kendaraan, sopir, HP, ekspedisi, dock, tanggal. Layar muat: scan label koli, progres *koli dimuat / total*, ketuk koli untuk bongkar, **Dispatch** dengan nomor segel, lalu **Konfirmasi Diterima (POD)**. |

- Setelah **Simpan & Keluarkan** di Issuing, dialog FEFO menawarkan **Lanjut Packing**.
- Detail issuing menampilkan tahap pengiriman, nomor packing, dan nomor shipment.
- Beranda: badge Packing = issuing menunggu packing; badge Loading = packing siap dimuat + shipment yang sedang dimuat.

### Aturan yang dijaga backend
- Hanya barang/batch hasil picking (alokasi FEFO) yang boleh masuk koli; qty tidak boleh melebihi hasil picking.
- Packing baru bisa diselesaikan bila semua barang sudah masuk koli. Koli kosong dihapus otomatis.
- Koli tidak bisa dimuat dua kali, dan packing dari gudang lain atau shipment lain ditolak.
- Dispatch ditolak bila ada koli yang belum dimuat. Setelah dispatch, shipment terkunci.
- Packing dan shipment bisa dibatalkan sebelum dispatch; pengeluaran kembali ke antrean.

### Desktop
- Menu baru **PENGIRIMAN → Packing** dan **Loading & Shipment**, dengan filter, kartu ringkasan, dan dialog detail.
- PDF baru: **Packing List** (isi koli + rekonsiliasi picking vs packing), **Manifest Muat** (daftar koli + jam dimuat), **Surat Jalan Pengiriman** (per kendaraan, per SO, dengan tanda tangan), serta rekap packing dan rekap shipment.
- Dokumen SO: kolom *Pengiriman* per transaksi dan ringkasan *di-pick / dikemas / dikirim / diterima*.
- Sinkronisasi ERP: status **Menunggu dispatch**, dan jenis event *Status: Dikemas / Dikirim / Diterima (POD)*.
- Overview: kartu Menunggu packing, Packing siap dimuat, Kendaraan sedang dimuat, Pengiriman dalam perjalanan.
- Monitoring Issuing: kolom *Pengiriman*.

### ERP
| Kapan | Event | Hasil di ERP simulator |
|---|---|---|
| Packing selesai | `SHIPMENT_PACKED` | SO ditandai *Dikemas* (jumlah koli) |
| Dispatch | `GOODS_ISSUE` (+ data kendaraan) dan `SHIPMENT_DISPATCHED` | SO **SHIPPED**, Delivery Note `DN-…` dibuat |
| POD | `SHIPMENT_DELIVERED` | Delivery Note diterima; SO **DELIVERED** |

ERP simulator punya tab baru **Pengiriman** (Delivery Note dan log update). Perilaku lama (GI saat issuing) tetap tersedia lewat `ERP_GOODS_ISSUE_AT=issuing` di `.env` backend.

### Langkah setelah update
1. Backend: `npm run migrate` (migration 006 hanya menambah tabel/kolom baru dan memperluas enum), lalu `npm run dev`.
2. ERP simulator: restart (`npm start`).
3. Pengujian: backend 25/25 skenario (E2 alur penuh SO → POD, E5 batal/manual/mode lama), Aplikasi AIDC 40 tes, Desktop 22 tes.
