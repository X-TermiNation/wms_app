import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/label_widgets.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart' show formatDate;
import '../../../data/models/shipping_models.dart';
import '../../../data/repositories/shipping_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';

/// Antrean packing: issuing yang sudah di-pick (siap packing) dan packing yang masih berjalan.
/// Scan nomor ISS / PCK untuk langsung membuka packing.
class PackingQueuePage extends StatefulWidget {
  const PackingQueuePage({super.key});

  @override
  State<PackingQueuePage> createState() => _PackingQueuePageState();
}

class _PackingQueuePageState extends State<PackingQueuePage> {
  final _repo = ShippingRepository.instance;
  List<PackingQueueItem> _ready = [];
  List<Packing> _open = [];
  bool _loading = true;
  bool _opening = false;
  String? _error;
  ScanRegistration? _scan;

  String get _warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Scan nomor pengeluaran / packing');
    _load();
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (ready, open) = await _repo.packingQueue(_warehouseId);
      if (mounted) {
        setState(() {
          _ready = ready;
          _open = open;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onScan(String code) async {
    if (code.toUpperCase().startsWith('PCK-')) {
      await _openPacking(() => _repo.packing(code));
    } else {
      await _openPacking(() => _repo.startPacking(code));
    }
  }

  Future<void> _openPacking(Future<Packing> Function() load) async {
    if (_opening) return;
    _opening = true;
    try {
      final p = await load();
      ScanFeedback.success();
      await Get.to(() => PackingPage(packingId: p.id));
      await _load();
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Packing tidak dapat dibuka');
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Packing', style: TextStyle(fontWeight: FontWeight.w700))),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const ScanPromptCard(
                title: 'Scan nomor pengeluaran (ISS)',
                subtitle: 'atau pilih dari daftar. Barang hasil picking dikemas ke koli berlabel.',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 14),
              if (_loading && _ready.isEmpty && _open.isEmpty)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                EmptyState(message: _error!, icon: Icons.cloud_off_rounded)
              else ...[
                if (_open.isNotEmpty) ...[
                  _SectionTitle('Sedang dikemas', _open.length),
                  for (final p in _open)
                    _QueueCard(
                      title: p.reference,
                      subtitle: '${p.destination} • ${p.number}',
                      info: '${p.totalPacked} / ${p.totalPicked} unit • ${p.totalCartons} koli',
                      progress: p.totalPicked == 0 ? 0 : p.totalPacked / p.totalPicked,
                      badge: 'Lanjutkan',
                      color: AppColors.warning,
                      onTap: () => _openPacking(() => _repo.packing(p.id)),
                    ),
                  const SizedBox(height: 8),
                ],
                _SectionTitle('Siap packing • ${WarehouseContext.instance.activeName}', _ready.length),
                if (_ready.isEmpty)
                  const EmptyState(message: 'Tidak ada barang yang menunggu packing.\nSelesaikan picking di menu Issuing terlebih dahulu.', icon: Icons.inventory_2_outlined)
                else
                  for (final r in _ready)
                    _QueueCard(
                      title: r.erpDocumentNo ?? r.issuingNumber,
                      subtitle: '${r.destination} • ${r.issuingNumber}',
                      info: '${r.totalLines} item • ${r.totalQuantity} unit${r.date != null ? ' • ${formatDate(r.date)}' : ''}',
                      badge: 'Mulai',
                      color: AppColors.info,
                      onTap: () => _openPacking(() => _repo.startPacking(r.issuingId)),
                    ),
              ],
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.count);
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.darkOrange)),
        ]),
      );
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.title, required this.subtitle, required this.info, required this.badge, required this.color, required this.onTap, this.progress});
  final String title, subtitle, info, badge;
  final Color color;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                const SizedBox(width: 6),
                AppStatusBadge(label: badge, color: color),
              ]),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress!.clamp(0, 1), minHeight: 8, color: color, backgroundColor: AppColors.border),
                ),
              ],
              const SizedBox(height: 6),
              Text(info, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// =====================================================================================
/// Layar packing: scan barang / batch -> masuk koli aktif. Satu koli = satu label CTN.
class PackingPage extends StatefulWidget {
  const PackingPage({super.key, required this.packingId});
  final String packingId;

  @override
  State<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends State<PackingPage> {
  final _repo = ShippingRepository.instance;
  Packing? _p;
  bool _busy = false;
  int _qtyPerScan = 1;
  String? _lastScan;
  bool _lastOk = true;
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Scan barang ke koli');
    _load();
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _repo.packing(widget.packingId);
      if (mounted) setState(() => _p = p);
    } catch (e) {
      showApiError(e, title: 'Gagal memuat packing');
    }
  }

  Future<void> _run(Future<Packing> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final p = await action();
      if (mounted) setState(() => _p = p);
      if (success != null) showSuccess('Packing', success);
    } catch (e) {
      showApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onScan(String code) async {
    final p = _p;
    if (p == null || !p.isOpen || _busy) return;
    setState(() => _busy = true);
    try {
      final (updated, last) = await _repo.scanToCarton(p.id, code, quantity: _qtyPerScan);
      ScanFeedback.success();
      if (mounted) {
        setState(() {
          _p = updated;
          _lastOk = true;
          _lastScan = last == null ? 'Tersimpan' : '+${last['quantity']} ${last['unit']} ${last['productName']} → ${last['cartonCode']}';
          _qtyPerScan = 1;
        });
      }
    } catch (e) {
      ScanFeedback.error();
      if (mounted) {
        setState(() {
          _lastOk = false;
          _lastScan = e is ApiException ? e.message : '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _weight(Carton c) async {
    final field = TextEditingController(text: c.weightKg == null ? '' : '${c.weightKg}');
    final value = await Get.dialog<double>(AlertDialog(
      title: Text('Berat koli ${c.seq}'),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: 'kg'),
        onSubmitted: (v) => Get.back(result: double.tryParse(v.replaceAll(',', '.'))),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: double.tryParse(field.text.replaceAll(',', '.'))), child: const Text('Simpan')),
      ],
    ));
    if (value != null) await _run(() => _repo.updateCarton(_p!.id, c.id, weightKg: value));
  }

  Future<void> _complete() async {
    final p = _p!;
    if (!await confirmAction(
      title: 'Selesai packing?',
      message: '${p.totalPacked} unit dalam ${p.totalCartons} koli untuk ${p.destination}. Setelah selesai, koli siap dimuat ke kendaraan.',
      confirmLabel: 'Selesai',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final done = await _repo.completePacking(p.id);
      ScanFeedback.success();
      if (!mounted) return;
      setState(() => _p = done);
      showSuccess('Packing selesai', '${done.number}: ${done.totalCartons} koli siap dimuat.');
      final cartons = done.cartons.where((c) => c.totalQuantity > 0).map((c) => ('CARTON', c.code)).toList();
      if (cartons.isNotEmpty) await printFromBackend(cartons, title: 'Cetak label koli');
      if (mounted) Get.back();
    } catch (e) {
      showApiError(e, title: 'Belum bisa diselesaikan');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(p == null ? 'Packing' : 'Packing ${p.reference}', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (p != null && p.isOpen)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'cancel' &&
                    await confirmAction(title: 'Batalkan packing?', message: 'Isi koli dihapus dan pengeluaran kembali ke antrean packing.', danger: true, confirmLabel: 'Batalkan')) {
                  await _run(() => _repo.cancelPacking(p.id));
                  if (mounted) Get.back();
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Batalkan packing'))],
            ),
        ],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Text('${p.destination} • ${p.issuingNumber} • ${p.number}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (p.isOpen) ...[
                    ScanPromptCard(
                      title: 'Scan barang / batch ke koli',
                      subtitle: p.currentCarton == null ? 'Koli baru dibuat otomatis' : 'Koli aktif: ${p.currentCarton!.code} (koli ${p.currentCarton!.seq})',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                    const SizedBox(height: 8),
                    QtyStepper(label: 'Qty per scan', value: _qtyPerScan, min: 1, onChanged: (v) => setState(() => _qtyPerScan = v)),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _run(() => _repo.newCarton(p.id), success: 'Koli baru dibuat'),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Tutup koli ini & buka koli baru'),
                      ),
                    ),
                    if (_lastScan != null) _LastScanBanner(text: _lastScan!, ok: _lastOk),
                  ] else
                    ScanPromptCard(title: p.statusLabel, done: true, doneText: '${p.statusLabel} • ${p.totalCartons} koli'),
                  const SizedBox(height: 12),
                  _ProgressPanel(packing: p),
                  const SizedBox(height: 12),
                  for (final c in p.cartons.reversed) _CartonCard(
                    carton: c,
                    editable: p.isOpen,
                    onWeight: () => _weight(c),
                    onPrint: () => printFromBackend([('CARTON', c.code)], title: 'Label ${c.code}'),
                    onToggle: () => _run(() => _repo.updateCarton(p.id, c.id, status: c.isOpen ? 'CLOSED' : 'OPEN')),
                    onRemove: (item) async {
                      if (await confirmAction(title: 'Hapus dari koli?', message: '${item.quantity} ${item.unit} ${item.productName}', danger: true, confirmLabel: 'Hapus')) {
                        await _run(() => _repo.removeItem(p.id, item.id));
                      }
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: p == null || !p.isOpen
          ? null
          : BottomActionBar(
              label: p.complete ? 'Selesai Packing (${p.totalCartons} koli)' : 'Sisa ${p.totalRemaining} unit belum dikemas',
              icon: Icons.inventory_rounded,
              busy: _busy,
              onPressed: p.complete ? _complete : null,
            ),
    );
  }
}

class _LastScanBanner extends StatelessWidget {
  const _LastScanBanner({required this.text, required this.ok});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFE8F7EF) : const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? AppColors.success : AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ok ? AppColors.success : AppColors.danger))),
        ]),
      );
}

/// Rencana packing per produk x batch (hasil picking FEFO).
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.packing});
  final Packing packing;

  @override
  Widget build(BuildContext context) {
    final p = packing;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          const Expanded(child: Text('Barang hasil picking', style: TextStyle(fontWeight: FontWeight.w900))),
          Text('${p.totalPacked} / ${p.totalPicked}', style: TextStyle(fontWeight: FontWeight.w900, color: p.complete ? AppColors.success : AppColors.charcoal)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p.totalPicked == 0 ? 0 : p.totalPacked / p.totalPicked,
            minHeight: 8,
            color: p.complete ? AppColors.success : AppColors.warning,
            backgroundColor: AppColors.border,
          ),
        ),
        const Divider(height: 18),
        for (final l in p.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(l.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: l.done ? AppColors.success : Colors.black38),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('${l.sku} • batch ${l.batchNumber ?? '-'}${l.expiryDate != null ? ' • ED ${formatDate(l.expiryDate)}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ),
              const SizedBox(width: 6),
              Text('${l.packedQuantity} / ${l.pickedQuantity} ${l.unit}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: l.done ? AppColors.success : AppColors.charcoal)),
            ]),
          ),
      ]),
    );
  }
}

class _CartonCard extends StatelessWidget {
  const _CartonCard({required this.carton, required this.editable, required this.onWeight, required this.onPrint, required this.onToggle, required this.onRemove});
  final Carton carton;
  final bool editable;
  final VoidCallback onWeight, onPrint, onToggle;
  final ValueChanged<CartonItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = carton;
    final color = c.isOpen ? AppColors.primary : AppColors.success;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.isOpen && editable ? AppColors.primary : AppColors.border, width: c.isOpen && editable ? 1.6 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.inventory_2_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Koli ${c.seq} • ${c.code}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${c.totalQuantity} unit${c.weightKg != null ? ' • ${c.weightKg} kg' : ''}${c.loaded ? ' • sudah dimuat' : ''}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
            AppStatusBadge(label: c.isOpen ? 'Terbuka' : 'Ditutup', color: color),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) { 'weight' => onWeight(), 'print' => onPrint(), _ => onToggle() },
              itemBuilder: (_) => [
                if (!c.loaded) const PopupMenuItem(value: 'weight', child: Text('Isi berat')),
                if (c.totalQuantity > 0) const PopupMenuItem(value: 'print', child: Text('Cetak label koli')),
                if (editable) PopupMenuItem(value: 'toggle', child: Text(c.isOpen ? 'Tutup koli' : 'Buka kembali')),
              ],
            ),
          ]),
          if (c.items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 6, left: 28), child: Text('Kosong — scan barang untuk mengisi koli ini.', style: TextStyle(fontSize: 11, color: Colors.black45)))
          else
            for (final i in c.items)
              InkWell(
                onLongPress: editable ? () => onRemove(i) : null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 28, right: 8),
                  child: Row(children: [
                    Expanded(
                      child: Text('${i.productName} • ${i.batchNumber ?? i.sku}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ),
                    Text('${i.quantity} ${i.unit}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ),
          if (editable && c.items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 28),
              child: Text('Tekan lama baris untuk menghapus dari koli.', style: TextStyle(fontSize: 10, color: Colors.black38)),
            ),
        ]),
      ),
    );
  }
}
