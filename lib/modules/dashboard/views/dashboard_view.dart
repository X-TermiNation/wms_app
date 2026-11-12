import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../application/constants/app_strings.dart';
import '../controllers/dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  static const _menus = <_HomeMenu>[
    _HomeMenu(
      'Receiving',
      'Barang masuk',
      Icons.move_to_inbox_outlined,
      'Penerimaan Barang',
    ),
    _HomeMenu(
      'Issuing',
      'Barang keluar',
      Icons.outbox_outlined,
      'Pengeluaran Barang',
    ),
    _HomeMenu(
      'Stock Transfer',
      'Pindah antar gudang',
      Icons.swap_horiz_rounded,
      'Transfer Barang',
    ),
    _HomeMenu(
      'Stock Opname',
      'Pemeriksaan stok',
      Icons.fact_check_outlined,
      'Stock Opname',
    ),
    _HomeMenu(
      'Products',
      'Data barang',
      Icons.inventory_2_outlined,
      'Produk & Kategori',
    ),
    _HomeMenu(
      'Warehouse',
      'Gudang dan lokasi',
      Icons.warehouse_outlined,
      'Gudang & Lokasi',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      titleSpacing: 18,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MyWMS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            'Operational Homepage',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Keluar',
          onPressed: () => _confirmLogout(),
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 5),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 350)),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.softOrange,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat bekerja!',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Pilih aktivitas gudang yang ingin dilakukan.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _WarehouseSelector(controller: controller),
            const SizedBox(height: 22),
            const Text(
              'Menu Operasional',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 11),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _menus.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                childAspectRatio: 1.32,
              ),
              itemBuilder: (context, index) {
                final item = _menus[index];
                return _HomeMenuCard(
                  item: item,
                  onTap: () => controller.openModule(item.route),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.softOrange,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.darkOrange,
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Gunakan tombol scan fisik SUNMI saat memilih atau memasukkan barcode produk.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.darkOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '${AppStrings.appName} • ${AppStrings.version}',
                style: const TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _confirmLogout() {
    Get.dialog(
      AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text('Kamu akan kembali ke halaman login.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: controller.logout,
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _WarehouseSelector extends StatelessWidget {
  const _WarehouseSelector({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warehouse_outlined,
          color: AppColors.primary,
          size: 21,
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Gudang aktif',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Obx(
          () => DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.selectedWarehouse.value,
              isExpanded: false,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              items: controller.warehouses
                  .map(
                    (w) => DropdownMenuItem(
                      value: w,
                      child: Text(w, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.selectedWarehouse.value = value;
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _HomeMenu {
  const _HomeMenu(this.title, this.subtitle, this.icon, this.route);
  final String title, subtitle, route;
  final IconData icon;
}

class _HomeMenuCard extends StatelessWidget {
  const _HomeMenuCard({required this.item, required this.onTap});

  final _HomeMenu item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.softOrange,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 21),
              ),

              const SizedBox(height: 7),

              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.2,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
