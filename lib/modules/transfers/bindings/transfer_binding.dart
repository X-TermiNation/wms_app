import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../controllers/transfer_controller.dart';

class TransferBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
    if (!Get.isRegistered<WarehouseController>()) {
      Get.put<WarehouseController>(WarehouseController(), permanent: true);
    }
    if (!Get.isRegistered<TransferController>()) {
      Get.lazyPut<TransferController>(() => TransferController());
    }
  }
}
