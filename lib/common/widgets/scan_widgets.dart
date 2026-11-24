import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../data/models/inventory_models.dart';
import '../../services/scanner/scanner_service.dart';

/// Kartu besar ajakan scan. Tombol "Ketik manual" untuk perangkat tanpa
/// scanner fisik / barcode rusak; hasilnya diproses sama seperti scan.
class ScanPromptCard extends StatelessWidget {
  const ScanPromptCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.qr_code_scanner_rounded,
    this.done = false,
    this.doneText,
    this.onReset,
  });

  final String title;
  final String? subtitle, doneText;
  final IconData icon;
  final bool done;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8F7EF) : AppColors.softOrange,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .45), width: 1.4),
      ),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(done ? (doneText ?? title) : title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: done ? AppColors.success : AppColors.charcoal)),
            if (subtitle != null && !done) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ]),
        ),
        if (done && onReset != null)
          IconButton(tooltip: 'Ganti', onPressed: onReset, icon: const Icon(Icons.refresh_rounded))
        else
          TextButton(
            onPressed: () => showManualScanDialog(title: title),
            child: const Text('Ketik\nmanual', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
          ),
      ]),
    );
  }
}

/// Dialog input barcode manual. Nilai dikirim ke handler scan halaman aktif.
Future<void> showManualScanDialog({String title = 'Input barcode'}) async {
  final field = TextEditingController();
  final value = await Get.dialog<String>(AlertDialog(
    title: Text(title, style: const TextStyle(fontSize: 16)),
    content: TextField(
      controller: field,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (v) => Get.back(result: v),
      decoration: const InputDecoration(labelText: 'Barcode / kode', border: OutlineInputBorder()),
    ),
    actions: [
      TextButton(onPressed: Get.back, child: const Text('Batal')),
      FilledButton(onPressed: () => Get.back(result: field.text), child: const Text('Proses')),
    ],
  ));
  if (value != null && value.trim().isNotEmpty) ScannerService.instance.simulate(value.trim());
}

/// Stepper qty berukuran besar (satu tangan). Angka bisa diketuk untuk diketik.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max, this.label, this.unit});

  final int value, min;
  final int? max;
  final String? label, unit;
  final ValueChanged<int> onChanged;

  void _set(int v) {
    final upper = max ?? 999999;
    onChanged(v.clamp(min, upper));
  }

  Future<void> _type() async {
    final field = TextEditingController(text: '$value');
    final result = await Get.dialog<int>(AlertDialog(
      title: Text(label ?? 'Jumlah'),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(border: const OutlineInputBorder(), suffixText: unit, helperText: max == null ? null : 'Maksimal $max'),
        onSubmitted: (v) => Get.back(result: int.tryParse(v)),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        FilledButton(onPressed: () => Get.back(result: int.tryParse(field.text)), child: const Text('OK')),
      ],
    ));
    if (result != null) _set(result);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label != null) ...[
      Text(label!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
      const SizedBox(height: 6),
    ],
    Row(children: [
      _StepButton(icon: Icons.remove_rounded, onTap: value > min ? () => _set(value - 1) : null),
      const SizedBox(width: 8),
      Expanded(
        child: InkWell(
          onTap: _type,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12), color: Colors.white),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$value${unit == null ? '' : ' $unit'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      _StepButton(icon: Icons.add_rounded, onTap: max == null || value < max! ? () => _set(value + 1) : null),
    ]),
    if (max != null)
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Text('Maksimal $max${unit == null ? '' : ' $unit'}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const Spacer(),
          if (value != max) GestureDetector(onTap: () => _set(max!), child: const Text('Isi semua', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700))),
        ]),
      ),
  ]);
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 52,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Icon(icon, size: 26),
    ),
  );
}

/// Label status stok berwarna.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = InventoryStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(InventoryStatus.shortLabel(status), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

/// Kartu saldo batch: produk, batch, expiry, lokasi, status, qty.
class BalanceTile extends StatelessWidget {
  const BalanceTile({super.key, required this.balance, this.onTap, this.selected = false, this.trailing});

  final InventoryBalance balance;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final b = balance;
    return Material(
      color: selected ? AppColors.softOrange : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(b.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              const SizedBox(width: 6),
              StatusPill(b.status),
            ]),
            const SizedBox(height: 5),
            Wrap(spacing: 10, runSpacing: 3, children: [
              _Meta(Icons.qr_code_2_rounded, b.batchNumber),
              _Meta(Icons.location_on_outlined, b.locationCode),
              if (b.expiryDate != null)
                _Meta(Icons.event_outlined, 'ED ${formatDate(b.expiryDate)}${b.isExpired ? ' (EXPIRED)' : ''}', color: b.isExpired ? AppColors.danger : null),
              if (b.supplierLot != null) _Meta(Icons.tag_rounded, 'Lot ${b.supplierLot}'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Text('${b.quantity} ${b.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              const Spacer(),
              ?trailing,
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color ?? Colors.black45),
    const SizedBox(width: 3),
    Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: color ?? Colors.black54, fontWeight: color == null ? FontWeight.w500 : FontWeight.w700))),
  ]);
}

/// Baris label : nilai.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});
  final String label, value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
      const Text(':  ', style: TextStyle(fontSize: 11)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 11.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
    ]),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(children: [
      Icon(icon, size: 42, color: Colors.black26),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    ]),
  );
}

/// Dialog konfirmasi untuk transaksi penting. Mengembalikan true jika disetujui.
Future<bool> confirmAction({required String title, required String message, String confirmLabel = 'Ya, Proses', bool danger = false}) async {
  final result = await Get.dialog<bool>(AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Batal')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.danger : AppColors.primary),
        onPressed: () => Get.back(result: true),
        child: Text(confirmLabel),
      ),
    ],
  ));
  return result == true;
}

/// Tombol aksi utama lebar penuh di bagian bawah layar.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.label, required this.onPressed, this.busy = false, this.icon = Icons.check_rounded});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: busy ? null : onPressed,
          icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon),
          label: Text(busy ? 'Memproses...' : label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    ),
  );
}
