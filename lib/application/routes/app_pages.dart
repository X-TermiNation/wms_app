import 'package:get/get.dart';
import '../../common/widgets/module_placeholder_view.dart';
import '../../modules/authentication/bindings/authentication_binding.dart';
import '../../modules/authentication/views/login_view.dart';
import '../../modules/dashboard/bindings/dashboard_binding.dart';
import '../../modules/dashboard/views/dashboard_view.dart';
import '../../modules/history/history_module.dart';
import '../../modules/issuing/bindings/issuing_binding.dart';
import '../../modules/issuing/views/issuing_view.dart';
import '../../modules/products/bindings/products_binding.dart';
import '../../modules/products/views/products_view.dart';
import '../../modules/qc/bindings/qc_binding.dart';
import '../../modules/qc/controllers/qc_queue_controller.dart';
import '../../modules/qc/views/qc_inspection_view.dart';
import '../../modules/qc/views/qc_queue_view.dart';
import '../../modules/receiving/bindings/receiving_binding.dart';
import '../../modules/receiving/views/receiving_view.dart';
import '../../modules/shipping/views/packing_pages.dart';
import '../../modules/shipping/views/shipment_pages.dart';
import '../../modules/stock_move/bindings/stock_move_binding.dart';
import '../../modules/stock_move/controllers/stock_move_controller.dart';
import '../../modules/stock_move/views/stock_move_view.dart';
import '../../modules/stock_opname/bindings/stock_opname_binding.dart';
import '../../modules/stock_opname/views/stock_opname_view.dart';
import '../../modules/transfers/bindings/transfer_binding.dart';
import '../../modules/transfers/views/transfer_view.dart';
import '../../modules/warehouse/bindings/warehouse_binding.dart';
import '../../modules/warehouse/views/warehouse_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final pages = <GetPage>[
    GetPage(name: AppRoutes.login, page: () => const LoginView(), binding: AuthenticationBinding()),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardView(), binding: DashboardBinding()),
    GetPage(name: AppRoutes.module, page: () => ModulePlaceholderView(title: Get.arguments as String? ?? 'Modul')),
    // Lookup (hanya baca)
    GetPage(name: AppRoutes.products, page: () => const ProductsView(), binding: ProductsBinding()),
    GetPage(name: AppRoutes.warehouse, page: () => const WarehouseView(), binding: WarehouseBinding()),
    // Operasional
    GetPage(name: AppRoutes.receiving, page: () => const ReceivingView(), binding: ReceivingBinding()),
    GetPage(name: AppRoutes.putaway, page: () => const StockMoveView(mode: StockMoveMode.putaway), binding: StockMoveBinding(StockMoveMode.putaway)),
    GetPage(name: AppRoutes.qcTransfer, page: () => const StockMoveView(mode: StockMoveMode.qcTransfer), binding: StockMoveBinding(StockMoveMode.qcTransfer)),
    GetPage(name: AppRoutes.qcInspection, page: () => const QcInspectionView(), binding: QcInspectionBinding()),
    GetPage(name: AppRoutes.qcRelease, page: () => const StockMoveView(mode: StockMoveMode.qcRelease), binding: StockMoveBinding(StockMoveMode.qcRelease)),
    GetPage(name: AppRoutes.qcHold, page: () => const QcQueueView(mode: QcQueueMode.hold), binding: QcQueueBinding(QcQueueMode.hold)),
    GetPage(name: AppRoutes.qcRejected, page: () => const QcQueueView(mode: QcQueueMode.rejected), binding: QcQueueBinding(QcQueueMode.rejected)),
    GetPage(name: AppRoutes.issuing, page: () => const IssuingView(), binding: IssuingBinding()),
    // Pengiriman: picking (issuing) -> packing -> loading -> dispatch -> POD
    GetPage(name: AppRoutes.packing, page: () => const PackingQueuePage()),
    GetPage(name: AppRoutes.shipments, page: () => const ShipmentListPage()),
    GetPage(name: AppRoutes.transfers, page: () => const TransferView(), binding: TransferBinding()),
    GetPage(name: AppRoutes.stockOpname, page: () => const StockOpnameView(), binding: StockOpnameBinding()),
    GetPage(name: AppRoutes.history, page: () => const HistoryView(), binding: HistoryBinding()),
  ];
}
