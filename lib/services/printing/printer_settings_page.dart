import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import 'label_printer.dart';

/// Pilih printer label Bluetooth (ESC/POS) yang sudah di-pair, atur lebar kertas & feed, tes cetak.
class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final printer = LabelPrinter.instance;
  List<PrinterDevice> devices = [];
  String? error;
  bool loading = true;
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    await printer.load();
    try {
      devices = await printer.pairedDevices();
    } on PrintResult catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Tidak dapat membaca perangkat Bluetooth: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _select(PrinterDevice d) async {
    await printer.save(mac: d.mac, name: d.name);
    setState(() => message = '${d.name} dipilih.');
  }

  Future<void> _test() async {
    setState(() => message = 'Mengirim tes cetak...');
    final r = await printer.testPrint();
    setState(() => message = r.message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Pengaturan Printer', style: TextStyle(fontWeight: FontWeight.w700))),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
              'Printer label Bluetooth ESC/POS, label 50 x 30 mm. Pair printer terlebih dahulu di Pengaturan Bluetooth Android, lalu pilih di bawah.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              _Notice(error!, AppColors.danger)
            else if (devices.isEmpty)
              const _Notice('Belum ada perangkat Bluetooth yang di-pair.', AppColors.warning)
            else
              ...devices.map((d) => Card(
                    child: ListTile(
                      leading: Icon(Icons.print_outlined, color: d.mac == printer.mac ? AppColors.primary : Colors.black45),
                      title: Text(d.name.isEmpty ? '(tanpa nama)' : d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(d.mac),
                      trailing: d.mac == printer.mac ? const Icon(Icons.check_circle, color: AppColors.success) : null,
                      onTap: () => _select(d),
                    ),
                  )),
            const SizedBox(height: 12),
            const Text('Lebar kertas', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 384, label: Text('58 mm / label 50 mm')), ButtonSegment(value: 576, label: Text('80 mm'))],
              selected: {printer.dotsWidth},
              onSelectionChanged: (s) async {
                if (printer.isConfigured) await printer.save(mac: printer.mac!, name: printer.name ?? '', dotsWidth: s.first);
                setState(() => printer.dotsWidth = s.first);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('Feed setelah label (baris)', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: printer.feedLines <= 0 ? null : () => _feed(printer.feedLines - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${printer.feedLines}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: printer.feedLines >= 10 ? null : () => _feed(printer.feedLines + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            const Text('Tambah jika label berikutnya terpotong; kurangi jika ada label kosong.', style: TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: printer.isConfigured ? _test : null,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Tes Cetak', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            TextButton(onPressed: Get.back, child: const Text('Kembali')),
          ]),
        ),
      );

  Future<void> _feed(int v) async {
    if (printer.isConfigured) {
      await printer.save(mac: printer.mac!, name: printer.name ?? '', feedLines: v);
    }
    setState(() => printer.feedLines = v);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      );
}
