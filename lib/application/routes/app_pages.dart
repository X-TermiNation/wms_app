import 'package:get/get.dart';
import '../../modules/authentication/bindings/authentication_binding.dart';
import '../../modules/authentication/views/login_view.dart';
import '../../modules/dashboard/bindings/dashboard_binding.dart';
import '../../modules/dashboard/views/dashboard_view.dart';
import '../../common/widgets/module_placeholder_view.dart';
import 'app_routes.dart';
import '../../modules/products/bindings/products_binding.dart';
import '../../modules/products/views/products_view.dart';
import '../../modules/warehouse/bindings/warehouse_binding.dart';
import '../../modules/warehouse/views/warehouse_view.dart';

abstract final class AppPages {
  static final pages = <GetPage>[
    GetPage(name: AppRoutes.login, page: () => const LoginView(), binding: AuthenticationBinding()),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardView(), binding: DashboardBinding()),
    GetPage(name: AppRoutes.module, page: () => ModulePlaceholderView(title: Get.arguments as String? ?? 'Modul')),
    GetPage(name: AppRoutes.products, page: () => const ProductsView(), binding: ProductsBinding()),
    GetPage(name: AppRoutes.warehouse, page: () => const WarehouseView(), binding: WarehouseBinding()),
  ];
}
