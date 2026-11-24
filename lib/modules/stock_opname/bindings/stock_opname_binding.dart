import 'package:get/get.dart';

import '../../products/controllers/products_controller.dart';
import '../../warehouse/controllers/warehouse_controller.dart';
import '../controllers/stock_opname_controller.dart';

class StockOpnameBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProductsController>()) {
      Get.put<ProductsController>(ProductsController(), permanent: true);
    }
    if (!Get.isRegistered<WarehouseController>()) {
      Get.put<WarehouseController>(WarehouseController(), permanent: true);
    }
    if (!Get.isRegistered<StockOpnameController>()) {
      Get.lazyPut<StockOpnameController>(() => StockOpnameController());
    }
  }
}
