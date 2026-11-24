import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/label_widgets.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/receiving_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/receiving_controller.dart';
import 'smart_receiving_pages.dart';

Color _statusColor(TemporaryReceiving t) {
  if (t.receivingNumber != null) return AppColors.success;
  return switch (t.status) {
    'PENDING_REGISTRATION' => AppColors.warning,
    'REJECTED' => AppColors.danger,
    _ => AppColors.info,
  };
}

// ================================================================ FORM
/// Barang belum terdaftar: tanpa mengetik nama/SKU. Dropdown + counter + foto; sistem membuat
/// nomor & temporary barcode, lalu label sementara dicetak dan ditempel pada barang.
class TemporaryReceivingFormPage extends StatefulWidget {
  const TemporaryReceivingFormPage({super.key, this.supplierBarcode});
  final String? supplierBarcode;

  @override
  State<TemporaryReceivingFormPage> createState() => _TemporaryReceivingFormPageState();
}

class _TemporaryReceivingFormPageState extends State<TemporaryReceivingFormPage> {
  final repo = ReceivingRepository.instance;
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  List<OptionItem> categories = [], suppliers = [], units = [];
  String? categoryId, supplierId;
  String unit = 'PCS';
  int qty = 1;
  String? supplierBarcode;
  Uint8List? photo;
  bool busy = false;
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    supplierBarcode = widget.supplierBarcode;
    _scan = ScannerService.instance.register((code) {
      ScanFeedback.success();
      setState(() => supplierBarcode = code);
    }, label: 'Temporary receiving');
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([repo.categories(), repo.suppliers(), repo.units()]);
      if (!mounted) return;
      setState(() {
        categories = r[0];
        suppliers = r[1];
        units = r[2];
        if (units.isNotEmpty && !units.any((u) => u.id == unit)) unit = units.first.id;
      });
    } catch (e) {
      showApiError(e, title: 'Gagal memuat master data');
    }
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 60, maxWidth: 1280);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => photo = bytes);
    } catch (e) {
      showApiError(e, title: 'Kamera tidak dapat dibuka');
    }
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      var t = await repo.createTemporary(
        warehouseId: WarehouseContext.instance.activeId.value,
        unit: unit,
        quantity: qty,
        categoryId: categoryId,
        supplierId: supplierId,
        supplierBarcode: supplierBarcode,
        idempotencyKey: idempotencyKey,
      );
      if (photo != null) {
        try {
          t = await repo.uploadPhoto(t.id, photo!);
        } catch (e) {
          showApiError(e, title: 'Temporary tersimpan, foto gagal diunggah');
        }
      }
      ScanFeedback.success();
      if (!mounted) return;
      Get.back();
      await _showSaved(t);
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Gagal menyimpan');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _showSaved(TemporaryReceiving t) => Get.dialog(AlertDialog(
        icon: const Icon(Icons.new_label_rounded, color: AppColors.warning, size: 36),
        title: const Text('Temporary receiving tersimpan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(t.tempBarcode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: .5)),
          const SizedBox(height: 6),
          Text('${t.quantity} ${t.unit} • PENDING REGISTRATION\nCetak dan tempel label sementara pada barang / pallet.', textAlign: TextAlign.center),
        ]),
        actions: [
          OutlinedButton(onPressed: Get.back, child: const Text('Selesai')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => printFromBackend([('TEMPORARY', t.tempBarcode)], title: 'Label Sementara'),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Cetak Label'),
          ),
        ],
      ));

  Widget _dropdown(String label, IconData icon, List<OptionItem> options, String? value, ValueChanged<String?> onChanged, {bool optional = true}) =>
      DropdownButtonFormField<String?>(
        initialValue: options.any((o) => o.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, prefixIcon: Icon(icon)),
        items: [
          if (optional) const DropdownMenuItem<String?>(value: null, child: Text('Tidak diketahui')),
          for (final o in options) DropdownMenuItem<String?>(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Barang Belum Terdaftar', style: TextStyle(fontWeight: FontWeight.w700))),
        bottomNavigationBar: BottomActionBar(label: busy ? 'Menyimpan...' : 'Simpan & Buat Label', busy: busy, onPressed: _save, icon: Icons.new_label_outlined),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          const WarehouseSelector(),
          const SizedBox(height: 12),
          _dropdown('Kategori', Icons.category_outlined, categories, categoryId, (v) => setState(() => categoryId = v)),
          const SizedBox(height: 10),
          _dropdown('Supplier', Icons.local_shipping_outlined, suppliers, supplierId, (v) => setState(() => supplierId = v)),
          const SizedBox(height: 10),
          _dropdown('Satuan *', Icons.straighten_outlined, units, unit, (v) => setState(() => unit = v ?? unit), optional: false),
          const SizedBox(height: 14),
          QtyStepper(label: 'Jumlah barang', value: qty, min: 1, unit: unit, onChanged: (v) => setState(() => qty = v)),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: Icon(Icons.qr_code_2_rounded, color: supplierBarcode == null ? Colors.black38 : AppColors.success),
              title: Text(supplierBarcode ?? 'Barcode supplier (opsional)', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(supplierBarcode == null ? 'Scan barcode di kemasan jika ada' : 'Akan dipakai admin sebagai referensi'),
              trailing: supplierBarcode == null
                  ? null
                  : IconButton(onPressed: () => setState(() => supplierBarcode = null), icon: const Icon(Icons.close_rounded)),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                if (photo != null)
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(photo!, height: 160, fit: BoxFit.cover, width: double.infinity)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(photo == null ? 'Ambil foto barang (disarankan)' : 'Ganti foto'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nomor dan barcode sementara dibuat otomatis. Barang belum menjadi stok sampai admin meregistrasi produk di Desktop.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ]),
      );
}

// ================================================================ DAFTAR
class TemporaryReceivingListPage extends StatefulWidget {
  const TemporaryReceivingListPage({super.key});

  @override
  State<TemporaryReceivingListPage> createState() => _TemporaryReceivingListPageState();
}

class _TemporaryReceivingListPageState extends State<TemporaryReceivingListPage> {
  final repo = ReceivingRepository.instance;
  List<TemporaryReceiving> items = [];
  bool loading = true;
  String filter = 'ready';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      items = await repo.temporaries(warehouseId: WarehouseContext.instance.activeId.value);
    } catch (e) {
      showApiError(e, title: 'Gagal memuat temporary receiving');
    }
    if (mounted) setState(() => loading = false);
  }

  List<TemporaryReceiving> get shown => switch (filter) {
        'ready' => items.where((t) => t.readyToReceive).toList(),
        'pending' => items.where((t) => t.status == 'PENDING_REGISTRATION').toList(),
        'done' => items.where((t) => t.receivingNumber != null || t.status == 'REJECTED').toList(),
        _ => items,
      };

  Future<void> _open(TemporaryReceiving t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(t.statusLabel, style: TextStyle(fontWeight: FontWeight.w700, color: _statusColor(t))),
            const SizedBox(height: 8),
            InfoRow('Qty', '${t.quantity} ${t.unit}', bold: true),
            if (t.categoryName != null) InfoRow('Kategori', t.categoryName!),
            if (t.supplierName != null) InfoRow('Supplier', t.supplierName!),
            if (t.supplierBarcode != null) InfoRow('Barcode supplier', t.supplierBarcode!),
            if (t.productName != null) InfoRow('Produk', '${t.productSku} • ${t.productName}', bold: true),
            if (t.baseQuantity != null) InfoRow('Qty diterima', '${t.baseQuantity} ${t.productUnit ?? ''}'),
            if (t.rejectReason != null) InfoRow('Alasan ditolak', t.rejectReason!),
            if (t.receivingNumber != null) InfoRow('Receiving', t.receivingNumber!),
            InfoRow('Dibuat', formatDateTime(t.createdAt)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => printFromBackend([('TEMPORARY', t.tempBarcode)], title: 'Cetak Ulang Label Sementara'),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Cetak ulang label sementara'),
            ),
            if (t.readyToReceive) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Get.to(() => TemporaryReceivePage(temporary: t));
                    _load();
                  },
                  icon: const Icon(Icons.move_to_inbox_rounded),
                  label: const Text('Terima Sekarang', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Temporary Receiving', style: TextStyle(fontWeight: FontWeight.w700))),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () async {
            await Get.to(() => const TemporaryReceivingFormPage());
            _load();
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Barang Baru'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
            Wrap(spacing: 6, children: [
              for (final f in const [('ready', 'Siap diterima'), ('pending', 'Menunggu admin'), ('done', 'Selesai/Ditolak'), ('all', 'Semua')])
                ChoiceChip(label: Text(f.$2), selected: filter == f.$1, onSelected: (_) => setState(() => filter = f.$1)),
            ]),
            const SizedBox(height: 10),
            if (loading)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              const EmptyState(message: 'Tidak ada data.', icon: Icons.new_label_outlined)
            else
              ...shown.map((t) => Card(
                    child: ListTile(
                      minVerticalPadding: 12,
                      leading: Icon(t.readyToReceive ? Icons.check_circle_rounded : Icons.new_label_outlined, color: _statusColor(t)),
                      title: Text(t.productName ?? t.number, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${t.number} • ${t.quantity} ${t.unit}\n${t.statusLabel}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(t),
                    ),
                  )),
          ]),
        ),
      );
}

// ================================================================ LANJUTKAN PENERIMAAN
/// Temporary yang sudah disetujui admin dilanjutkan menjadi receiving resmi: produk & qty sudah ditentukan,
/// petugas tidak menghitung ulang. Backend menolak bila sudah pernah diterima.
class TemporaryReceivePage extends StatefulWidget {
  const TemporaryReceivePage({super.key, required this.temporary});
  final TemporaryReceiving temporary;

  @override
  State<TemporaryReceivePage> createState() => _TemporaryReceivePageState();
}

class _TemporaryReceivePageState extends State<TemporaryReceivePage> {
  final c = Get.find<ReceivingController>();
  final repo = ReceivingRepository.instance;
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  ProductBrief? product;
  List<OptionItem> suppliers = [];
  String? supplierId;
  DateTime? expiry;

  TemporaryReceiving get t => widget.temporary;

  @override
  void initState() {
    super.initState();
    supplierId = t.supplierId;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([repo.product(t.productId!), repo.suppliers()]);
      if (!mounted) return;
      setState(() {
        product = (r[0] as ProductWithPackages).product;
        suppliers = r[1] as List<OptionItem>;
      });
    } catch (e) {
      showApiError(e, title: 'Gagal memuat produk');
    }
  }

  Future<void> _confirm() async {
    final p = product;
    if (p == null) return;
    if (p.hasExpiry && expiry == null) {
      ScanFeedback.error();
      Get.snackbar('Tanggal kedaluwarsa wajib', 'Pilih tanggal kedaluwarsa ${p.name}.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (supplierId == null) {
      ScanFeedback.error();
      Get.snackbar('Pilih supplier', 'Supplier wajib dipilih dari daftar.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final result = await c.submit(
      supplierId: supplierId,
      temporaryReceivingId: t.id,
      items: [
        {'productId': p.id, 'quantity': t.baseQuantity, 'expiryDate': expiry == null ? null : ApiClient.formatDate(expiry!)},
      ],
      idempotencyKey: idempotencyKey,
    );
    if (result == null || !mounted) return;
    Get.back();
    await ReceivingController.showCreatedBatches(result.$2, productIds: [p.id]);
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Terima Barang Terdaftar', style: TextStyle(fontWeight: FontWeight.w700))),
      bottomNavigationBar: Obx(() => BottomActionBar(
            label: c.isBusy.value ? 'Memproses...' : 'Confirm Receiving',
            busy: c.isBusy.value || p == null,
            onPressed: _confirm,
          )),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.productName ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('${t.productSku ?? ''} • ${t.statusLabel}', style: const TextStyle(color: Colors.black54)),
              const Divider(height: 20),
              InfoRow('Temporary', t.number),
              InfoRow('Dicatat', '${t.quantity} ${t.unit}'),
              InfoRow('Diterima sebagai', '${t.baseQuantity} ${t.productUnit ?? ''}', bold: true),
              if (p?.requiresQc == true) const InfoRow('Alur', 'Wajib QC → QC-HOLD'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SupplierDropdown(options: suppliers, value: supplierId, onChanged: (v) => setState(() => supplierId = v)),
        if (p?.hasExpiry == true) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: expiry ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => expiry = picked);
              },
              icon: const Icon(Icons.event_available_outlined),
              label: Text(expiry == null ? 'Pilih tanggal kedaluwarsa *' : 'ED ${formatDate(expiry)}'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text('Qty sudah ditetapkan saat registrasi admin; tidak perlu menghitung ulang.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}
