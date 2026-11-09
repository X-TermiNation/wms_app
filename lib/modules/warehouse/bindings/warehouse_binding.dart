import 'package:get/get.dart';
import '../controllers/warehouse_controller.dart';

class WarehouseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WarehouseController>(() => WarehouseController());
  }
}
