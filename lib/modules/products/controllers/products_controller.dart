import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../models/product_model.dart';

class ProductsController extends GetxController {
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedTab = 0.obs;
  final selectedCategory = 'Semua'.obs;

  final categories = <String>[
    'Elektronik',
    'Peralatan',
    'Bahan Baku',
    'Kemasan',
  ].obs;

  final products = <ProductModel>[
    ProductModel(
      id: '1',
      sku: 'ELK-001',
      barcode: '8991001000011',
      name: 'Kabel USB Type-C',
      category: 'Elektronik',
      unit: 'PCS',
      stock: 125,
      minimumStock: 20,
      location: 'A-01-02',
    ),
    ProductModel(
      id: '2',
      sku: 'ELK-002',
      barcode: '8991001000012',
      name: 'Adaptor 20W',
      category: 'Elektronik',
      unit: 'PCS',
      stock: 8,
      minimumStock: 15,
      location: 'A-01-03',
    ),
    ProductModel(
      id: '3',
      sku: 'PRT-001',
      barcode: '8991001000021',
      name: 'Obeng Set',
      category: 'Peralatan',
      unit: 'SET',
      stock: 42,
      minimumStock: 10,
      location: 'B-02-01',
    ),
    ProductModel(
      id: '4',
      sku: 'BBK-001',
      barcode: '8991001000031',
      name: 'Baut  M8',
      category: 'Bahan Baku',
      unit: 'BOX',
      stock: 4,
      minimumStock: 5,
      location: 'C-01-01',
    ),
    ProductModel(
      id: '5',
      sku: 'KMS-001',
      barcode: '8991001000041',
      name: 'Kardus Sedang',
      category: 'Kemasan',
      unit: 'PCS',
      stock: 300,
      minimumStock: 50,
      location: 'D-01-01',
    ),
  ].obs;

  List<ProductModel> get filteredProducts {
    final query = searchQuery.value.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          selectedCategory.value == 'Semua' ||
          product.category == selectedCategory.value;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get lowStockCount => products.where((p) => p.isLowStock).length;

  @override
  void onInit() {
    super.onInit();
  }

  void updateSearch(String value) => searchQuery.value = value;

  void showProductForm({ProductModel? product}) {
    Get.dialog(
      _ProductFormDialog(controller: this, product: product),
      barrierDismissible: false,
    );
  }

  void addCategory(String value) {
    final name = value.trim();
    if (name.isEmpty) return;
    if (categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      Get.snackbar('Kategori sudah ada', 'Gunakan nama kategori yang berbeda.');
      return;
    }
    categories.add(name);
  }

  void renameCategory(String oldName, String newName) {
    final name = newName.trim();
    if (name.isEmpty ||
        categories.any(
          (c) => c.toLowerCase() == name.toLowerCase() && c != oldName,
        ))
      return;
    final index = categories.indexOf(oldName);
    if (index < 0) return;
    categories[index] = name;
    for (var i = 0; i < products.length; i++) {
      final p = products[i];
      if (p.category == oldName) {
        products[i] = ProductModel(
          id: p.id,
          sku: p.sku,
          barcode: p.barcode,
          name: p.name,
          category: name,
          unit: p.unit,
          stock: p.stock,
          minimumStock: p.minimumStock,
          location: p.location,
        );
      }
    }
    if (selectedCategory.value == oldName) selectedCategory.value = name;
  }

  void deleteCategory(String name) {
    if (products.any((p) => p.category == name)) {
      Get.snackbar(
        'Tidak dapat menghapus',
        'Kategori masih digunakan oleh produk.',
      );
      return;
    }
    categories.remove(name);
    if (selectedCategory.value == name) selectedCategory.value = 'Semua';
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void changeTab(int index) {
    selectedTab.value = index;
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.controller, this.product});

  final ProductsController controller;
  final ProductModel? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController barcode;
  late final TextEditingController stock;
  late final TextEditingController minimum;
  late final TextEditingController unit;

  String? selectedCategory;

  @override
  void initState() {
    super.initState();

    final product = widget.product;
    final categories = widget.controller.categories;

    name = TextEditingController(text: product?.name ?? '');
    sku = TextEditingController(text: product?.sku ?? '');
    barcode = TextEditingController(text: product?.barcode ?? '');
    stock = TextEditingController(text: product?.stock.toString() ?? '0');
    minimum = TextEditingController(
      text: product?.minimumStock.toString() ?? '0',
    );
    unit = TextEditingController(text: product?.unit ?? 'PCS');

    selectedCategory = categories.contains(product?.category)
        ? product?.category
        : (categories.isNotEmpty ? categories.first : null);
  }

  void saveProduct() {
    final controller = widget.controller;
    final oldProduct = widget.product;

    if (name.text.trim().isEmpty ||
        sku.text.trim().isEmpty ||
        barcode.text.trim().isEmpty ||
        selectedCategory == null) {
      Get.snackbar(
        'Data belum lengkap',
        'Nama, SKU, barcode, dan kategori wajib diisi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final stockValue = int.tryParse(stock.text.trim());
    final minimumValue = int.tryParse(minimum.text.trim());

    if (stockValue == null ||
        minimumValue == null ||
        stockValue < 0 ||
        minimumValue < 0) {
      Get.snackbar(
        'Input tidak valid',
        'Stok dan minimum stok harus berupa angka nol atau lebih.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final newProduct = ProductModel(
      id: oldProduct?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      sku: sku.text.trim(),
      barcode: barcode.text.trim(),
      category: selectedCategory!,
      unit: unit.text.trim().isEmpty ? 'PCS' : unit.text.trim().toUpperCase(),
      stock: stockValue,
      minimumStock: minimumValue,
      location: oldProduct?.location ?? '-',
    );

    if (oldProduct == null) {
      controller.products.add(newProduct);
    } else {
      final index = controller.products.indexWhere(
        (p) => p.id == oldProduct.id,
      );

      if (index >= 0) {
        controller.products[index] = newProduct;
      }
    }

    Get.back();

    Get.snackbar(
      'Berhasil',
      oldProduct == null
          ? 'Produk berhasil ditambahkan.'
          : 'Produk berhasil diperbarui.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: false)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    barcode.dispose();
    stock.dispose();
    minimum.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final categories = widget.controller.categories.toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Edit Produk' : 'Tambah Produk',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      buildField(name, 'Nama produk'),
                      buildField(sku, 'SKU'),
                      buildField(barcode, 'Barcode'),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField<String>(
                          value: categories.contains(selectedCategory)
                              ? selectedCategory
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                          items: categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(
                                category,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                      ),

                      buildField(stock, 'Stok', numeric: true),
                      buildField(minimum, 'Minimum stok', numeric: true),
                      buildField(unit, 'Satuan'),
                    ],
                  ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: saveProduct,
                      child: const Text('Simpan'),
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
