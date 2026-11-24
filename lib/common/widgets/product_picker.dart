import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import '../../modules/products/controllers/products_controller.dart';
import '../../modules/products/models/product_model.dart';

/// Pilih produk dari master item (tanpa mengetik): filter kategori dengan chip, ketuk produk.
/// Kotak cari tersedia tetapi tidak membuka keyboard otomatis. SUNMI tidak dapat membuat item baru dari sini.
Future<ProductModel?> pickProductManually({String title = 'Pilih produk'}) async {
  final products = Get.find<ProductsController>();
  if (products.products.isEmpty) await products.refreshAll();
  final query = ''.obs;
  final category = RxnString();
  return Get.bottomSheet<ProductModel>(
    Container(
      height: Get.height * .85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: Obx(() {
            final cats = products.products.where((p) => p.isActive).map((p) => p.category).toSet().toList()..sort();
            return ListView(scrollDirection: Axis.horizontal, children: [
              _CategoryChip(label: 'Semua', selected: category.value == null, onTap: () => category.value = null),
              for (final c in cats) _CategoryChip(label: c, selected: category.value == c, onTap: () => category.value = c),
            ]);
          }),
        ),
        const SizedBox(height: 6),
        TextField(
          onChanged: (v) => query.value = v.toLowerCase(),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari (opsional)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Obx(() {
            final q = query.value;
            final list = products.products.where((p) => p.isActive && (category.value == null || p.category == category.value) && (q.isEmpty ||
                p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.barcode.contains(q))).toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            if (list.isEmpty) {
              return const Center(child: Text('Item belum terdaftar. Gunakan "Barang belum terdaftar" atau hubungi administrator.', textAlign: TextAlign.center));
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  minVerticalPadding: 12,
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p.sku} • ${p.category} • ${p.unit}'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  onTap: () => Get.back(result: p),
                );
              },
            );
          }),
        ),
      ]),
    ),
    isScrollControlled: true,
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

/// Dialog jelas saat barcode tidak terdaftar.
Future<void> showNotRegistered(String message) => Get.dialog(AlertDialog(
  icon: const Icon(Icons.inventory_2_outlined, color: AppColors.danger, size: 36),
  title: const Text('Item tidak dikenal'),
  content: Text(message),
  actions: [FilledButton(onPressed: Get.back, child: const Text('Mengerti'))],
));
