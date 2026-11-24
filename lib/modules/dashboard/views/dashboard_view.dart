import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../application/constants/app_colors.dart';
import '../../../application/constants/app_strings.dart';
import '../../../application/routes/app_routes.dart';
import '../../../services/api/api_client.dart';
import '../../../services/printing/printer_settings_page.dart';
import '../controllers/dashboard_controller.dart';

class _Menu {
  const _Menu(this.title, this.subtitle, this.icon, this.route, [this.badge]);
  final String title, subtitle, route;
  final IconData icon;
  final int Function(OperationalSummary s)? badge;
}

/// Dashboard operasional SUNMI: hanya informasi yang dibutuhkan staff gudang.
class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  static final _menus = <_Menu>[
    _Menu(
      'Receiving',
      'Barang masuk & batch',
      Icons.move_to_inbox_outlined,
      AppRoutes.receiving,
      (s) => s.openReceivings + s.openInboundDocuments,
    ),
    _Menu(
      'Putaway',
      'Receiving→rak',
      Icons.move_down_rounded,
      AppRoutes.putaway,
      (s) => s.putawayBatches,
    ),
    _Menu(
      'QC Transfer',
      'Pindah ke area QC',
      Icons.science_outlined,
      AppRoutes.qcTransfer,
    ),
    _Menu(
      'QC Inspection',
      'PASS / FAIL / HOLD',
      Icons.fact_check_rounded,
      AppRoutes.qcInspection,
      (s) => s.qcPendingBatches,
    ),
    _Menu(
      'QC Release',
      'QC PASS → rak',
      Icons.verified_outlined,
      AppRoutes.qcRelease,
      (s) => s.qcPassedBatches,
    ),
    _Menu(
      'QC Hold',
      'Recheck barang hold',
      Icons.pause_circle_outline_rounded,
      AppRoutes.qcHold,
      (s) => s.qcHoldBatches,
    ),
    _Menu(
      'QC Rejected',
      'Retur / scrap / rework',
      Icons.block_rounded,
      AppRoutes.qcRejected,
      (s) => s.qcRejectedBatches,
    ),
    _Menu(
      'Issuing',
      'Barang keluar (FEFO)',
      Icons.outbox_outlined,
      AppRoutes.issuing,
      (s) => s.openIssuings + s.openOutboundDocuments,
    ),
    _Menu(
      'Packing',
      'Kemas ke koli + label',
      Icons.inventory_2_outlined,
      AppRoutes.packing,
      (s) => s.packingQueue,
    ),
    _Menu(
      'Loading',
      'Muat, dispatch, POD',
      Icons.local_shipping_outlined,
      AppRoutes.shipments,
      (s) => s.packedReady + s.shipmentsLoading,
    ),
    _Menu(
      'Transfer',
      'Antar gudang/cabang',
      Icons.swap_horiz_rounded,
      AppRoutes.transfers,
      (s) => s.inboundTransfers,
    ),
    _Menu(
      'Stock Opname',
      'Hitung per lokasi',
      Icons.inventory_rounded,
      AppRoutes.stockOpname,
      (s) => s.draftOpnames,
    ),
    _Menu(
      'Riwayat',
      'Jejak transaksi & batch',
      Icons.history_rounded,
      AppRoutes.history,
    ),
    _Menu(
      'Lookup Produk',
      'Info item & stok',
      Icons.qr_code_scanner_rounded,
      AppRoutes.products,
    ),
    _Menu(
      'Lokasi',
      'Gudang, rak, area QC',
      Icons.warehouse_outlined,
      AppRoutes.warehouse,
    ),
  ];

  /// Skala font sistem dibatasi 1.3x di dashboard agar kartu menu tetap rapi di semua perangkat.
  static const maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: maxTextScale)),
      child: _scaffold(),
    );
  }

  Widget _scaffold() => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      titleSpacing: 18,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MyWMS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Warehouse Operation',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      actions: [
        const _ConnectionChip(),
        IconButton(
          tooltip: 'Pengaturan printer',
          onPressed: () => Get.to(() => const PrinterSettingsPage()),
          icon: const Icon(Icons.print_outlined),
        ),
        IconButton(
          tooltip: 'Keluar',
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _WarehouseCard(controller: controller),
            const SizedBox(height: 12),
            _StatsRow(controller: controller),
            const SizedBox(height: 16),
            const Text(
              'Menu Operasional',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                // Kolom mengikuti lebar layar (min. ~96 dp per kartu): 2 di layar sangat sempit,
                // 3 di SUNMI/HP, lebih banyak di tablet / landscape.
                const spacing = 9.0;
                final columns = ((constraints.maxWidth + spacing) / (_MenuTile.minWidth + spacing)).floor().clamp(2, 6);
                return Obx(() {
                  final s = controller.summary.value;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _menus.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      mainAxisExtent: _MenuTile.heightFor(MediaQuery.textScalerOf(context)),
                    ),
                    itemBuilder: (_, i) {
                      final m = _menus[i];
                      final badge = s == null || m.badge == null ? 0 : m.badge!(s);
                      return _MenuTile(
                        menu: m,
                        badge: badge,
                        onTap: () => controller.open(m.route),
                      );
                    },
                  );
                });
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      'Gunakan tombol scan fisik SUNMI. Master item, cabang, dan laporan manajemen dikelola dari aplikasi Desktop.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.darkOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip();

  @override
  Widget build(BuildContext context) => Obx(() {
    final status = ApiClient.instance.connection.value;
    final (label, color) = switch (status) {
      ConnectionStatus.online => ('Online', const Color(0xFF7CE0A9)),
      ConnectionStatus.offline => ('Offline', const Color(0xFFFFB4B4)),
      ConnectionStatus.unknown => ('…', Colors.white70),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  });
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Obx(() {
      final ctx = controller.ctx;
      final list = ctx.warehouses;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Halo, ${controller.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.softOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ctx.role.value.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const Text(
              'Akun ini belum memiliki akses gudang. Hubungi administrator.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            )
          else if (list.length == 1)
            Row(
              children: [
                const Icon(
                  Icons.warehouse_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${list.first.name} (${list.first.code})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey(ctx.activeId.value),
              initialValue: ctx.activeId.value.isEmpty
                  ? null
                  : ctx.activeId.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Gudang aktif',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
              ),
              items: list
                  .map(
                    (w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        '${w.name} (${w.code})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) ctx.select(v);
              },
            ),
        ],
      );
    }),
  );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final s = controller.summary.value;
    if (s == null) {
      return controller.isLoading.value
          ? const LinearProgressIndicator()
          : const SizedBox.shrink();
    }
    final stats = [
      _Stat('Available', '${s.availableQty}', AppColors.success),
      _Stat('Dalam QC', '${s.qcQty}', AppColors.warning),
      _Stat('Transit masuk', '${s.inTransitQty}', const Color(0xFF6B5BD2)),
      _Stat('ED ≤30 hari', '${s.expiringBatches} batch', AppColors.danger),
    ];
    // 4 kolom bila cukup lebar (>= ~78 dp per kartu), selain itu 2 x 2.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final columns = constraints.maxWidth >= 4 * 78 + 3 * gap ? 4 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final st in stats) SizedBox(width: width, child: st)],
        );
      },
    );
  });
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Angka besar tidak pernah terpotong: diperkecil otomatis bila tidak muat.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 9.5, color: Colors.black54),
          ),
        ),
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.menu,
    required this.badge,
    required this.onTap,
  });
  final _Menu menu;
  final int badge;
  final VoidCallback onTap;

  /// Lebar minimum kartu agar judul & ikon tetap terbaca.
  static const minWidth = 96.0;

  static const _padTop = 10.0, _padBottom = 8.0, _icon = 38.0, _gap = 6.0;
  static const _titleSize = 11.5, _titleHeight = 1.25, _subSize = 9.0, _subHeight = 1.2;

  /// Tinggi kartu = isi tetap (ikon + 1 baris judul + 2 baris keterangan), mengikuti skala font
  /// sehingga tidak pernah overflow dan semua kartu dalam satu baris sama tinggi.
  static double heightFor(TextScaler scaler) =>
      _padTop + _icon + _gap +
      scaler.scale(_titleSize) * _titleHeight + 2 +
      scaler.scale(_subSize) * _subHeight * 2 +
      _padBottom + 4;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, _padTop, 8, _padBottom),
                child: Column(
                  // Posisi ikon & teks selalu dari atas dengan slot tetap -> tidak bergeser antar kartu.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: _icon,
                        height: _icon,
                        decoration: BoxDecoration(
                          color: AppColors.softOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(menu.icon, color: AppColors.primary, size: 21),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    SizedBox(
                      height: scaler.scale(_titleSize) * _titleHeight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          menu.title,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: _titleSize,
                            height: _titleHeight,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: scaler.scale(_subSize) * _subHeight * 2,
                      child: Text(
                        menu.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: _subSize,
                          color: Colors.black45,
                          height: _subHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
