import 'package:get/get.dart';
import '../../../application/routes/app_routes.dart';

class DashboardController extends GetxController {
  final selectedWarehouse = 'Gudang Utama'.obs;
  final warehouses = <String>['Gudang Utama', 'Gudang Surabaya', 'Gudang Jakarta'];

  void openModule(String title) {
    if (title == 'Gudang & Lokasi') {
      Get.toNamed(AppRoutes.warehouse);
      return;
    }
    if (title == 'Penerimaan Barang') {
      Get.toNamed(AppRoutes.receiving);
      return;
    }
    if (title == 'Pengeluaran Barang') {
      Get.toNamed(AppRoutes.issuing);
      return;
    }
    if (title == 'Transfer Barang') {
      Get.toNamed(AppRoutes.transfers);
      return;
    }
    if (title == 'Stock Opname') {
      Get.toNamed(AppRoutes.stockOpname);
      return;
    }
    if (title == 'Produk & Kategori') {
      Get.toNamed(AppRoutes.products);
      return;
    }
    Get.toNamed(AppRoutes.module, arguments: title);
  }
  void logout() => Get.offAllNamed(AppRoutes.login);
  void showNotifications() => Get.snackbar('Notifikasi', 'Belum ada notifikasi baru.');
}
