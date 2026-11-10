import 'package:get/get.dart';
import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../controllers/issuing_controller.dart';

class IssuingBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.lazyPut<ProductsController>(() => ProductsController());
    }
    if (!Get.isRegistered<WarehouseController>()) {
      Get.lazyPut<WarehouseController>(() => WarehouseController());
    }
    Get.lazyPut<IssuingController>(() => IssuingController());
  }
}
