import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../controllers/products_controller.dart';
import '../models/product_model.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProductsController controller;

  @override
  void initState() {
    super.initState();

    controller = Get.find<ProductsController>();

    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      controller.changeTab(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'Produk & Kategori',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black,
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Produk'),
          Tab(text: 'Kategori'),
        ],
      ),
    ),
    floatingActionButton: Obx(
      () => FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: controller.selectedTab.value == 0
            ? controller.showProductForm
            : () => _categoryDialog(context, controller: controller),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          controller.selectedTab.value == 0
              ? 'Tambah Produk'
              : 'Tambah Kategori',
        ),
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _ProductsTab(controller: controller),
        _CategoriesTab(controller: controller),
      ],
    ),
  );
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.controller});
  final ProductsController controller;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          children: [
            Obx(
              () => Row(
                children: [
                  _SummaryChip(
                    label: 'Total Produk',
                    value: '${controller.products.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Stok Menipis',
                    value: '${controller.lowStockCount}',
                    icon: Icons.warning_amber_rounded,
                    warning: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSearchField(
              hint: 'Cari nama, SKU, atau barcode...',
              controller: controller.searchController,
              onChanged: controller.updateSearch,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: Obx(
                () => ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['Semua', ...controller.categories].map((category) {
                    final selected =
                        controller.selectedCategory.value == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) =>
                            controller.selectedCategory.value = category,
                        selectedColor: AppColors.softOrange,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? AppColors.darkOrange
                              : AppColors.charcoal,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Obx(() {
          final items = controller.filteredProducts;
          if (items.isEmpty)
            return const Center(child: Text('Produk tidak ditemukan.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) => _ProductCard(
              product: items[index],
              onEdit: () => controller.showProductForm(product: items[index]),
            ),
          );
        }),
      ),
    ],
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onEdit});
  final ProductModel product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.softOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${product.sku} • ${product.category}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const Divider(height: 18),
        Row(
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              size: 16,
              color: Colors.black45,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                product.barcode,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
            Text(
              '${product.stock} ${product.unit}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: product.isLowStock
                    ? const Color(0xFFFFEEEE)
                    : const Color(0xFFE8F7EF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                product.isLowStock ? 'Stok Rendah' : 'Aman',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: product.isLowStock
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.black38,
            ),
            const SizedBox(width: 4),
            Text(
              'Lokasi: ${product.location}',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
            const Spacer(),
            Text(
              'Min. ${product.minimumStock} ${product.unit}',
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.controller});
  final ProductsController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: controller.categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = controller.categories[index];
        final count = controller.products
            .where((p) => p.category == category)
            .length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$count produk',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _categoryDialog(
                  context,
                  controller: controller,
                  initial: category,
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 19,
                ),
              ),
              IconButton(
                onPressed: () => Get.dialog(
                  AlertDialog(
                    title: const Text('Hapus kategori?'),
                    content: Text('Kategori "$category" akan dihapus.'),
                    actions: [
                      TextButton(
                        onPressed: Get.back,
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.deleteCategory(category);
                          Get.back();
                        },
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                  size: 19,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _categoryDialog(
  BuildContext context, {
  required ProductsController controller,
  String? initial,
}) {
  Get.dialog(
    _CategoryDialog(controller: controller, initial: initial),
    barrierDismissible: true,
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.controller, this.initial});

  final ProductsController controller;
  final String? initial;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController field;

  @override
  void initState() {
    super.initState();
    field = TextEditingController(text: widget.initial ?? '');
  }

  void saveCategory() {
    final value = field.text.trim();

    if (value.isEmpty) {
      Get.snackbar(
        'Data belum lengkap',
        'Nama kategori wajib diisi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (widget.initial == null) {
      widget.controller.addCategory(value);
    } else {
      widget.controller.renameCategory(widget.initial!, value);
    }

    Get.back();
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori'),
      content: TextField(
        controller: field,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama kategori',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: saveCategory,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool warning;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: warning ? AppColors.warning : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
