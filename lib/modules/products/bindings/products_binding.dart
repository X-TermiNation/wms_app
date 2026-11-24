import 'package:get/get.dart';
import '../controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';

class ProductsBinding extends Bindings {
  @override
  void dependencies() {
    // Keep the demo/master data controllers alive while navigating between
    // operational pages so the product list is not recreated unexpectedly.
    if (!Get.isRegistered<WarehouseController>()) {
      Get.put<WarehouseController>(WarehouseController(), permanent: true);
    }
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
  }
}
