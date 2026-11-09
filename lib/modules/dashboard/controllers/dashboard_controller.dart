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
    if (title == 'Produk & Kategori') {
      Get.toNamed(AppRoutes.products);
      return;
    }
    Get.toNamed(AppRoutes.module, arguments: title);
  }
  void logout() => Get.offAllNamed(AppRoutes.login);
  void showNotifications() => Get.snackbar('Notifikasi', 'Belum ada notifikasi baru.');
}
