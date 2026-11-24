import 'package:get/get.dart';

import '../controllers/stock_move_controller.dart';

class StockMoveBinding extends Bindings {
  StockMoveBinding(this.mode);
  final StockMoveMode mode;

  @override
  void dependencies() {
    Get.lazyPut<StockMoveController>(() => StockMoveController(mode), tag: mode.name);
  }
}
