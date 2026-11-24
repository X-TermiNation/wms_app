import 'package:get/get.dart';
import '../controllers/warehouse_controller.dart';

class WarehouseBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<WarehouseController>()) {
      Get.put<WarehouseController>(WarehouseController(), permanent: true);
    }
  }
}
