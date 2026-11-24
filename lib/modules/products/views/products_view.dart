import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../common/widgets/document_widgets.dart';
import '../../../common/widgets/label_widgets.dart';
import '../../../common/widgets/product_picker.dart';
import '../../../common/widgets/scan_widgets.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../../../services/scanner/scanner_service.dart';
import '../controllers/products_controller.dart';
import '../models/product_model.dart';

/// Lookup item (hanya baca). Registrasi item / SKU / barcode / kategori
/// dilakukan di aplikasi Desktop.
class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProductsController controller;
  ScanRegistration? _scan;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ProductsController>();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) controller.changeTab(_tabController.index);
    });
    _scan = ScannerService.instance.register(_onScan, label: 'Produk');
  }

  Future<void> _onScan(String code) async {
    try {
      final result = await InventoryRepository.instance.scan(code, warehouseId: controller.warehouseId);
      if (result.type == ScanType.product) {
        ScanFeedback.success();
        final product = controller.products.firstWhereOrNull((p) => p.id == result.product!.id);
        if (product != null) {
          if (_tabController.index != 0) _tabController.animateTo(0);
          await showProductDetail(controller, product, gs1: result.gs1);
        }
      } else if (result.type == ScanType.batch) {
        ScanFeedback.success();
        final product = controller.products.firstWhereOrNull((p) => p.id == result.batch!.productId);
        if (product != null) await showProductDetail(controller, product);
      } else {
        ScanFeedback.error();
        Get.snackbar('Lookup produk', 'Yang discan adalah lokasi ${result.location!.code}.', snackPosition: SnackPosition.BOTTOM);
      }
    } on ApiException catch (e) {
      ScanFeedback.error();
      if (e.statusCode == 404) {
        await showNotRegistered(e.message);
      } else {
        Get.snackbar('Scan gagal', e.message, snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  @override
  void dispose() {
    _scan?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Lookup Produk', style: TextStyle(fontWeight: FontWeight.w700)),
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black,
        indicatorColor: AppColors.primary,
        tabs: const [Tab(text: 'Produk'), Tab(text: 'Kategori')],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [_ProductsTab(controller: controller), _CategoriesTab(controller: controller)],
    ),
  );
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.controller});
  final ProductsController controller;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(children: [
        const ScanPromptCard(title: 'Scan barcode item / batch', subtitle: 'Menampilkan info item & stok per batch di gudang aktif'),
        const SizedBox(height: 8),
        AppSearchField(hint: 'Cari nama, SKU, atau barcode...', controller: controller.searchController, onChanged: controller.updateSearch),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: Obx(() => ListView(
            scrollDirection: Axis.horizontal,
            children: ['Semua', ...controller.categories].map((category) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(category, style: const TextStyle(fontSize: 11)),
                selected: controller.selectedCategory.value == category,
                selectedColor: AppColors.softOrange,
                onSelected: (_) => controller.selectedCategory.value = category,
              ),
            )).toList(),
          )),
        ),
      ]),
    ),
    Expanded(
      child: Obx(() {
        final items = controller.filteredProducts;
        if (items.isEmpty && controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: items.isEmpty ? 1 : items.length,
            itemBuilder: (context, i) => items.isEmpty
                ? const EmptyState(message: 'Produk tidak ditemukan.')
                : _ProductCard(product: items[i], onTap: () => showProductDetail(controller, items[i])),
          ),
        );
      }),
    ),
  ]);
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});
  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              if (product.requiresQc) const _Tag('QC', AppColors.warning),
              if (product.hasExpiry) const _Tag('ED', AppColors.info),
              if (!product.isActive) const _Tag('NONAKTIF', Colors.grey),
            ]),
            const SizedBox(height: 3),
            Text('${product.sku} • ${product.category} • ${product.barcode}', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(children: [
              _Stock('Available', product.availableStock, product.unit, product.isLowStock ? AppColors.danger : AppColors.success),
              _Stock('QC', product.qcStock, product.unit, AppColors.warning),
              _Stock('Min.', product.minimumStock, product.unit, Colors.black45),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _Stock extends StatelessWidget {
  const _Stock(this.label, this.value, this.unit, this.color);
  final String label, unit;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
      Text('$value $unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
  );
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.controller});
  final ProductsController controller;

  @override
  Widget build(BuildContext context) => Obx(() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: [
      const Text('Kategori dikelola melalui aplikasi Desktop.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 10),
      ...controller.categories.map((category) {
        final count = controller.products.where((p) => p.category == category).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.category_outlined, color: AppColors.primary),
            const SizedBox(width: 11),
            Expanded(child: Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Text('$count produk', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        );
      }),
    ],
  ));
}

/// Detail produk + stok per batch / lokasi / status di gudang aktif.
Future<void> showProductDetail(ProductsController c, ProductModel p, {Gs1Data? gs1}) async {
  List<InventoryBalance> stock = const [];
  try {
    stock = await c.stockDetail(p.id);
  } catch (_) {}
  await showDetailSheet(
    title: p.name,
    children: [
      if (p.imageUrl != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(p.imageUrl!, height: 140, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
      InfoRow('SKU', p.sku, bold: true),
      InfoRow('Barcode', p.barcode),
      InfoRow('Kategori', p.category),
      InfoRow('Satuan', p.unit),
      InfoRow('Wajib QC', p.requiresQc ? 'Ya' : 'Tidak'),
      InfoRow('Ada expiry', p.hasExpiry ? 'Ya' : 'Tidak'),
      if (gs1 != null) InfoRow('GS1', 'GTIN ${gs1.gtin}${gs1.lot != null ? ' • lot ${gs1.lot}' : ''}${gs1.expiryDate != null ? ' • ED ${formatDate(gs1.expiryDate)}' : ''}'),
      SectionTitle('Stok di ${WarehouseContext.instance.activeName}'),
      if (stock.isEmpty) const Text('Tidak ada stok di gudang ini.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ...stock.map((b) => Padding(padding: const EdgeInsets.only(bottom: 7), child: BalanceTile(balance: b))),
    ],
    actions: [
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: () => printFromBackend([('PRODUCT', p.id)], title: 'Label Produk'),
        icon: const Icon(Icons.print_rounded),
        label: const Text('Cetak Label Produk'),
      ),
    ],
  );
}
