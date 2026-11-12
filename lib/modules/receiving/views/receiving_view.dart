import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/models/warehouse_model.dart';
import '../controllers/receiving_controller.dart';
import '../models/receiving_model.dart';

class ReceivingView extends GetView<ReceivingController> {
  const ReceivingView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'Penerimaan Barang',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () => _ReceivingForm.show(controller),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Penerimaan Baru'),
    ),
    body: Obx(() {
      final records = controller.filteredReceivings;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          _SummarySection(controller: controller),
          const SizedBox(height: 18),
          const Text(
            'Daftar Penerimaan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          AppSearchField(
            hint: 'Cari nomor, supplier, atau gudang...',
            controller: controller.searchController,
            onChanged: controller.updateSearch,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Semua', 'Draft', 'Pending', 'Completed', 'Cancelled']
                  .map((status) {
                    final selected = controller.selectedStatus.value == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(
                          status,
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: selected,
                        selectedColor: AppColors.softOrange,
                        onSelected: (_) =>
                            controller.selectedStatus.value = status,
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 45),
              child: Center(
                child: Text(
                  'Tidak ada transaksi penerimaan.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReceivingCard(
                  record: record,
                  onTap: () => _showDetail(controller, record),
                  onMenu: (action) {
                    if (action == 'complete') {
                      _confirmComplete(controller, record);
                    } else if (action == 'cancel') {
                      _confirmCancel(controller, record);
                    } else if (action == 'delete') {
                      _confirmDelete(controller, record);
                    }
                  },
                ),
              ),
            ),
        ],
      );
    }),
  );
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.controller});
  final ReceivingController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.darkOrange],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.move_to_inbox_rounded,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Barang Diterima',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '${controller.totalReceivedQuantity} unit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${controller.completedCount} transaksi selesai',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SummaryTile(
              label: 'Total Transaksi',
              value: '${controller.totalItems}',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(width: 9),
            _SummaryTile(
              label: 'Menunggu',
              value: '${controller.pendingCount}',
              icon: Icons.pending_actions_rounded,
              warning: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });
  final String label, value;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: warning ? AppColors.warning : AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReceivingCard extends StatelessWidget {
  const _ReceivingCard({
    required this.record,
    required this.onTap,
    required this.onMenu,
  });
  final ReceivingModel record;
  final VoidCallback onTap;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: AppColors.softOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ReceivingController.formatDate(record.date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusBadge(
                  label: ReceivingController.statusLabel(record.status),
                  color: ReceivingController.statusColor(record.status),
                ),
                PopupMenuButton<String>(
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    if (record.status == ReceivingStatus.draft ||
                        record.status == ReceivingStatus.pending)
                      const PopupMenuItem(
                        value: 'complete',
                        child: Text('Tandai selesai'),
                      ),
                    if (record.status == ReceivingStatus.draft ||
                        record.status == ReceivingStatus.pending)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Batalkan'),
                      ),
                    if (record.status == ReceivingStatus.draft)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus draft'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              record.supplier,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  size: 14,
                  color: Colors.black45,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    record.warehouseName,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ),
                Text(
                  '${record.items.length} produk • ${record.totalQuantity} unit',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            const Row(
              children: [
                Text(
                  'Lihat detail transaksi',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showDetail(ReceivingController c, ReceivingModel r) {
  Get.bottomSheet(
    Container(
      constraints: BoxConstraints(maxHeight: Get.height * .82),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Detail Penerimaan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              AppStatusBadge(
                label: ReceivingController.statusLabel(r.status),
                color: ReceivingController.statusColor(r.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(label: 'Nomor transaksi', value: r.number),
          _DetailLine(
            label: 'Tanggal',
            value: ReceivingController.formatDate(r.date),
          ),
          _DetailLine(label: 'Supplier', value: r.supplier),
          _DetailLine(label: 'Gudang tujuan', value: r.warehouseName),
          const Divider(height: 24),
          const Text(
            'Item Barang',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...r.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.sku,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.quantity} ${item.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Catatan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              r.notes,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 14),
          if (r.status == ReceivingStatus.draft ||
              r.status == ReceivingStatus.pending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                      _confirmCancel(c, r);
                    },
                    child: const Text('Batalkan'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () {
                      Get.back();
                      _confirmComplete(c, r);
                    },
                    child: const Text('Selesaikan'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
        const Text(':  ', style: TextStyle(fontSize: 11)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

void _confirmComplete(ReceivingController c, ReceivingModel r) => Get.dialog(
  AlertDialog(
    title: const Text('Selesaikan penerimaan?'),
    content: Text(
      'Stok dari ${r.items.length} item pada transaksi ${r.number} akan ditambahkan ke data produk.',
    ),
    actions: [
      TextButton(onPressed: Get.back, child: const Text('Kembali')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () {
          c.changeStatus(r, ReceivingStatus.completed);
          Get.back();
        },
        child: const Text('Selesaikan'),
      ),
    ],
  ),
);

void _confirmCancel(ReceivingController c, ReceivingModel r) => Get.dialog(
  AlertDialog(
    title: const Text('Batalkan penerimaan?'),
    content: Text('Transaksi ${r.number} akan ditandai Cancelled.'),
    actions: [
      TextButton(onPressed: Get.back, child: const Text('Kembali')),
      TextButton(
        onPressed: () {
          c.changeStatus(r, ReceivingStatus.cancelled);
          Get.back();
        },
        child: const Text(
          'Batalkan',
          style: TextStyle(color: AppColors.danger),
        ),
      ),
    ],
  ),
);

void _confirmDelete(ReceivingController c, ReceivingModel r) => Get.dialog(
  AlertDialog(
    title: const Text('Hapus draft?'),
    content: Text('Draft ${r.number} akan dihapus.'),
    actions: [
      TextButton(onPressed: Get.back, child: const Text('Kembali')),
      TextButton(
        onPressed: () {
          c.deleteDraft(r);
          Get.back();
        },
        child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
      ),
    ],
  ),
);

class _ReceivingForm {
  static void show(ReceivingController c) => Get.dialog(
    _ReceivingFormDialog(controller: c),
    barrierDismissible: false,
  );
}

class _ReceivingFormDialog extends StatefulWidget {
  const _ReceivingFormDialog({required this.controller});
  final ReceivingController controller;
  @override
  State<_ReceivingFormDialog> createState() => _ReceivingFormDialogState();
}

class _ReceivingFormDialogState extends State<_ReceivingFormDialog> {
  late final TextEditingController supplier, notes, quantity;
  late DateTime date;
  late String? warehouseId, productId;
  ReceivingStatus status = ReceivingStatus.pending;
  final List<ReceivingItemModel> items = [];

  List<WarehouseModel> get warehouses => widget
      .controller
      .warehouseController
      .warehouses
      .where((w) => w.isActive)
      .toList();
  List<ProductModel> get products =>
      widget.controller.productsController.products.toList();

  @override
  void initState() {
    super.initState();
    supplier = TextEditingController();
    notes = TextEditingController();
    quantity = TextEditingController(text: '1');
    date = DateTime.now();
    warehouseId = warehouses.isNotEmpty ? warehouses.first.id : null;
    productId = products.isNotEmpty ? products.first.id : null;
  }

  @override
  void dispose() {
    supplier.dispose();
    notes.dispose();
    quantity.dispose();
    super.dispose();
  }

  void addItem() {
    final product = products.firstWhereOrNull((p) => p.id == productId);
    final qty = int.tryParse(quantity.text.trim());
    if (product == null || qty == null || qty <= 0) {
      Get.snackbar(
        'Item belum valid',
        'Pilih produk dan masukkan jumlah lebih dari nol.',
      );
      return;
    }
    final index = items.indexWhere((e) => e.productId == product.id);
    setState(() {
      if (index >= 0) {
        final old = items[index];
        items[index] = ReceivingItemModel(
          productId: old.productId,
          productName: old.productName,
          sku: old.sku,
          unit: old.unit,
          quantity: old.quantity + qty,
        );
      } else {
        items.add(
          ReceivingItemModel(
            productId: product.id,
            productName: product.name,
            sku: product.sku,
            unit: product.unit,
            quantity: qty,
          ),
        );
      }
      quantity.text = '1';
    });
  }

  void save() {
    if (supplier.text.trim().isEmpty || warehouseId == null || items.isEmpty) {
      Get.snackbar(
        'Data belum lengkap',
        'Supplier, gudang, dan minimal satu item wajib diisi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    widget.controller.createReceiving(
      supplier: supplier.text.trim(),
      warehouseId: warehouseId!,
      date: date,
      items: items,
      notes: notes.text.trim(),
      status: status,
    );
    Get.back();
    Get.snackbar(
      'Berhasil',
      'Transaksi penerimaan berhasil dibuat.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 500, maxHeight: (MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 32).clamp(140.0, 720.0).toDouble()),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Penerimaan Barang Baru',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      supplier,
                      'Nama supplier',
                      hint: 'Contoh: PT Sumber Elektronik',
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      value: warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Gudang tujuan',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      items: warehouses
                          .map(
                            (w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(
                                '${w.name} (${w.code})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => warehouseId = v),
                    ),
                    const SizedBox(height: 11),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => date = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal penerimaan',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(ReceivingController.formatDate(date)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Item Barang',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (products.isEmpty)
                      const Text(
                        'Belum ada data produk. Tambahkan produk terlebih dahulu.',
                        style: TextStyle(fontSize: 11, color: AppColors.danger),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: productId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih produk',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                        ),
                        items: products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${p.name} • ${p.sku}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => productId = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(quantity, 'Jumlah', numeric: true),
                          ),
                          const SizedBox(width: 9),
                          SizedBox(
                            height: 53,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              onPressed: addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Tambah'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${item.sku} • ${item.quantity} ${item.unit}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => items.removeAt(i)),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ReceivingStatus>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Status awal',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ReceivingStatus.draft,
                          child: Text('Draft'),
                        ),
                        DropdownMenuItem(
                          value: ReceivingStatus.pending,
                          child: Text('Pending'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => status = v);
                      },
                    ),
                    const SizedBox(height: 11),
                    _field(notes, 'Catatan (opsional)', maxLines: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: Get.back,
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: save,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Simpan', maxLines: 1, softWrap: false),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  String? hint,
  bool numeric = false,
  int maxLines = 1,
}) => TextField(
  controller: controller,
  maxLines: maxLines,
  keyboardType: numeric ? TextInputType.number : TextInputType.text,
  textCapitalization: TextCapitalization.words,
  decoration: InputDecoration(
    labelText: label,
    hintText: hint,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  ),
);
