import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../data/models/erp_document_models.dart';
import '../../data/models/inventory_models.dart' show formatDate;
import '../../data/repositories/erp_document_repository.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/warehouse_context.dart';
import '../../services/scanner/scanner_service.dart';
import '../helpers/api_feedback.dart';
import 'app_status_badge.dart';
import 'scan_widgets.dart';

/// Langkah 1 Tally / Picking: scan nomor dokumen (PO / SO) atau pilih dari daftar dokumen terbuka
/// di gudang aktif. [onOpen] membuka layar proses; daftar dimuat ulang setelah kembali.
class ErpDocumentPickerPage extends StatefulWidget {
  const ErpDocumentPickerPage({super.key, required this.kind, required this.onOpen});
  final ErpDocKind kind;
  final Future<void> Function(ErpDocument doc) onOpen;

  @override
  State<ErpDocumentPickerPage> createState() => _ErpDocumentPickerPageState();
}

class _ErpDocumentPickerPageState extends State<ErpDocumentPickerPage> {
  final _repo = ErpDocumentRepository.instance;
  final _search = TextEditingController();
  List<ErpDocument> _docs = [];
  bool _loading = true;
  bool _opening = false;
  String? _error;
  ScanRegistration? _scan;

  bool get isIn => widget.kind == ErpDocKind.inbound;
  String get _warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void initState() {
    super.initState();
    _scan = ScannerService.instance.register(_onScan, label: isIn ? 'Scan dokumen PO' : 'Scan dokumen SO');
    _load();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await _repo.openDocuments(widget.kind, warehouseId: _warehouseId, search: _search.text.trim());
      if (mounted) setState(() => _docs = docs);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onScan(String code) => _open(code);

  /// Selalu ambil detail terbaru (sisa qty bisa berubah oleh petugas lain).
  Future<void> _open(String code) async {
    if (_opening) return;
    _opening = true;
    try {
      final doc = await _repo.find(widget.kind, code);
      if (doc.warehouseId != _warehouseId) {
        ScanFeedback.error();
        Get.snackbar('Gudang berbeda', '${doc.displayNumber} untuk gudang lain. Ganti gudang aktif terlebih dahulu.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (!doc.isOpen) {
        ScanFeedback.error();
        Get.snackbar('Dokumen ${doc.statusLabel}', '${doc.displayNumber} sudah ${doc.statusLabel.toLowerCase()} dan tidak dapat diproses lagi.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      ScanFeedback.success();
      await widget.onOpen(doc);
      await _load();
    } on ApiException catch (e) {
      ScanFeedback.error();
      showApiError(e, title: e.statusCode == 404 ? 'Dokumen tidak ditemukan' : 'Tidak dapat dibuka');
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(isIn ? 'Terima dari PO (Tally)' : 'Keluarkan dari SO (Picking)', style: const TextStyle(fontWeight: FontWeight.w700))),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              ScanPromptCard(
                title: isIn ? 'Scan nomor PO / dokumen inbound' : 'Scan nomor SO / dokumen outbound',
                subtitle: 'atau pilih dari daftar di bawah',
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari nomor, ${widget.kind.partyLabel.toLowerCase()}, SKU',
                  suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward_rounded)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Dokumen terbuka • ${WarehouseContext.instance.activeName}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (_loading && _docs.isEmpty)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                EmptyState(message: _error!, icon: Icons.cloud_off_rounded)
              else if (_docs.isEmpty)
                EmptyState(
                  message: isIn ? 'Tidak ada PO terbuka untuk gudang ini.' : 'Tidak ada SO terbuka untuk gudang ini.',
                  icon: Icons.inbox_outlined,
                )
              else
                ..._docs.map((d) => ErpDocumentCard(document: d, onTap: () => _open(d.id))),
            ],
          ),
        ),
      );
}

/// Kartu dokumen: nomor, pihak, tanggal, progres pemenuhan.
class ErpDocumentCard extends StatelessWidget {
  const ErpDocumentCard({super.key, required this.document, this.onTap});
  final ErpDocument document;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = document;
    final pct = (d.percentage / 100).clamp(0.0, 1.0);
    final color = d.percentage >= 100 ? AppColors.success : (d.percentage > 0 ? AppColors.warning : AppColors.info);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(d.displayNumber, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              const SizedBox(width: 6),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: AppStatusBadge(label: d.statusLabel, color: color))),
            ]),
            const SizedBox(height: 2),
            Text(
              [if (d.partyName.isNotEmpty) d.partyName, if (d.erpDocumentNo != null) d.number, if (d.source == 'MANUAL') 'Manual'].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct, minHeight: 8, color: color, backgroundColor: AppColors.border),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('${d.lines.length} item • ${d.totalProcessed} / ${d.totalOrdered} ${d.kind.processedLabel}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  d.expectedDate != null ? 'Rencana ${formatDate(d.expectedDate)}' : (d.documentDate != null ? formatDate(d.documentDate) : ''),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Ringkasan sisa dokumen per item vs qty yang sedang dihitung di layar.
class ErpDocumentProgress extends StatelessWidget {
  const ErpDocumentProgress({super.key, required this.document, required this.countedFor});
  final ErpDocument document;

  /// Qty (unit dasar) yang sedang dihitung untuk produk ini di layar.
  final int Function(String productId) countedFor;

  @override
  Widget build(BuildContext context) {
    final d = document;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('${d.kind.erpLabel} ${d.displayNumber}', style: const TextStyle(fontWeight: FontWeight.w900))),
        ]),
        if (d.partyName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${d.kind.partyLabel}: ${d.partyName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        const Divider(height: 16),
        for (final l in d.lines) _line(l),
      ]),
    );
  }

  Widget _line(ErpDocLine l) {
    final counted = countedFor(l.productId);
    final room = document.availableFor(l.productId);
    final over = counted > room;
    final done = counted > 0 && counted == room;
    final color = over ? AppColors.danger : (done ? AppColors.success : AppColors.charcoal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(over ? Icons.error_rounded : (done ? Icons.check_circle_rounded : Icons.radio_button_unchecked), size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${l.sku} • dokumen ${l.orderedQuantity}, sudah ${l.processedQuantity}${l.pendingQuantity > 0 ? ', pending ${l.pendingQuantity}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text('$counted / $room ${l.unit}', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ),
      ]),
    );
  }
}
