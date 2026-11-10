import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../products/models/product_model.dart';
import '../controllers/stock_opname_controller.dart';
import '../models/stock_opname_model.dart';

class StockOpnameView extends GetView<StockOpnameController> {
  const StockOpnameView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Stock Opname',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _OpnameForm.show(controller),
        icon: const Icon(Icons.add),
        label: const Text('Opname Baru'),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            _summary(),
            const SizedBox(height: 18),

            const Text(
              'Riwayat Stock Opname',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            AppSearchField(
              hint: 'Cari nomor atau gudang...',
              controller: controller.searchController,
              onChanged: controller.updateSearch,
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Semua', 'Draft', 'Completed', 'Cancelled']
                    .map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(
                            status,
                            style: const TextStyle(fontSize: 10),
                          ),
                          selected: controller.selectedStatus.value == status,
                          selectedColor: AppColors.softOrange,
                          onSelected: (_) {
                            controller.selectedStatus.value = status;
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            if (controller.filteredRecords.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 45),
                child: Center(child: Text('Belum ada data stock opname.')),
              )
            else
              ...controller.filteredRecords.map(
                (record) => _OpnameCard(
                  record: record,
                  onTap: () => _detail(record),
                  onAction: (action) {
                    if (action == 'complete') {
                      _confirm(record);
                    } else if (action == 'cancel') {
                      controller.cancel(record);
                    } else if (action == 'delete') {
                      controller.deleteDraft(record);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // SUMMARY
  Widget _summary() {
    return Obx(
      () => Container(
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
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Opname Selesai',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    '${controller.completedCount} transaksi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${controller.totalDifferences} item memiliki selisih',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CONFIRM COMPLETE
  void _confirm(StockOpnameModel record) {
    Get.dialog(
      AlertDialog(
        title: const Text('Selesaikan stock opname?'),
        content: const Text(
          'Stok sistem akan disesuaikan dengan jumlah fisik yang dicatat.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Kembali')),
          FilledButton(
            onPressed: () {
              Get.back();
              controller.complete(record);
            },
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
  }

  // DETAIL
  void _detail(StockOpnameModel record) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.82),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Detail Stock Opname',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            _line('Nomor', record.number),
            _line('Tanggal', StockOpnameController.formatDate(record.date)),
            _line('Gudang', record.warehouseName),
            _line('Status', StockOpnameController.statusLabel(record.status)),

            const Divider(height: 24),

            const Text(
              'Hasil Perhitungan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),

            ...record.items.map(
              (item) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
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
                      'SKU: ${item.sku}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sistem: ${item.systemStock} ${item.unit}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Fisik: ${item.physicalStock} ${item.unit}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Selisih: '
                      '${item.difference > 0 ? '+' : ''}'
                      '${item.difference}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: item.difference == 0
                            ? AppColors.success
                            : item.difference > 0
                            ? AppColors.info
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (record.notes.isNotEmpty) _line('Catatan', record.notes),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // DETAIL ROW
  static Widget _line(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              title,
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STOCK OPNAME CARD
// ============================================================

class _OpnameCard extends StatelessWidget {
  const _OpnameCard({
    required this.record,
    required this.onTap,
    required this.onAction,
  });

  final StockOpnameModel record;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(top: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.number,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          StockOpnameController.formatDate(record.date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppStatusBadge(
                    label: StockOpnameController.statusLabel(record.status),
                    color: StockOpnameController.statusColor(record.status),
                  ),

                  PopupMenuButton<String>(
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      if (record.status == OpnameStatus.draft)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Text('Terapkan hasil'),
                        ),
                      if (record.status == OpnameStatus.draft)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Batalkan'),
                        ),
                      if (record.status == OpnameStatus.draft)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Hapus draft'),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.warehouseName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${record.items.length} produk • '
                    '${record.totalDifference > 0 ? '+' : ''}'
                    '${record.totalDifference} selisih',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
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
}

// ============================================================
// STOCK OPNAME FORM
// ============================================================

class _OpnameForm extends StatefulWidget {
  const _OpnameForm({required this.c});

  final StockOpnameController c;

  static void show(StockOpnameController c) {
    Get.dialog(_OpnameForm(c: c), barrierDismissible: false);
  }

  @override
  State<_OpnameForm> createState() => _OpnameFormState();
}

class _OpnameFormState extends State<_OpnameForm> {
  String? warehouseId;

  final TextEditingController notes = TextEditingController();
  final List<_OpnameDraft> rows = [];

  late DateTime date;

  StockOpnameController get c => widget.c;

  @override
  void initState() {
    super.initState();

    final activeWarehouses = c.warehouses.warehouses
        .where((warehouse) => warehouse.isActive)
        .toList();

    warehouseId = activeWarehouses.isNotEmpty
        ? activeWarehouses.first.id
        : null;

    date = DateTime.now();
  }

  // ADD PRODUCT
  void add() {
    final availableProducts = c.products.products
        .where((product) => !rows.any((row) => row.product.id == product.id))
        .toList();

    if (availableProducts.isEmpty) {
      Get.snackbar(
        'Informasi',
        'Semua produk sudah ditambahkan.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final product = availableProducts.first;

    setState(() {
      rows.add(
        _OpnameDraft(
          product,
          TextEditingController(text: product.stock.toString()),
        ),
      );
    });
  }

  // SAVE DRAFT
  void save() {
    final items = rows.map((row) {
      return StockOpnameItemModel(
        productId: row.product.id,
        productName: row.product.name,
        sku: row.product.sku,
        unit: row.product.unit,
        systemStock: row.product.stock,
        physicalStock: int.tryParse(row.qty.text) ?? -1,
      );
    }).toList();

    final success = c.createOpname(
      warehouseId: warehouseId ?? '',
      date: date,
      items: items,
      notes: notes.text,
    );

    if (success) {
      Get.back();
    }
  }

  // REMOVE PRODUCT
  void removeRow(int index) {
    if (index < 0 || index >= rows.length) return;

    final removed = rows.removeAt(index);
    removed.qty.dispose();

    setState(() {});
  }

  @override
  void dispose() {
    notes.dispose();

    for (final row in rows) {
      row.qty.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.88,
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock Opname Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  children: [
                    DropdownButtonFormField<String>(
                      value: warehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Gudang',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: c.warehouses.warehouses
                          .where((warehouse) => warehouse.isActive)
                          .map(
                            (warehouse) => DropdownMenuItem<String>(
                              value: warehouse.id,
                              child: Text(warehouse.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          warehouseId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Hitung stok fisik',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: add,
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('Tambah Produk'),
                        ),
                      ],
                    ),

                    ...rows.asMap().entries.map(
                      (entry) => _row(entry.key, entry.value),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: save,
                      child: const Text(
                        'Simpan Draft',
                        textAlign: TextAlign.center,
                        maxLines: 2,
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

  // PRODUCT ROW
  Widget _row(int index, _OpnameDraft row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ProductModel>(
            value: row.product,
            decoration: const InputDecoration(
              labelText: 'Produk',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: c.products.products.map((product) {
              return DropdownMenuItem<ProductModel>(
                value: product,
                child: Text(product.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (product) {
              if (product == null) return;

              setState(() {
                row.product = product;
                row.qty.text = product.stock.toString();
              });
            },
          ),

          const SizedBox(height: 7),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Stok sistem: '
                  '${row.product.stock} ${row.product.unit}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),

              SizedBox(
                width: 100,
                child: TextField(
                  controller: row.qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok fisik',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),

              IconButton(
                onPressed: () => removeRow(index),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OPNAME DRAFT MODEL
// ============================================================

class _OpnameDraft {
  _OpnameDraft(this.product, this.qty);

  ProductModel product;
  final TextEditingController qty;
}
