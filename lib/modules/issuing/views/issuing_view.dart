import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/models/warehouse_model.dart';
import '../controllers/issuing_controller.dart';
import '../models/issuing_model.dart';

class IssuingView extends GetView<IssuingController> {
  const IssuingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Pengeluaran Barang', style: TextStyle(fontWeight: FontWeight.w700))),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () => _IssuingForm.show(controller),
      icon: const Icon(Icons.add_rounded), label: const Text('Pengeluaran Baru'),
    ),
    body: Obx(() {
      final records = controller.filteredIssuings;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _SummarySection(controller: controller),
          const SizedBox(height: 18),
          const Text('Daftar Pengeluaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          AppSearchField(
            hint: 'Cari nomor, tujuan, atau gudang...',
            controller: controller.searchController,
            onChanged: controller.updateSearch,
          ),
          const SizedBox(height: 10),
          SizedBox(height: 36, child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['Semua', 'Draft', 'Pending', 'Completed', 'Cancelled'].map((status) {
              final selected = controller.selectedStatus.value == status;
              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(status, style: const TextStyle(fontSize: 10)),
                  selected: selected, selectedColor: AppColors.softOrange,
                  onSelected: (_) => controller.selectedStatus.value = status,
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 45), child: Center(child: Text('Tidak ada transaksi pengeluaran.', style: TextStyle(color: Colors.black54))))
          else
            ...records.map((record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IssuingCard(
                record: record,
                onTap: () => _showDetail(controller, record),
                onMenu: (action) {
                  if (action == 'complete') _confirmStatus(controller, record, IssuingStatus.completed);
                  if (action == 'cancel') _confirmStatus(controller, record, IssuingStatus.cancelled);
                  if (action == 'delete') _confirmDelete(controller, record);
                },
              ),
            )),
        ],
      );
    }),
  );
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.controller});
  final IssuingController controller;
  @override
  Widget build(BuildContext context) => Obx(() => Column(children: [
    Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.darkOrange]), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.outbox_rounded, color: Colors.white, size: 38), const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Barang Dikeluarkan', style: TextStyle(color: Colors.white70, fontSize: 11)),
          Text('${controller.totalIssuedQuantity} unit', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          Text('${controller.completedCount} transaksi selesai', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      ]),
    ),
    const SizedBox(height: 10),
    Row(children: [
      _SummaryTile(label: 'Total Transaksi', value: '${controller.totalTransactions}', icon: Icons.receipt_long_outlined),
      const SizedBox(width: 9),
      _SummaryTile(label: 'Menunggu', value: '${controller.pendingCount}', icon: Icons.pending_actions_rounded, warning: true),
    ]),
  ]));
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon, this.warning = false});
  final String label, value; final IconData icon; final bool warning;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(icon, color: warning ? AppColors.warning : AppColors.primary, size: 22), const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ])),
    ]),
  ));
}

class _IssuingCard extends StatelessWidget {
  const _IssuingCard({required this.record, required this.onTap, required this.onMenu});
  final IssuingModel record; final VoidCallback onTap; final ValueChanged<String> onMenu;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 39, height: 39, decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.outbox_outlined, color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3), Text(IssuingController.formatDate(record.date), style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ])),
          AppStatusBadge(label: IssuingController.statusLabel(record.status), color: IssuingController.statusColor(record.status)),
          PopupMenuButton<String>(onSelected: onMenu, itemBuilder: (_) => [
            if (record.status == IssuingStatus.draft || record.status == IssuingStatus.pending) const PopupMenuItem(value: 'complete', child: Text('Tandai selesai')),
            if (record.status == IssuingStatus.draft || record.status == IssuingStatus.pending) const PopupMenuItem(value: 'cancel', child: Text('Batalkan')),
            if (record.status == IssuingStatus.draft) const PopupMenuItem(value: 'delete', child: Text('Hapus draft')),
          ]),
        ]),
        const SizedBox(height: 11),
        Text(record.destination, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.warehouse_outlined, size: 14, color: Colors.black45), const SizedBox(width: 5),
          Expanded(child: Text(record.warehouseName, style: const TextStyle(fontSize: 10, color: Colors.black54))),
          Text('${record.items.length} produk • ${record.totalQuantity} unit', style: const TextStyle(fontSize: 10, color: AppColors.charcoal, fontWeight: FontWeight.w700)),
        ]),
        const Divider(height: 18),
        const Row(children: [Text('Lihat detail transaksi', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)), Spacer(), Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary)]),
      ])),
    ),
  );
}

void _showDetail(IssuingController c, IssuingModel r) {
  Get.bottomSheet(
    Container(
      constraints: BoxConstraints(maxHeight: Get.height * .82),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: ListView(shrinkWrap: true, children: [
        Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(5)))),
        const SizedBox(height: 16),
        Row(children: [const Expanded(child: Text('Detail Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), AppStatusBadge(label: IssuingController.statusLabel(r.status), color: IssuingController.statusColor(r.status))]),
        const SizedBox(height: 14),
        _DetailLine(label: 'Nomor transaksi', value: r.number),
        _DetailLine(label: 'Tanggal', value: IssuingController.formatDate(r.date)),
        _DetailLine(label: 'Tujuan', value: r.destination),
        _DetailLine(label: 'Gudang asal', value: r.warehouseName),
        const Divider(height: 24),
        const Text('Produk yang dikeluarkan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        ...r.items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), Text(item.sku, style: const TextStyle(fontSize: 10, color: Colors.black54))])),
          Text('${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]))),
        const Divider(height: 22),
        _DetailLine(label: 'Total kuantitas', value: '${r.totalQuantity} unit'),
        _DetailLine(label: 'Catatan', value: r.notes.isEmpty ? '-' : r.notes),
      ]),
    ), isScrollControlled: true,
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 116, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
    const Text(': ', style: TextStyle(fontSize: 11)),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
  ]));
}

void _confirmStatus(IssuingController c, IssuingModel r, IssuingStatus status) {
  final complete = status == IssuingStatus.completed;
  Get.dialog(AlertDialog(
    title: Text(complete ? 'Selesaikan pengeluaran?' : 'Batalkan pengeluaran?'),
    content: Text(complete ? 'Stok produk di gudang akan dikurangi sesuai jumlah transaksi.' : 'Transaksi ini akan ditandai sebagai Cancelled.'),
    actions: [TextButton(onPressed: Get.back, child: const Text('Kembali')), FilledButton(
      style: FilledButton.styleFrom(backgroundColor: complete ? AppColors.primary : AppColors.danger),
      onPressed: () { Get.back(); c.changeStatus(r, status); }, child: Text(complete ? 'Ya, Selesaikan' : 'Ya, Batalkan'),
    )],
  ));
}

void _confirmDelete(IssuingController c, IssuingModel r) => Get.dialog(AlertDialog(
  title: const Text('Hapus draft?'), content: const Text('Draft pengeluaran ini akan dihapus.'),
  actions: [TextButton(onPressed: Get.back, child: const Text('Kembali')), FilledButton(
    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
    onPressed: () { Get.back(); c.deleteDraft(r); }, child: const Text('Hapus'),
  )],
));

class _IssuingForm extends StatefulWidget {
  const _IssuingForm({required this.controller});
  final IssuingController controller;
  static void show(IssuingController controller) => Get.dialog(_IssuingForm(controller: controller), barrierDismissible: false);
  @override
  State<_IssuingForm> createState() => _IssuingFormState();
}

class _IssuingFormState extends State<_IssuingForm> {
  final _formKey = GlobalKey<FormState>();
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  late String _warehouseId;
  late DateTime _date;
  String? _productId;
  IssuingStatus _status = IssuingStatus.pending;
  final List<IssuingItemModel> _items = [];

  IssuingController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    final active = c.warehouseController.warehouses.where((w) => w.isActive).toList();
    _warehouseId = active.isNotEmpty ? active.first.id : c.warehouseController.warehouses.first.id;
    _date = DateTime.now();
    _productId = c.productsController.products.isNotEmpty ? c.productsController.products.first.id : null;
  }

  ProductModel? get _selectedProduct => c.productsController.products.firstWhereOrNull((p) => p.id == _productId);
  List<WarehouseModel> get _warehouses => c.warehouseController.warehouses.where((w) => w.isActive).toList();

  void _addItem() {
    final product = _selectedProduct;
    final qty = int.tryParse(_quantity.text.trim());
    if (product == null || qty == null || qty <= 0) {
      Get.snackbar('Produk belum valid', 'Pilih produk dan masukkan jumlah lebih dari nol.'); return;
    }
    final alreadyAdded = _items.where((e) => e.productId == product.id).fold<int>(0, (sum, e) => sum + e.quantity);
    if (alreadyAdded + qty > product.stock) {
      Get.snackbar('Stok tidak cukup', 'Stok ${product.name} tersedia ${product.stock} ${product.unit}.'); return;
    }
    setState(() {
      _items.add(IssuingItemModel(productId: product.id, productName: product.name, sku: product.sku, unit: product.unit, quantity: qty));
      _quantity.text = '1';
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) { Get.snackbar('Produk belum ditambahkan', 'Tambahkan minimal satu produk.'); return; }
    final created = c.createIssuing(destination: _destination.text.trim(), warehouseId: _warehouseId, date: _date, items: _items, notes: _notes.text, status: _status);
    if (created) Get.back();
  }

  @override
  void dispose() { _destination.dispose(); _notes.dispose(); _quantity.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: Get.height * .9),
      child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(18, 17, 10, 12), child: Row(children: [const Expanded(child: Text('Buat Pengeluaran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),), IconButton(onPressed: Get.back, icon: const Icon(Icons.close))])),
        const Divider(height: 1),
        Flexible(child: ListView(padding: const EdgeInsets.all(16), children: [
          _fieldLabel('Tujuan pengeluaran'),
          TextFormField(controller: _destination, decoration: _decoration('Contoh: Produksi, Cabang, atau Maintenance'), validator: (v) => v == null || v.trim().isEmpty ? 'Tujuan wajib diisi.' : null),
          const SizedBox(height: 13),
          _fieldLabel('Gudang asal'),
          DropdownButtonFormField<String>(value: _warehouses.any((w) => w.id == _warehouseId) ? _warehouseId : null, isExpanded: true, decoration: _decoration('Pilih gudang'), items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) setState(() => _warehouseId = v); }, validator: (v) => v == null ? 'Pilih gudang asal.' : null),
          const SizedBox(height: 13),
          _fieldLabel('Tanggal pengeluaran'),
          OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035)); if (picked != null) setState(() => _date = picked); }, icon: const Icon(Icons.calendar_today_outlined, size: 17), label: Text(IssuingController.formatDate(_date)), style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: AppColors.charcoal)),
          const SizedBox(height: 13),
          Row(children: [const Expanded(child: Text('Produk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), Text('${_items.length} item', style: const TextStyle(fontSize: 11, color: Colors.black54))]),
          const SizedBox(height: 8),
          if (c.productsController.products.isEmpty) const Text('Belum ada produk. Tambahkan produk terlebih dahulu.', style: TextStyle(fontSize: 11, color: AppColors.danger)) else ...[
            DropdownButtonFormField<String>(value: c.productsController.products.any((p) => p.id == _productId) ? _productId : null, isExpanded: true, decoration: _decoration('Pilih produk'), items: c.productsController.products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} • ${p.sku}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _productId = v)),
            if (_selectedProduct != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Stok tersedia: ${_selectedProduct!.stock} ${_selectedProduct!.unit}', style: const TextStyle(fontSize: 10, color: Colors.black54))),
            const SizedBox(height: 7),
            Row(children: [Expanded(child: TextFormField(controller: _quantity, keyboardType: TextInputType.number, decoration: _decoration('Jumlah'),)), const SizedBox(width: 8), FilledButton.icon(onPressed: _addItem, style: FilledButton.styleFrom(backgroundColor: AppColors.primary), icon: const Icon(Icons.add, size: 17), label: const Text('Tambah'))]),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 9),
            ..._items.asMap().entries.map((entry) { final index = entry.key; final item = entry.value; return Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), Text('${item.sku} • ${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 10, color: Colors.black54))])), IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _items.removeAt(index)), icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 19))])); }),
          ],
          const SizedBox(height: 13),
          _fieldLabel('Status awal'),
          DropdownButtonFormField<IssuingStatus>(value: _status, decoration: _decoration('Pilih status'), items: const [DropdownMenuItem(value: IssuingStatus.draft, child: Text('Draft')), DropdownMenuItem(value: IssuingStatus.pending, child: Text('Pending'))], onChanged: (v) { if (v != null) setState(() => _status = v); }),
          const SizedBox(height: 13),
          _fieldLabel('Catatan (opsional)'),
          TextFormField(controller: _notes, maxLines: 2, decoration: _decoration('Tambahkan catatan...')),
        ])),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 13)), child: const Text('Simpan Pengeluaran', style: TextStyle(fontWeight: FontWeight.w700))))),
      ])),
    ),
  );
}

Widget _fieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.charcoal)));
InputDecoration _decoration(String hint) => InputDecoration(hintText: hint, hintStyle: const TextStyle(fontSize: 11), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)));
