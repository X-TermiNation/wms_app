import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../data/models/inventory_models.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/warehouse_context.dart';
import '../models/product_model.dart';
import '../models/product_stock_lot_model.dart';

/// Master item untuk lookup di SUNMI (hanya baca).
/// Registrasi item, SKU, barcode, dan kategori dikelola dari aplikasi Desktop.
class ProductsController extends GetxController {
  final _api = ApiClient.instance;

  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final selectedTab = 0.obs;
  final selectedCategory = 'Semua'.obs;
  final isLoading = false.obs;

  final categories = <String>[].obs;
  final products = <ProductModel>[].obs;

  String get warehouseId => WarehouseContext.instance.activeId.value;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    // Stok per gudang ikut berubah saat gudang aktif diganti.
    ever(WarehouseContext.instance.activeId, (_) => reloadProductsSilently());
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      await Future.wait([fetchCategories(), fetchProducts()]);
    } catch (e) {
      showApiError(e, title: 'Gagal memuat produk');
    } finally {
      isLoading.value = false;
    }
  }

  /// Daftar produk dengan stok AVAILABLE / QC untuk gudang aktif.
  Future<void> fetchProducts() async {
    final list = await _api.getList('/products', ProductModel.fromJson,
        query: {'warehouseId': warehouseId.isEmpty ? null : warehouseId});
    products.assignAll(list);
  }

  /// Muat ulang produk tanpa melempar error (dipakai setelah transaksi stok).
  Future<void> reloadProductsSilently() async {
    try {
      await fetchProducts();
    } catch (_) {}
  }

  Future<void> fetchCategories() async {
    final data = await _api.get('/categories') as List;
    categories.assignAll(data.map((e) => e['name'] as String));
    if (selectedCategory.value != 'Semua' && !categories.contains(selectedCategory.value)) {
      selectedCategory.value = 'Semua';
    }
  }

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
          product.barcode.toLowerCase().contains(query) ||
          product.location.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  /// Ketersediaan stok produk di gudang (dipakai form issuing/transfer).
  Future<ProductAvailabilityModel> availability(String productId, String warehouseId, {String? lotId}) async {
    final data = await _api.get('/products/$productId/availability', query: {'warehouseId': warehouseId, 'lotId': lotId});
    return ProductAvailabilityModel.fromJson(data as Map<String, dynamic>);
  }

  /// Sebaran stok produk per batch x lokasi x status di gudang aktif.
  Future<List<InventoryBalance>> stockDetail(String productId) =>
      InventoryRepository.instance.balances(warehouseId: warehouseId, productId: productId);

  int get lowStockCount => products.where((p) => p.isLowStock).length;

  void updateSearch(String value) => searchQuery.value = value;

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void changeTab(int index) {
    selectedTab.value = index;
  }
}
