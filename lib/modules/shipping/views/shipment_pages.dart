import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart' show formatDate;
import '../../../data/models/shipping_models.dart';
import '../../../data/repositories/shipping_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';

Color shipmentStatusColor(String s) => switch (s) {
      'PLANNED' => AppColors.info,
      'LOADING' => AppColors.warning,
      'DISPATCHED' => const Color(0xFF6B4FBB),
      'DELIVERED' => AppColors.success,
      _ => AppColors.danger,
    };

/// Daftar shipment: sedang dimuat / dalam perjalanan, plus packing yang siap dimuat.
/// Scan label koli di layar ini langsung membuka shipment yang memuat koli tersebut (bila ada).
class ShipmentListPage extends StatefulWidget {
  const ShipmentListPage({super.key});

  @override
  State<ShipmentListPage> createState() => _ShipmentListPageState();
}

class _ShipmentListPageState extends State<ShipmentListPage> {
  final _repo = ShippingRepository.instance;
  int _tab = 0;
  List<Shipment> _active = [], _transit = [];
  List<Packing> _ready = [];
  bool _loading = true;
  String? _error;
  ScanRegistration? _scan;

  String get _wh => WarehouseContext.instance.activeId.value;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Scan nomor shipment');
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
      final r = await Future.wait([_repo.shipments(_wh), _repo.shipments(_wh, status: 'DISPATCHED'), _repo.readyPackings(_wh)]);
      if (mounted) {
        setState(() {
          _active = r[0] as List<Shipment>;
          _transit = r[1] as List<Shipment>;
          _ready = r[2] as List<Packing>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onScan(String code) async {
    try {
      final s = await _repo.shipment(code);
      ScanFeedback.success();
      await _open(s);
    } catch (e) {
      ScanFeedback.error();
      showApiError(e, title: 'Shipment tidak ditemukan');
    }
  }

  Future<void> _open(Shipment s) async {
    await Get.to(() => LoadingPage(shipmentId: s.id));
    await _load();
  }

  Future<void> _create() async {
    final created = await Get.to<Shipment>(() => ShipmentFormPage(readyPackings: _ready));
    if (created != null) await _open(created);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _active : _transit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Loading & Dispatch', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Shipment baru'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            _ReadyBanner(count: _ready.length, cartons: _ready.fold(0, (s, p) => s + p.totalCartons), onCreate: _create),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text('Dimuat (${_active.length})')),
                ButtonSegment(value: 1, label: Text('Dikirim (${_transit.length})')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 12),
            if (_loading && _active.isEmpty && _transit.isEmpty)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              EmptyState(message: _error!, icon: Icons.cloud_off_rounded)
            else if (list.isEmpty)
              EmptyState(
                message: _tab == 0 ? 'Belum ada shipment yang sedang dimuat.\nTekan "Shipment baru" untuk memulai loading.' : 'Tidak ada shipment dalam perjalanan.',
                icon: Icons.local_shipping_outlined,
              )
            else
              for (final s in list) ShipmentCard(shipment: s, onTap: () => _open(s)),
          ],
        ),
      ),
    );
  }
}

class _ReadyBanner extends StatelessWidget {
  const _ReadyBanner({required this.count, required this.cartons, required this.onCreate});
  final int count, cartons;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: count > 0 ? AppColors.softOrange : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: count > 0 ? AppColors.primary.withValues(alpha: .4) : AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.inventory_rounded, color: count > 0 ? AppColors.primary : Colors.black38, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$count packing siap dimuat', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text(count > 0 ? '$cartons koli menunggu kendaraan' : 'Selesaikan packing terlebih dahulu', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ]),
      );
}

class ShipmentCard extends StatelessWidget {
  const ShipmentCard({super.key, required this.shipment, this.onTap});
  final Shipment shipment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final color = shipmentStatusColor(s.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.number, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              AppStatusBadge(label: s.statusLabel, color: color),
            ]),
            const SizedBox(height: 2),
            Text([if (s.vehicleLabel.isNotEmpty) s.vehicleLabel, if (s.driverName.isNotEmpty) s.driverName, if (s.carrier.isNotEmpty) s.carrier].join(' • '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (s.destinations.isNotEmpty)
              Text('Tujuan: ${s.destinations.join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: s.totalCartons == 0 ? 0 : s.loadedCartons / s.totalCartons,
                minHeight: 8,
                color: s.allLoaded ? AppColors.success : AppColors.warning,
                backgroundColor: AppColors.border,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('${s.loadedCartons} / ${s.totalCartons} koli dimuat • ${s.totalPackings} SO',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Text(s.dispatchedAt != null ? 'Berangkat ${formatDate(s.dispatchedAt)}' : (s.plannedDate != null ? formatDate(s.plannedDate) : ''),
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================================
/// Form shipment baru: data kendaraan & sopir, opsional pilih packing yang akan dimuat.
class ShipmentFormPage extends StatefulWidget {
  const ShipmentFormPage({super.key, this.readyPackings = const []});
  final List<Packing> readyPackings;

  @override
  State<ShipmentFormPage> createState() => _ShipmentFormPageState();
}

class _ShipmentFormPageState extends State<ShipmentFormPage> {
  final _form = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _type = TextEditingController();
  final _driver = TextEditingController();
  final _phone = TextEditingController();
  final _carrier = TextEditingController(text: 'Armada sendiri');
  final _dock = TextEditingController();
  final _notes = TextEditingController();
  final _selected = <String>{};
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_plate, _type, _driver, _phone, _carrier, _dock, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final s = await ShippingRepository.instance.createShipment({
        'warehouseId': WarehouseContext.instance.activeId.value,
        'plannedDate': ApiClient.formatDate(_date),
        'vehiclePlate': _plate.text.trim(),
        'vehicleType': _type.text.trim(),
        'driverName': _driver.text.trim(),
        'driverPhone': _phone.text.trim(),
        'carrier': _carrier.text.trim(),
        'dock': _dock.text.trim(),
        'notes': _notes.text.trim(),
        'packingIds': _selected.toList(),
      });
      showSuccess('Shipment dibuat', '${s.number}. Scan label koli saat dimuat.');
      Get.back(result: s);
    } catch (e) {
      showApiError(e, title: 'Shipment gagal dibuat');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true, prefixIcon: icon == null ? null : Icon(icon));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Shipment baru', style: TextStyle(fontWeight: FontWeight.w700))),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), children: [
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('No. polisi kendaraan *', hint: 'L 1234 AB', icon: Icons.local_shipping_outlined),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _type, decoration: _dec('Jenis kendaraan', hint: 'CDD Box / Pickup / Wingbox')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _driver,
              decoration: _dec('Nama sopir *', icon: Icons.person_outline),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec('No. HP sopir', icon: Icons.phone_outlined)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _carrier, decoration: _dec('Ekspedisi'))),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: TextFormField(controller: _dock, decoration: _dec('Dock', hint: 'D1'))),
            ]),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Tanggal kirim'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 7)), lastDate: DateTime.now().add(const Duration(days: 60)));
                if (d != null) setState(() => _date = d);
              },
            ),
            TextFormField(controller: _notes, maxLines: 2, decoration: _dec('Catatan')),
            const SizedBox(height: 16),
            Text('Packing siap dimuat (${widget.readyPackings.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text('Opsional — packing juga otomatis masuk saat label kolinya di-scan.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 6),
            if (widget.readyPackings.isEmpty)
              const EmptyState(message: 'Belum ada packing yang selesai.', icon: Icons.inventory_2_outlined)
            else
              for (final p in widget.readyPackings)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(p.id),
                  onChanged: (v) => setState(() => v == true ? _selected.add(p.id) : _selected.remove(p.id)),
                  title: Text('${p.reference} • ${p.destination}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p.number} • ${p.totalCartons} koli • ${p.totalPacked} unit${p.totalWeightKg > 0 ? ' • ${p.totalWeightKg} kg' : ''}'),
                ),
          ]),
        ),
        bottomNavigationBar: BottomActionBar(label: 'Buat Shipment & Mulai Muat', icon: Icons.local_shipping_rounded, busy: _busy, onPressed: _save),
      );
}

// =====================================================================================
/// Loading: scan label koli ke kendaraan; dispatch bila semua koli sudah dimuat; POD setelah dikirim.
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key, required this.shipmentId});
  final String shipmentId;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final _repo = ShippingRepository.instance;
  Shipment? _s;
  bool _busy = false;
  String? _last;
  bool _lastOk = true;
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: 'Scan label koli');
    _load();
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.shipment(widget.shipmentId);
      if (mounted) setState(() => _s = s);
    } catch (e) {
      showApiError(e, title: 'Gagal memuat shipment');
    }
  }

  Future<void> _run(Future<Shipment> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await action();
      if (mounted) setState(() => _s = s);
      if (success != null) showSuccess(s.number, success);
    } catch (e) {
      showApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onScan(String code) async {
    final s = _s;
    if (s == null || !s.editable || _busy) return;
    setState(() => _busy = true);
    try {
      final (updated, last) = await _repo.loadCarton(s.id, code);
      ScanFeedback.success();
      if (mounted) {
        setState(() {
          _s = updated;
          _lastOk = true;
          _last = 'Koli ${last?['cartonCode'] ?? code} dimuat • ${updated.loadedCartons}/${updated.totalCartons}';
        });
      }
    } catch (e) {
      ScanFeedback.error();
      if (mounted) {
        setState(() {
          _lastOk = false;
          _last = e is ApiException ? e.message : '$e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPacking() async {
    final s = _s!;
    final ready = await _repo.readyPackings(s.warehouseId).catchError((Object e) {
      showApiError(e);
      return <Packing>[];
    });
    if (ready.isEmpty) {
      showSuccess('Tidak ada packing', 'Belum ada packing selesai yang siap dimuat.');
      return;
    }
    final picked = await Get.bottomSheet<Packing>(
      Container(
        color: Colors.white,
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
            const Padding(padding: EdgeInsets.all(8), child: Text('Tambah packing ke shipment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            for (final p in ready)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${p.reference} • ${p.destination}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${p.number} • ${p.totalCartons} koli'),
                onTap: () => Get.back(result: p),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) await _run(() => _repo.addPacking(s.id, picked.id), success: '${picked.number} ditambahkan. Scan kolinya saat dimuat.');
  }

  Future<void> _dispatch() async {
    final s = _s!;
    final seal = TextEditingController(text: s.sealNumber ?? '');
    final go = await Get.dialog<bool>(AlertDialog(
      title: const Text('Berangkatkan kendaraan?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s.totalCartons} koli • ${s.totalQuantity} unit\n${s.vehicleLabel} • ${s.driverName}\nTujuan: ${s.destinations.join(', ')}'),
        const SizedBox(height: 12),
        TextField(controller: seal, decoration: const InputDecoration(labelText: 'No. segel (opsional)', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 8),
        const Text('Goods Issue dikirim ke ERP saat dispatch.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('Dispatch')),
      ],
    ));
    if (go != true) return;
    await _run(() => _repo.dispatch(s.id, sealNumber: seal.text.trim().isEmpty ? null : seal.text.trim()),
        success: 'Kendaraan berangkat. Goods Issue dikirim ke ERP.');
  }

  Future<void> _deliver() async {
    final s = _s!;
    final name = TextEditingController();
    final notes = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Konfirmasi diterima (POD)'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nama penerima *', border: OutlineInputBorder(), isDense: true)),
        const SizedBox(height: 10),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder(), isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: name.text.trim().isNotEmpty), child: const Text('Simpan POD')),
      ],
    ));
    if (ok == true) await _run(() => _repo.deliver(s.id, receiverName: name.text.trim(), notes: notes.text.trim()), success: 'Diterima oleh ${name.text.trim()}.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s?.number ?? 'Shipment', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (s != null && s.editable)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'add') await _addPacking();
                if (v == 'cancel' &&
                    await confirmAction(title: 'Batalkan shipment?', message: 'Semua koli dibongkar dan packing kembali siap dimuat.', danger: true, confirmLabel: 'Batalkan')) {
                  await _run(() => _repo.cancelShipment(s.id));
                  if (mounted) Get.back();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'add', child: Text('Tambah packing')),
                PopupMenuItem(value: 'cancel', child: Text('Batalkan shipment')),
              ],
            ),
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _VehicleCard(shipment: s),
                  const SizedBox(height: 10),
                  if (s.editable) ...[
                    const ScanPromptCard(title: 'Scan label koli (CTN)', subtitle: 'saat koli dinaikkan ke kendaraan', icon: Icons.local_shipping_outlined),
                    if (_last != null) _Banner(text: _last!, ok: _lastOk),
                  ] else
                    ScanPromptCard(
                      title: s.statusLabel,
                      done: true,
                      doneText: s.status == 'DELIVERED'
                          ? 'Diterima ${s.receiverName ?? ''} • ${formatDate(s.deliveredAt)}'
                          : 'Berangkat ${formatDate(s.dispatchedAt)}${s.sealNumber != null ? ' • segel ${s.sealNumber}' : ''}',
                    ),
                  const SizedBox(height: 12),
                  _LoadProgress(shipment: s),
                  const SizedBox(height: 12),
                  if (s.packings.isEmpty)
                    const EmptyState(message: 'Belum ada koli. Scan label koli pertama — packing-nya otomatis masuk shipment ini.', icon: Icons.qr_code_scanner_rounded)
                  else
                    for (final p in s.packings)
                      _PackingLoadCard(
                        packing: p,
                        editable: s.editable,
                        onRemove: () async {
                          if (await confirmAction(title: 'Keluarkan ${p.number}?', message: 'Koli ${p.reference} dibongkar dari kendaraan.', danger: true, confirmLabel: 'Keluarkan')) {
                            await _run(() => _repo.removePacking(s.id, p.id));
                          }
                        },
                        onUnload: (c) async {
                          if (await confirmAction(title: 'Bongkar koli?', message: '${c.code} diturunkan dari kendaraan.', confirmLabel: 'Bongkar')) {
                            await _run(() => _repo.unloadCarton(s.id, c.code));
                          }
                        },
                      ),
                ],
              ),
            ),
      bottomNavigationBar: s == null
          ? null
          : s.editable
              ? BottomActionBar(
                  label: s.allLoaded ? 'Dispatch • ${s.totalCartons} koli' : 'Muat ${s.totalCartons - s.loadedCartons} koli lagi',
                  icon: Icons.local_shipping_rounded,
                  busy: _busy,
                  onPressed: s.allLoaded ? _dispatch : null,
                )
              : s.status == 'DISPATCHED'
                  ? BottomActionBar(label: 'Konfirmasi Diterima (POD)', icon: Icons.assignment_turned_in_outlined, busy: _busy, onPressed: _deliver)
                  : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.ok});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: ok ? const Color(0xFFE8F7EF) : const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? AppColors.success : AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ok ? AppColors.success : AppColors.danger))),
        ]),
      );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.shipment});
  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.vehicleLabel.isEmpty ? '-' : s.vehicleLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text([if (s.driverName.isNotEmpty) s.driverName, if (s.driverPhone.isNotEmpty) s.driverPhone].join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text([if (s.carrier.isNotEmpty) s.carrier, if (s.dock.isNotEmpty) 'Dock ${s.dock}', if (s.plannedDate != null) formatDate(s.plannedDate)].join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            // Badge di bawah teks agar no. polisi tidak terpotong di layar sempit.
            AppStatusBadge(label: s.statusLabel, color: shipmentStatusColor(s.status)),
          ]),
        ),
      ]),
    );
  }
}

class _LoadProgress extends StatelessWidget {
  const _LoadProgress({required this.shipment});
  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    final pct = s.totalCartons == 0 ? 0.0 : s.loadedCartons / s.totalCartons;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Angka besar mengecil otomatis di layar sempit / font besar agar tidak meluap.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${s.loadedCartons}',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: s.allLoaded ? AppColors.success : AppColors.darkOrange, height: 1)),
                Text(' / ${s.totalCartons} koli', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${s.totalQuantity} unit', style: const TextStyle(fontWeight: FontWeight.w800)),
            if (s.totalWeightKg > 0) Text('${s.totalWeightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, minHeight: 10, color: s.allLoaded ? AppColors.success : AppColors.warning, backgroundColor: AppColors.border),
        ),
      ]),
    );
  }
}

class _PackingLoadCard extends StatelessWidget {
  const _PackingLoadCard({required this.packing, required this.editable, required this.onRemove, required this.onUnload});
  final Packing packing;
  final bool editable;
  final VoidCallback onRemove;
  final ValueChanged<Carton> onUnload;

  @override
  Widget build(BuildContext context) {
    final p = packing;
    final cartons = p.cartons.where((c) => c.totalQuantity > 0).toList();
    final done = cartons.isNotEmpty && cartons.every((c) => c.loaded);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(done ? Icons.check_circle_rounded : Icons.pending_outlined, color: done ? AppColors.success : AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.reference} • ${p.destination}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${p.number} • ${p.issuingNumber} • ${p.totalPacked} unit', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
            if (editable) IconButton(tooltip: 'Keluarkan dari shipment', onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline, color: Colors.black45)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in cartons)
              InkWell(
                onTap: editable && c.loaded ? () => onUnload(c) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.loaded ? const Color(0xFFE8F7EF) : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.loaded ? AppColors.success : AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(c.loaded ? Icons.check_rounded : Icons.inventory_2_outlined, size: 14, color: c.loaded ? AppColors.success : Colors.black45),
                    const SizedBox(width: 4),
                    Text('${c.seq}: ${c.code}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.loaded ? AppColors.success : AppColors.charcoal)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
