import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/erp_document_picker.dart';
import '../../../common/widgets/product_picker.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/erp_document_models.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../data/repositories/receiving_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/printing/printer_settings_page.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/receiving_controller.dart';
import 'temporary_receiving_pages.dart';

enum ReceivingMode { scan, manual, package }

// ================================================================ MENU
/// Menu Receiving: tiga pilihan besar. Gudang mengikuti akses petugas.
class ReceivingStartPage extends StatefulWidget {
  const ReceivingStartPage({super.key});

  @override
  State<ReceivingStartPage> createState() => _ReceivingStartPageState();
}

class _ReceivingStartPageState extends State<ReceivingStartPage> {
  int ready = 0;

  @override
  void initState() {
    super.initState();
    _loadReady();
  }

  Future<void> _loadReady() async {
    try {
      final list = await ReceivingRepository.instance.temporaries(warehouseId: WarehouseContext.instance.activeId.value, readyOnly: true);
      if (mounted) setState(() => ready = list.length);
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await Get.to(() => page);
    _loadReady();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Penerimaan Baru', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [IconButton(tooltip: 'Pengaturan printer', onPressed: () => Get.to(() => const PrinterSettingsPage()), icon: const Icon(Icons.print_outlined))],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          const WarehouseSelector(),
          const SizedBox(height: 14),
          _BigAction(
            icon: Icons.receipt_long_outlined,
            title: 'Terima dari PO (Tally)',
            subtitle: 'Scan / pilih dokumen PO dari ERP, lalu scan barang. Qty dicocokkan dengan PO dan dikirim ke ERP.',
            color: AppColors.charcoal,
            onTap: () => _open(ErpDocumentPickerPage(
              kind: ErpDocKind.inbound,
              onOpen: (doc) async => Get.to(() => ReceivingCountPage(mode: ReceivingMode.scan, document: doc)),
            )),
          ),
          _BigAction(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan Barcode',
            subtitle: 'Tanpa dokumen PO. Barcode pabrik / internal / kemasan, scan berulang untuk menghitung.',
            color: AppColors.primary,
            onTap: () => _open(const ReceivingCountPage(mode: ReceivingMode.scan)),
          ),
          _BigAction(
            icon: Icons.touch_app_outlined,
            title: 'Barang Tanpa Barcode',
            subtitle: 'Pilih produk dari daftar, hitung dengan tombol + / −.',
            color: AppColors.info,
            onTap: () => _open(const ReceivingCountPage(mode: ReceivingMode.manual)),
          ),
          _BigAction(
            icon: Icons.inventory_2_outlined,
            title: 'Package / Bulk',
            subtitle: 'Karton, box, sak, roll, kg. Otomatis dikonversi ke satuan dasar.',
            color: AppColors.success,
            onTap: () => _open(const ReceivingCountPage(mode: ReceivingMode.package)),
          ),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: const Icon(Icons.new_label_outlined, color: AppColors.warning, size: 30),
              title: const Text('Barang Belum Terdaftar', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ready > 0 ? 'Temporary receiving • $ready siap diterima' : 'Temporary receiving + label sementara'),
              trailing: ready > 0
                  ? CircleAvatar(radius: 13, backgroundColor: AppColors.success, child: Text('$ready', style: const TextStyle(color: Colors.white, fontSize: 12)))
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(const TemporaryReceivingListPage()),
            ),
          ),
        ]),
      );
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .35), width: 1.5)),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ]),
            ),
          ),
        ),
      );
}

/// Gudang aktif: teks jika hanya satu akses, dropdown jika lebih dari satu.
class WarehouseSelector extends StatelessWidget {
  const WarehouseSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = WarehouseContext.instance;
    return Obx(() {
      if (ctx.warehouses.length <= 1) {
        return Row(children: [
          const Icon(Icons.warehouse_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Gudang: ${ctx.activeName}', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]);
      }
      return DropdownButtonFormField<String>(
        initialValue: ctx.activeId.value.isEmpty ? null : ctx.activeId.value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Gudang', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.warehouse_outlined)),
        items: [for (final w in ctx.warehouses) DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.code})', overflow: TextOverflow.ellipsis))],
        onChanged: (v) {
          if (v != null) ctx.select(v);
        },
      );
    });
  }
}

/// Dropdown supplier dari master (tidak perlu mengetik nama supplier).
class SupplierDropdown extends StatelessWidget {
  const SupplierDropdown({super.key, required this.options, required this.value, required this.onChanged, this.label = 'Supplier *', this.allowEmpty = false});
  final List<OptionItem> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
        initialValue: options.any((o) => o.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, prefixIcon: const Icon(Icons.local_shipping_outlined)),
        items: [
          if (allowEmpty) const DropdownMenuItem<String?>(value: null, child: Text('Tidak diketahui')),
          for (final o in options) DropdownMenuItem<String?>(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      );
}

// ================================================================ HITUNG
class _Line {
  _Line({required this.product, required this.packages, required this.unit});
  final ProductBrief product;
  final List<PackageInfo> packages;
  String unit;
  int qty = 0;
  DateTime? expiry;
  String? lot;

  String get key => '${product.id}|$unit';
  int get factor => unit == product.unit ? 1 : (packages.firstWhereOrNull((p) => p.unitCode == unit)?.conversionFactor ?? 1);
  int get baseQty => qty * factor;
  bool get isPackage => unit != product.unit;

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'productName': product.name,
        if (isPackage) ...{'packageUnit': unit, 'packageQuantity': qty} else 'quantity': qty,
        'supplierLot': lot,
        'expiryDate': expiry == null ? null : ApiClient.formatDate(expiry!),
      };
}

/// Layar hitung barang masuk. Scan: setiap scan menambah qty (scan barcode kemasan = 1 kemasan).
/// Tanpa barcode / package: pilih produk dari daftar, hitung dengan tombol besar.
class ReceivingCountPage extends StatefulWidget {
  const ReceivingCountPage({super.key, required this.mode, this.document});
  final ReceivingMode mode;

  /// Tally terhadap dokumen PO (ERP): hanya item dokumen, supplier dari dokumen, qty dicek terhadap sisa PO.
  final ErpDocument? document;

  @override
  State<ReceivingCountPage> createState() => _ReceivingCountPageState();
}

class _ReceivingCountPageState extends State<ReceivingCountPage> {
  final c = Get.find<ReceivingController>();
  final repo = ReceivingRepository.instance;
  final lines = <_Line>[];
  final history = <String>[]; // key baris per scan, untuk Undo Last Scan
  final idempotencyKey = ApiClient.instance.newIdempotencyKey();
  List<OptionItem> suppliers = [];
  String? supplierId;
  ScanRegistration? _scan;
  bool _lookingUp = false;
  String? lastScanned;
  bool? lastScanOk;

  bool get isScan => widget.mode == ReceivingMode.scan;
  int get totalBase => lines.fold(0, (s, l) => s + l.baseQty);
  ErpDocument? get doc => widget.document;
  int countedFor(String productId) => lines.where((l) => l.product.id == productId).fold(0, (s, l) => s + l.baseQty);

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Receiving count');
    if (doc == null) _loadSuppliers();
    if (!isScan) WidgetsBinding.instance.addPostFrameCallback((_) => _pickProduct());
  }

  Future<void> _loadSuppliers() async {
    try {
      final s = await repo.suppliers();
      if (mounted) setState(() => suppliers = s);
    } catch (e) {
      showApiError(e, title: 'Gagal memuat supplier');
    }
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  String get _title => doc != null ? 'Tally ${doc!.displayNumber}' : switch (widget.mode) {
        ReceivingMode.scan => 'Scan Barcode',
        ReceivingMode.manual => 'Barang Tanpa Barcode',
        ReceivingMode.package => 'Package / Bulk',
      };

  _Line _lineFor(ProductBrief p, List<PackageInfo> packages, String unit) {
    final existing = lines.firstWhereOrNull((l) => l.product.id == p.id && l.unit == unit);
    if (existing != null) return existing;
    final l = _Line(product: p, packages: packages, unit: unit);
    lines.insert(0, l);
    return l;
  }

  Future<void> _onScan(String code) async {
    if (_lookingUp) return;
    setState(() => _lookingUp = true);
    try {
      final r = await InventoryRepository.instance.scan(code, warehouseId: c.warehouseId);
      switch (r.type) {
        case ScanType.product:
          final p = r.product!;
          if (doc != null && !doc!.contains(p.id)) {
            _fail('${p.name} tidak ada di PO ${doc!.displayNumber}');
            return;
          }
          final unit = r.package?.unitCode ?? p.unit;
          final packages = r.packages.isNotEmpty ? r.packages : [if (r.package != null) r.package!];
          setState(() {
            final line = _lineFor(p, packages, unit);
            line.qty += 1;
            if (line.expiry == null && r.gs1?.expiryDate != null) line.expiry = r.gs1!.expiryDate;
            if (line.lot == null && r.gs1?.lot != null) line.lot = r.gs1!.lot;
            history.add(line.key);
            lastScanned = r.package != null ? '${p.name} • 1 $unit = ${r.package!.conversionFactor} ${p.unit}' : p.name;
            lastScanOk = true;
          });
          ScanFeedback.success();
        case ScanType.temporary:
          if (doc != null) {
            _fail('Label sementara tidak dapat dipakai untuk Tally PO.');
            return;
          }
          ScanFeedback.success();
          final t = r.temporary!;
          if (t.readyToReceive) {
            await Get.to(() => TemporaryReceivePage(temporary: t));
          } else {
            _fail('${t.number}: ${t.statusLabel}');
          }
        case ScanType.batch:
          _fail('Yang discan adalah label batch ${r.batch!.batchNumber}. Scan barcode produk / kemasan.');
        case ScanType.location:
          _fail('Yang discan adalah lokasi ${r.location!.code}. Scan barcode produk / kemasan.');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404 && doc != null) {
        _fail('Barcode $code belum terdaftar. Pilih item dari daftar PO.');
      } else if (e.statusCode == 404) {
        _fail('Barcode $code belum terdaftar');
        await _notRegistered(code);
      } else {
        _fail(e.message);
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _fail(String message) {
    ScanFeedback.error();
    setState(() {
      lastScanned = message;
      lastScanOk = false;
    });
  }

  Future<void> _notRegistered(String code) async {
    final choice = await Get.dialog<String>(AlertDialog(
      icon: const Icon(Icons.help_outline_rounded, color: AppColors.warning, size: 36),
      title: const Text('Barcode belum terdaftar'),
      content: Text('Barcode $code tidak dikenal. Master produk tidak dibuat otomatis.'),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 6,
      actions: [
        FilledButton.icon(
          onPressed: () => Get.back(result: 'pick'),
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('Pilih dari daftar produk'),
        ),
        OutlinedButton.icon(
          onPressed: () => Get.back(result: 'temp'),
          icon: const Icon(Icons.new_label_outlined),
          label: const Text('Barang belum terdaftar'),
        ),
        TextButton(onPressed: () => Get.back(result: 'cancel'), child: const Text('Batal')),
      ],
    ));
    if (choice == 'pick') {
      await _pickProduct();
    } else if (choice == 'temp') {
      await Get.to(() => TemporaryReceivingFormPage(supplierBarcode: code));
    }
  }

  /// Tally PO: pilihan hanya item yang ada di dokumen.
  Future<String?> _pickFromDocument() => Get.bottomSheet<String>(
        SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: Get.height * .7),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 14, 8, 8), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text('Item PO ${doc!.displayNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              for (final l in doc!.lines)
                ListTile(
                  title: Text(l.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${l.sku} • sisa ${doc!.availableFor(l.productId)} ${l.unit}'),
                  trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onTap: () => Get.back(result: l.productId),
                ),
            ]),
          ),
        ),
        isScrollControlled: true,
      );

  Future<void> _pickProduct() async {
    final pickedId = doc != null ? await _pickFromDocument() : (await pickProductManually())?.id;
    if (pickedId == null) return;
    try {
      final detail = await repo.product(pickedId);
      final packages = detail.packages;
      final unit = widget.mode == ReceivingMode.package && packages.isNotEmpty ? packages.last.unitCode : detail.product.unit;
      setState(() {
        final line = _lineFor(detail.product, packages, unit);
        if (line.qty == 0) line.qty = 1;
      });
      if (widget.mode == ReceivingMode.package && packages.isEmpty) {
        Get.snackbar('Belum ada konversi kemasan', '${detail.product.name} hanya punya satuan ${detail.product.unit}. Admin dapat menambah kemasan di Desktop.',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      showApiError(e, title: 'Produk tidak dapat dimuat');
    }
  }

  void _undo() {
    if (history.isEmpty) return;
    final key = history.removeLast();
    setState(() {
      final l = lines.firstWhereOrNull((x) => x.key == key);
      if (l != null) {
        l.qty -= 1;
        if (l.qty <= 0) lines.remove(l);
      }
      lastScanned = 'Scan terakhir dibatalkan';
      lastScanOk = null;
    });
  }

  Future<void> _confirm() async {
    final active = lines.where((l) => l.qty > 0).toList();
    String? problem;
    if (active.isEmpty) {
      problem = 'Scan atau pilih produk terlebih dahulu.';
    } else if (doc == null && supplierId == null) {
      problem = 'Supplier wajib dipilih dari daftar.';
    } else {
      final missing = active.where((l) => l.product.hasExpiry && l.expiry == null).map((l) => l.product.name).toList();
      if (missing.isNotEmpty) problem = 'Isi tanggal kedaluwarsa untuk ${missing.join(', ')}.';
    }
    if (problem != null) {
      ScanFeedback.error();
      Get.snackbar('Belum lengkap', problem, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final over = doc == null
        ? <String>[]
        : active.map((l) => l.product).toSet().where((p) => countedFor(p.id) > doc!.availableFor(p.id))
            .map((p) => '${p.name} (${countedFor(p.id)} > sisa ${doc!.availableFor(p.id)})').toList();
    final docNote = doc == null
        ? ''
        : over.isEmpty
            ? ' Qty dicatat ke PO ${doc!.displayNumber} dan dikirim ke ERP sebagai Goods Receipt.'
            : '\n\nMelebihi sisa PO: ${over.join(', ')}. Backend akan menolak kecuali toleransi lebih-terima diizinkan.';
    if (!await confirmAction(
      title: 'Konfirmasi penerimaan?',
      message: '${active.length} baris, total $totalBase unit dasar akan dibuatkan batch baru. Barang wajib QC masuk QC-HOLD, lainnya ke RECEIVING untuk putaway.$docNote',
      confirmLabel: 'Confirm Receiving',
    )) {
      return;
    }
    final result = await c.submit(
      supplierId: doc == null ? supplierId : null,
      inboundDocumentId: doc?.id,
      items: active.map((l) => l.toJson()).toList(),
      idempotencyKey: idempotencyKey,
    );
    if (result == null || !mounted) return;
    final productIds = active.map((l) => l.product.id).toSet().toList();
    Get.back();
    await ReceivingController.showCreatedBatches(result.$2, productIds: productIds);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700))),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (doc == null) ...[
                SupplierDropdown(options: suppliers, value: supplierId, onChanged: (v) => setState(() => supplierId = v)),
                const SizedBox(height: 8),
              ],
              Row(children: [
                if (isScan)
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: history.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Undo'),
                    ),
                  ),
                if (isScan) const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: Obx(() => FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: c.isBusy.value || totalBase == 0 ? null : _confirm,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(c.isBusy.value ? 'Memproses...' : 'Confirm Receiving', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        )),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
          // Dokumen PO terikat ke satu gudang: gudang tidak boleh diganti selama Tally.
          if (doc == null) const WarehouseSelector(),
          if (doc == null) const SizedBox(height: 10),
          _TotalCard(total: totalBase, lines: lines.length, scanning: _lookingUp, last: lastScanned, lastOk: lastScanOk, isScan: isScan),
          const SizedBox(height: 10),
          if (isScan)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showManualScanDialog(title: 'Barcode tidak terbaca'),
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Input manual'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(onPressed: _pickProduct, icon: const Icon(Icons.list_alt_rounded), label: const Text('Pilih produk')),
              ),
            ])
          else
            SizedBox(
              height: 52,
              child: FilledButton.tonalIcon(
                onPressed: _pickProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Pilih Produk', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          const SizedBox(height: 12),
          if (doc != null) ...[
            ErpDocumentProgress(document: doc!, countedFor: countedFor),
            const SizedBox(height: 12),
          ],
          if (lines.isEmpty)
            EmptyState(
              message: isScan ? 'Arahkan scanner ke barcode barang dan tekan tombol scan.' : 'Pilih produk untuk mulai menghitung.',
              icon: isScan ? Icons.qr_code_scanner_rounded : Icons.touch_app_outlined,
            )
          else
            ...lines.map((l) => _LineCard(
                  line: l,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    lines.remove(l);
                    history.removeWhere((k) => k == l.key);
                  }),
                )),
        ]),
      );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.lines, required this.scanning, required this.last, required this.lastOk, required this.isScan});
  final int total, lines;
  final bool scanning, isScan;
  final String? last;
  final bool? lastOk;

  @override
  Widget build(BuildContext context) {
    final color = lastOk == null ? Colors.black54 : (lastOk! ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Text(isScan ? (scanning ? 'Mencari...' : 'Siap scan') : 'Total diterima', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        Text('$total', style: const TextStyle(fontSize: 56, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.primary)),
        Text('unit dasar • $lines baris', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        if (last != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(lastOk == false ? Icons.error_rounded : Icons.check_circle_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(last!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
          ]),
        ],
      ]),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.onChanged, required this.onRemove});
  final _Line line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final units = [p.unit, ...line.packages.map((k) => k.unitCode)];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text([p.sku, if (p.requiresQc) 'WAJIB QC'].join(' • '), style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, color: Colors.black38)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            if (units.length > 1)
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  initialValue: line.unit,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Satuan', border: OutlineInputBorder(), isDense: true),
                  items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u))],
                  onChanged: (v) {
                    if (v == null) return;
                    line.unit = v;
                    onChanged();
                  },
                ),
              )
            else
              Text(line.unit, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            _RoundButton(icon: Icons.remove_rounded, onTap: line.qty > 1 ? () { line.qty--; onChanged(); } : null),
            SizedBox(
              width: 72,
              child: Text('${line.qty}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            ),
            _RoundButton(icon: Icons.add_rounded, onTap: () { line.qty++; onChanged(); }),
          ]),
          if (line.isPackage)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${line.qty} ${line.unit} × ${line.factor} = ${line.baseQty} ${p.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
          if (p.hasExpiry || line.expiry != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: line.expiry == null ? AppColors.danger : AppColors.charcoal),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: line.expiry ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    line.expiry = picked;
                    onChanged();
                  }
                },
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: Text(line.expiry == null ? 'Pilih tanggal kedaluwarsa *' : 'ED ${formatDate(line.expiry)}${line.lot != null ? ' • Lot ${line.lot}' : ''}'),
              ),
            ),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 52,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder(), backgroundColor: AppColors.primary),
          onPressed: onTap,
          child: Icon(icon, size: 28),
        ),
      );
}
