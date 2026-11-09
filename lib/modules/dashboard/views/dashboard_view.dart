import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../application/constants/app_strings.dart';
import '../../../common/widgets/app_header.dart';
import '../../../common/widgets/app_status_badge.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_drawer.dart';
import '../widgets/dashboard_stat_grid.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/recent_activity_tile.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: DashboardDrawer(controller: controller),
    appBar: AppBar(title: const Text(AppStrings.dashboard, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), actions: [IconButton(onPressed: controller.showNotifications, icon: const Icon(Icons.notifications_none_rounded, size: 25)), const SizedBox(width: 5)]),
    body: RefreshIndicator(color: AppColors.primary, onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 450)), child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
      const Row(children: [Expanded(child: AppHeader(name: 'Admin', role: 'Warehouse Staff')), AppStatusBadge(label: 'Online')]),
      const SizedBox(height: 18),
      _WarehouseSelector(controller: controller),
      const SizedBox(height: 18),
      const _SectionTitle('Ringkasan Inventaris'),
      const SizedBox(height: 11),
      const DashboardStatGrid(),
      const SizedBox(height: 23),
      const _SectionTitle('Menu Cepat'),
      const SizedBox(height: 11),
      Row(children: [
        QuickActionTile(title: 'Penerimaan', icon: Icons.move_to_inbox_outlined, color: AppColors.primary, onTap: () => controller.openModule('Penerimaan Barang')),
        QuickActionTile(title: 'Pengeluaran', icon: Icons.outbox_outlined, color: AppColors.danger, onTap: () => controller.openModule('Pengeluaran Barang')),
        QuickActionTile(title: 'Transfer', icon: Icons.swap_horiz_rounded, color: AppColors.info, onTap: () => controller.openModule('Transfer Barang')),
        QuickActionTile(title: 'Opname', icon: Icons.fact_check_outlined, color: AppColors.success, onTap: () => controller.openModule('Stock Opname')),
      ]),
      const SizedBox(height: 23),
      Row(children: [const Expanded(child: _SectionTitle('Aktivitas Terbaru')), TextButton(onPressed: () => controller.openModule('Riwayat Aktivitas'), child: const Text('Lihat Semua', style: TextStyle(color: AppColors.primary, fontSize: 12)))]),
      const SizedBox(height: 4),
      const RecentActivityTile(title: 'Penerimaan Barang', reference: 'PO-001245', warehouse: 'Gudang Utama', time: '10:18', icon: Icons.move_to_inbox_outlined, color: AppColors.success),
      const RecentActivityTile(title: 'Pengeluaran Barang', reference: 'DO-000832', warehouse: 'Gudang Surabaya', time: '09:42', icon: Icons.outbox_outlined, color: AppColors.danger),
      const RecentActivityTile(title: 'Transfer Barang', reference: 'TR-000126', warehouse: 'Gudang Utama → Jakarta', time: '09:10', icon: Icons.swap_horiz_rounded, color: AppColors.info),
    ])),
  );
}

class _WarehouseSelector extends StatelessWidget {
  const _WarehouseSelector({required this.controller});
  final DashboardController controller;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.warehouse_outlined, color: AppColors.primary, size: 21), const SizedBox(width: 10), const Expanded(child: Text('Gudang Aktif', style: TextStyle(fontSize: 12, color: Colors.black54))), Obx(() => DropdownButtonHideUnderline(child: DropdownButton<String>(value: controller.selectedWarehouse.value, icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.charcoal), style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w700, fontSize: 12), items: controller.warehouses.map((warehouse) => DropdownMenuItem(value: warehouse, child: Text(warehouse))).toList(), onChanged: (value) { if (value != null) controller.selectedWarehouse.value = value; }))) ]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal));
}
