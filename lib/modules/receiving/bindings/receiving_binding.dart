
import 'package:get/get.dart';
import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../controllers/receiving_controller.dart';

class ReceivingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.lazyPut<ProductsController>(() => ProductsController());
    }
    if (!Get.isRegistered<WarehouseController>()) {
      Get.lazyPut<WarehouseController>(() => WarehouseController());
    }
    Get.lazyPut<ReceivingController>(() => ReceivingController());
  }
}
