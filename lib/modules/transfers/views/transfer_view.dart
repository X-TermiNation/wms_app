import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../services/scanner/scanner_service.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../../products/models/product_model.dart';
import '../../warehouse/models/warehouse_model.dart';
import '../controllers/transfer_controller.dart';
import '../models/transfer_model.dart';

class TransferView extends GetView<TransferController> {
  const TransferView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Transfer Barang',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _TransferForm.show(controller),
        icon: const Icon(Icons.add),
        label: const Text('Transfer Baru'),
      ),
      body: Obx(() {
        final rows = controller.filteredTransfers;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            _summary(),
            const SizedBox(height: 18),

            const Text(
              'Daftar Transfer',
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
                children:
                    ['Semua', 'Draft', 'Pending', 'Completed', 'Cancelled'].map(
                      (status) {
                        return Padding(
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
                        );
                      },
                    ).toList(),
              ),
            ),

            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 45),
                child: Center(child: Text('Belum ada transaksi transfer.')),
              )
            else
              ...rows.map(
                (record) => _TransferCard(
                  record: record,
                  onTap: () => _detail(record),
                  onAction: (action) {
                    if (action == 'complete') {
                      _confirmComplete(record);
                    } else if (action == 'cancel') {
                      controller.changeStatus(record, TransferStatus.cancelled);
                    } else if (action == 'delete') {
                      controller.deleteDraft(record);
                    }
                  },
                ),
              ),
          ],
        );
      }),
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
            const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Barang Ditransfer',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    '${controller.totalMoved} unit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${controller.completedCount} transaksi selesai',
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
  void _confirmComplete(TransferModel record) {
    Get.dialog(
      AlertDialog(
        title: const Text('Selesaikan transfer?'),
        content: Text('Transfer ${record.number} akan ditandai selesai.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Kembali')),
          FilledButton(
            onPressed: () {
              Get.back();
              controller.changeStatus(record, TransferStatus.completed);
            },
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
  }

  // DETAIL
  void _detail(TransferModel record) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.8),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Detail Transfer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            _line('Nomor', record.number),
            _line('Tanggal', TransferController.formatDate(record.date)),
            _line('Gudang asal', record.sourceWarehouseName),
            _line('Gudang tujuan', record.destinationWarehouseName),
            _line('Status', TransferController.statusLabel(record.status)),

            const Divider(height: 24),

            const Text(
              'Item Barang',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),

            ...record.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(item.sku, style: const TextStyle(fontSize: 10)),
                trailing: Text(
                  '${item.quantity} ${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
// TRANSFER CARD
// ============================================================

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.record,
    required this.onTap,
    required this.onAction,
  });

  final TransferModel record;
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, color: AppColors.primary),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.number,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          TransferController.formatDate(record.date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppStatusBadge(
                    label: TransferController.statusLabel(record.status),
                    color: TransferController.statusColor(record.status),
                  ),

                  PopupMenuButton<String>(
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      if (record.status == TransferStatus.pending ||
                          record.status == TransferStatus.draft)
                        const PopupMenuItem(
                          value: 'complete',
                          child: Text('Tandai selesai'),
                        ),
                      if (record.status == TransferStatus.pending ||
                          record.status == TransferStatus.draft)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Batalkan'),
                        ),
                      if (record.status == TransferStatus.draft)
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
                      record.sourceWarehouseName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      record.destinationWarehouseName,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 16),

              Row(
                children: [
                  Text(
                    '${record.items.length} produk • '
                    '${record.totalQuantity} unit',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Lihat detail',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
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
// TRANSFER FORM
// ============================================================

class _TransferForm extends StatefulWidget {
  const _TransferForm({required this.c});

  final TransferController c;

  static void show(TransferController c) {
    Get.dialog(_TransferForm(c: c), barrierDismissible: false);
  }

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  String? source;
  String? destination;

  late DateTime date;

  final TextEditingController notes = TextEditingController();
  final List<_TransferDraft> rows = [];
  StreamSubscription<String>? _scannerSubscription;

  TransferController get c => widget.c;

  @override
  void initState() {
    super.initState();

    final activeWarehouses = c.warehouses.warehouses
        .where((warehouse) => warehouse.isActive)
        .toList();

    source = activeWarehouses.isNotEmpty ? activeWarehouses.first.id : null;

    destination = activeWarehouses.length > 1 ? activeWarehouses[1].id : null;

    date = DateTime.now();
    _scannerSubscription = ScannerService.instance.listen(_handleBarcode, onError: (error) {
      Get.snackbar('Scanner error', 'Tidak dapat menerima hasil scan: $error');
    });
  }

  void _handleBarcode(String barcode) {
    final product = c.products.products.firstWhereOrNull(
      (item) => item.barcode.trim().toLowerCase() == barcode.trim().toLowerCase() ||
          item.sku.trim().toLowerCase() == barcode.trim().toLowerCase(),
    );
    if (product == null) {
      Get.snackbar('Produk tidak ditemukan', 'Barcode: $barcode', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final existing = rows.firstWhereOrNull((row) => row.product.id == product.id);
    setState(() {
      if (existing != null) {
        final current = int.tryParse(existing.qty.text) ?? 0;
        existing.qty.text = (current + 1).toString();
      } else {
        rows.add(_TransferDraft(product, TextEditingController(text: '1')));
      }
    });
    Get.snackbar('Produk ditambahkan', '${product.name} · $barcode', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
  }

  // ADD ITEM
  void addItem() {
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
      rows.add(_TransferDraft(product, TextEditingController(text: '1')));
    });
  }

  // REMOVE ITEM
  void removeItem(int index) {
    if (index < 0 || index >= rows.length) return;

    final removed = rows.removeAt(index);
    removed.qty.dispose();

    setState(() {});
  }

  // SAVE TRANSFER
  void save() {
    final items = rows.map((row) {
      return TransferItemModel(
        productId: row.product.id,
        productName: row.product.name,
        sku: row.product.sku,
        unit: row.product.unit,
        quantity: int.tryParse(row.qty.text) ?? 0,
      );
    }).toList();

    final success = c.createTransfer(
      sourceId: source ?? '',
      destinationId: destination ?? '',
      date: date,
      items: items,
      notes: notes.text,
      status: TransferStatus.draft,
    );

    if (success) {
      Get.back();
    }
  }

  @override
  void dispose() {
    _scannerSubscription?.cancel();
    notes.dispose();

    for (final row in rows) {
      row.qty.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeWarehouses = c.warehouses.warehouses
        .where((warehouse) => warehouse.isActive)
        .toList();

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
                'Transfer Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  children: [
                    _dropdown('Gudang Asal', source, activeWarehouses, (value) {
                      setState(() {
                        source = value;

                        if (source == destination) {
                          destination = null;
                        }
                      });
                    }),

                    const SizedBox(height: 9),

                    _dropdown(
                      'Gudang Tujuan',
                      destination,
                      activeWarehouses
                          .where((warehouse) => warehouse.id != source)
                          .toList(),
                      (value) {
                        setState(() {
                          destination = value;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(Icons.qr_code_scanner, color: AppColors.darkOrange),
                        SizedBox(width: 8),
                        Expanded(child: Text('Tekan tombol scan SUNMI untuk menambahkan produk otomatis.', style: TextStyle(fontSize: 12))),
                      ]),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Produk yang dipindahkan',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: addItem,
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),

                    ...rows.asMap().entries.map(
                      (entry) => _itemRow(entry.key, entry.value),
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

  // WAREHOUSE DROPDOWN
  Widget _dropdown(
    String label,
    String? value,
    List<WarehouseModel> warehouses,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: warehouses.map((warehouse) {
        return DropdownMenuItem<String>(
          value: warehouse.id,
          child: Text(warehouse.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // PRODUCT ROW
  Widget _itemRow(int index, _TransferDraft row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<ProductModel>(
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
                });
              },
            ),
          ),

          const SizedBox(width: 7),

          SizedBox(
            width: 72,
            child: TextField(
              controller: row.qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Qty',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),

          IconButton(
            onPressed: () => removeItem(index),
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TRANSFER DRAFT MODEL
// ============================================================

class _TransferDraft {
  _TransferDraft(this.product, this.qty);

  ProductModel product;
  final TextEditingController qty;
}
