
import 'package:get/get.dart';
import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../controllers/receiving_controller.dart';

class ReceivingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
    if (!Get.isRegistered<WarehouseController>()) {
      Get.put<WarehouseController>(WarehouseController(), permanent: true);
    }
    Get.lazyPut<ReceivingController>(() => ReceivingController());
  }
}
