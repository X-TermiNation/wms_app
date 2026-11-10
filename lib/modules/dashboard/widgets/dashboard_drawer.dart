import 'package:flutter/material.dart';
import '../../../application/constants/app_colors.dart';
import '../../../application/constants/app_strings.dart';
import '../controllers/dashboard_controller.dart';

class DashboardDrawer extends StatelessWidget {
  const DashboardDrawer({super.key, required this.controller});
  final DashboardController controller;

  static const _mainItems = <_DrawerItem>[
    _DrawerItem('Dashboard', Icons.home_rounded),
    _DrawerItem('Produk & Kategori', Icons.inventory_2_outlined),
    _DrawerItem('Gudang & Lokasi', Icons.warehouse_outlined),
    _DrawerItem('Penerimaan Barang', Icons.move_to_inbox_outlined),
    _DrawerItem('Pengeluaran Barang', Icons.outbox_outlined),
    _DrawerItem('Transfer Barang', Icons.swap_horiz_rounded),
    _DrawerItem('Stock Opname', Icons.fact_check_outlined),
  ];
  static const _reportItems = <_DrawerItem>[
    _DrawerItem('Laporan Inventaris', Icons.bar_chart_rounded),
    _DrawerItem('Riwayat Aktivitas', Icons.history_rounded),
  ];
  static const _settingItems = <_DrawerItem>[
    _DrawerItem('Pengguna & Role', Icons.people_outline_rounded),
    _DrawerItem('Pengaturan', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            color: AppColors.primary,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Warehouse Staff',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 9),
              children: [
                ..._mainItems.map((item) => _buildItem(context, item)),
                const Divider(height: 17),
                const _GroupLabel('LAPORAN'),
                ..._reportItems.map((item) => _buildItem(context, item)),
                const Divider(height: 17),
                const _GroupLabel('PENGATURAN'),
                ..._settingItems.map((item) => _buildItem(context, item)),
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 21,
                  ),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: controller.logout,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              '${AppStrings.appName} • ${AppStrings.version}',
              style: TextStyle(color: Colors.black38, fontSize: 10),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildItem(BuildContext context, _DrawerItem item) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    child: ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Icon(item.icon, color: AppColors.charcoal, size: 21),
      title: Text(
        item.title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.charcoal,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: Colors.black38,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      onTap: () {
        Navigator.pop(context);
        if (item.title != 'Dashboard') controller.openModule(item.title);
      },
    ),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 3, 18, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.black45,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

class _DrawerItem {
  const _DrawerItem(this.title, this.icon);
  final String title;
  final IconData icon;
}
