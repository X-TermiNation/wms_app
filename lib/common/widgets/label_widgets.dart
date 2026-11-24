import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../common/helpers/api_feedback.dart';
import '../../data/models/inventory_models.dart';
import '../../data/repositories/receiving_repository.dart';
import '../../services/printing/label_printer.dart';
import '../../services/printing/printer_settings_page.dart';
import '../../services/scanner/scanner_service.dart';
import 'scan_widgets.dart';

/// Pratinjau label 50 x 30 mm seperti yang akan dicetak.
class LabelPreview extends StatelessWidget {
  const LabelPreview(this.label, {super.key});
  final LabelData label;

  @override
  Widget build(BuildContext context) {
    final ean = label.symbology == 'EAN13' && RegExp(r'^\d{13}$').hasMatch(label.code);
    return AspectRatio(
      aspectRatio: 50 / 30,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6)),
        child: Column(children: [
          Text(label.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 2),
          Expanded(
            child: BarcodeWidget(
              barcode: ean ? Barcode.ean13() : Barcode.code128(),
              data: label.code,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              errorBuilder: (_, e) => Center(child: Text(label.code, style: const TextStyle(fontWeight: FontWeight.w800))),
            ),
          ),
          for (final line in label.lines.take(3))
            Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5)),
        ]),
      ),
    );
  }
}

/// Lembar cetak: pratinjau, jumlah salinan, cetak / cetak ulang. Gagal cetak tidak membatalkan transaksi.
Future<void> showPrintSheet(List<LabelData> labels, {String title = 'Cetak Label', int copies = 1}) async {
  if (labels.isEmpty) return;
  await LabelPrinter.instance.load();
  await Get.bottomSheet(_PrintSheet(labels: labels, title: title, initialCopies: copies), isScrollControlled: true);
}

/// Ambil data label dari backend lalu buka lembar cetak. [items] = (type, code).
Future<void> printFromBackend(List<(String, String)> items, {String title = 'Cetak Label'}) async {
  try {
    final labels = <LabelData>[];
    for (final (type, code) in items) {
      labels.add(await ReceivingRepository.instance.label(type, code));
    }
    await showPrintSheet(labels, title: title);
  } catch (e) {
    showApiError(e, title: 'Label tidak dapat dimuat');
  }
}

class _PrintSheet extends StatefulWidget {
  const _PrintSheet({required this.labels, required this.title, required this.initialCopies});
  final List<LabelData> labels;
  final String title;
  final int initialCopies;

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  late int copies = widget.initialCopies;
  bool busy = false;
  PrintResult? last;

  Future<void> _print() async {
    setState(() => busy = true);
    final r = await LabelPrinter.instance.print(widget.labels, copies: copies);
    if (!mounted) return;
    setState(() {
      busy = false;
      last = r;
    });
    if (r.success) {
      ScanFeedback.success();
    } else {
      ScanFeedback.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = LabelPrinter.instance;
    return Container(
      constraints: BoxConstraints(maxHeight: Get.height * .9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.print_outlined, size: 16, color: printer.isConfigured ? AppColors.success : AppColors.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(printer.isConfigured ? (printer.name ?? printer.mac!) : 'Printer belum dipilih',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              onPressed: () async {
                await Get.to(() => const PrinterSettingsPage());
                if (mounted) setState(() {});
              },
              child: const Text('Pengaturan'),
            ),
          ]),
          const SizedBox(height: 6),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.labels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => Center(child: SizedBox(width: 260, child: LabelPreview(widget.labels[i]))),
            ),
          ),
          const SizedBox(height: 10),
          QtyStepper(label: 'Salinan per label', value: copies, min: 1, max: 50, onChanged: (v) => setState(() => copies = v)),
          if (last != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (last!.success ? AppColors.success : AppColors.danger).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                last!.success ? last!.message : '${last!.message}\nTransaksi tetap tersimpan. Label bisa dicetak ulang kapan saja.',
                style: TextStyle(fontSize: 12, color: last!.success ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: SizedBox(height: 52, child: OutlinedButton(onPressed: busy ? null : Get.back, child: const Text('Selesai')))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: busy ? null : _print,
                  icon: const Icon(Icons.print_rounded),
                  label: Text(busy ? 'Mencetak...' : (last == null ? 'Cetak' : 'Cetak Ulang'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
