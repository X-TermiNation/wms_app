import 'package:get/get.dart';

import '../controllers/qc_inspection_controller.dart';
import '../controllers/qc_queue_controller.dart';

class QcInspectionBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut<QcInspectionController>(() => QcInspectionController());
}

class QcQueueBinding extends Bindings {
  QcQueueBinding(this.mode);
  final QcQueueMode mode;

  @override
  void dependencies() => Get.lazyPut<QcQueueController>(() => QcQueueController(mode), tag: mode.name);
}
