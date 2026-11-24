import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../../../data/models/inventory_models.dart';
import '../controllers/warehouse_controller.dart';
import '../models/warehouse_location_model.dart';
import '../models/warehouse_model.dart';

/// Daftar gudang & lokasi (hanya baca). Pengelolaan di aplikasi Desktop.
class WarehouseView extends GetView<WarehouseController> {
  const WarehouseView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Gudang & Lokasi', style: TextStyle(fontWeight: FontWeight.w700))),
    body: Column(children: [
      Container(
        color: Colors.white,
        child: Obx(() => Row(children: [
          _TabButton(label: 'Gudang', selected: controller.selectedTab.value == 0, onTap: () => controller.selectedTab.value = 0),
          _TabButton(label: 'Lokasi', selected: controller.selectedTab.value == 1, onTap: () => controller.selectedTab.value = 1),
        ])),
      ),
      Expanded(child: Obx(() => controller.selectedTab.value == 0
          ? _WarehouseList(controller: controller)
          : _LocationList(controller: controller))),
    ]),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 3))),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.primary : Colors.black54)),
    ),
  ));
}

class _WarehouseList extends StatelessWidget {
  const _WarehouseList({required this.controller});
  final WarehouseController controller;

  @override
  Widget build(BuildContext context) => Obx(() => RefreshIndicator(
    onRefresh: controller.fetchAll,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (controller.isLoading.value && controller.warehouses.isEmpty)
          const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
        const Text('Gudang yang dapat Anda akses. Penambahan gudang & lokasi dilakukan dari aplikasi Desktop.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 10),
        ...controller.warehouses.map((w) => _WarehouseCard(
          warehouse: w,
          locationCount: controller.locations.where((e) => e.warehouseId == w.id).length,
          onSelect: () {
            controller.selectWarehouse(w.id);
            controller.selectedTab.value = 1;
          },
        )),
      ],
    ),
  ));
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse, required this.locationCount, required this.onSelect});
  final WarehouseModel warehouse;
  final int locationCount;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warehouse_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(warehouse.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(warehouse.code, style: const TextStyle(color: Colors.black54, fontSize: 10.5)),
              ])),
              _Pill(label: warehouse.isActive ? 'Aktif' : 'Nonaktif', color: warehouse.isActive ? AppColors.success : Colors.grey),
            ]),
            const SizedBox(height: 8),
            Text(warehouse.address, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Divider(height: 18),
            Row(children: [
              Text('$locationCount lokasi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Lihat lokasi', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _LocationList extends StatelessWidget {
  const _LocationList({required this.controller});
  final WarehouseController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final warehouse = controller.selectedWarehouse;
    final locations = controller.currentLocations;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      DropdownButtonFormField<String>(
        initialValue: warehouse?.id,
        key: ValueKey(warehouse?.id),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Gudang', border: OutlineInputBorder(), isDense: true),
        items: controller.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.code})', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) controller.selectWarehouse(v); },
      ),
      const SizedBox(height: 10),
      AppSearchField(hint: 'Cari kode / barcode lokasi...', controller: controller.searchController, onChanged: controller.updateSearch),
      const SizedBox(height: 8),
      SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: ['Semua', 'Rak', 'Area Sistem/QC'].map((t) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(label: Text(t, style: const TextStyle(fontSize: 11)), selected: controller.selectedType.value == t, selectedColor: AppColors.softOrange, onSelected: (_) => controller.selectedType.value = t),
      )).toList())),
      const SizedBox(height: 8),
      if (locations.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 35), child: Center(child: Text('Lokasi tidak ditemukan.', style: TextStyle(color: Colors.black54))))
      else
        ...locations.map((l) => _LocationCard(location: l)),
    ]);
  });
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});
  final WarehouseLocationModel location;

  @override
  Widget build(BuildContext context) {
    final color = !location.isActive || location.status == LocationStatus.blocked
        ? AppColors.danger
        : location.isSystem
            ? AppColors.info
            : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(location.isSystem ? Icons.science_outlined : Icons.grid_view_rounded, color: color),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(location.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(location.barcode ?? '-', style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
          if (location.description.isNotEmpty) Text(location.description, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _Pill(label: LocationInfo.typeLabel(location.type), color: color),
          const SizedBox(height: 4),
          Text(WarehouseController.statusLabel(location.status), style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
  );
}
