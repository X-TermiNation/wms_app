import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../common/widgets/app_search_field.dart';
import '../controllers/warehouse_controller.dart';
import '../models/warehouse_location_model.dart';
import '../models/warehouse_model.dart';

class WarehouseView extends GetView<WarehouseController> {
  const WarehouseView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Gudang & Lokasi', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
    floatingActionButton: Obx(() => FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: controller.selectedTab.value == 0
          ? () => _WarehouseForm.show(controller)
          : () => _LocationForm.show(controller),
      icon: const Icon(Icons.add_rounded),
      label: Text(controller.selectedTab.value == 0 ? 'Tambah Gudang' : 'Tambah Lokasi'),
    )),
    body: Column(children: [
      Container(
        color: Colors.white,
        child: Obx(() => Row(children: [
          _TabButton(label: 'Gudang', selected: controller.selectedTab.value == 0,
            onTap: () => controller.selectedTab.value = 0),
          _TabButton(label: 'Lokasi', selected: controller.selectedTab.value == 1,
            onTap: () => controller.selectedTab.value = 1),
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
  Widget build(BuildContext context) => Obx(() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _OverviewCard(controller: controller),
      const SizedBox(height: 16),
      Row(children: [
        const Expanded(child: Text('Daftar Gudang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        Text('${controller.warehouses.length} gudang', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
      const SizedBox(height: 10),
      ...controller.warehouses.map((warehouse) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _WarehouseCard(
          warehouse: warehouse,
          locationCount: controller.locations.where((e) => e.warehouseId == warehouse.id).length,
          onSelect: () { controller.selectWarehouse(warehouse.id); controller.selectedTab.value = 1; },
          onEdit: () => _WarehouseForm.show(controller, warehouse: warehouse),
          onDelete: () => _confirmDeleteWarehouse(controller, warehouse),
        ),
      )),
    ],
  ));
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.controller});
  final WarehouseController controller;
  @override
  Widget build(BuildContext context) {
    final total = controller.warehouses.length;
    final active = controller.warehouses.where((e) => e.isActive).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.darkOrange]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.warehouse_rounded, color: Colors.white, size: 38),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Gudang Terdaftar', style: TextStyle(color: Colors.white70, fontSize: 11)),
          Text('$total Gudang', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          Text('$active aktif • ${total - active} nonaktif', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse, required this.locationCount, required this.onSelect, required this.onEdit, required this.onDelete});
  final WarehouseModel warehouse;
  final int locationCount;
  final VoidCallback onSelect, onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onSelect,
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.warehouse_outlined, color: AppColors.primary)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(warehouse.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 3),
            Text(warehouse.code, style: const TextStyle(color: Colors.black54, fontSize: 10)),
          ])),
          _StatusPill(label: warehouse.isActive ? 'Aktif' : 'Nonaktif', color: warehouse.isActive ? AppColors.success : Colors.grey),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 15, color: Colors.black45),
          const SizedBox(width: 5),
          Expanded(child: Text(warehouse.address, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const Divider(height: 20),
        Row(children: [
          const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$locationCount lokasi penyimpanan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('Lihat lokasi', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
        ]),
      ])),
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
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 100), children: [
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gudang yang dipilih', style: TextStyle(color: Colors.black54, fontSize: 10)),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            value: warehouse?.id,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: controller.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text('${w.name} (${w.code})', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) { if (value != null) controller.selectWarehouse(value); },
          ),
          const SizedBox(height: 12),
          Row(children: [
            _MiniCount(label: 'Total', value: '${controller.totalLocations}', color: AppColors.info),
            _MiniCount(label: 'Available', value: '${controller.countByStatus(LocationStatus.available, warehouse?.id ?? '')}', color: AppColors.success),
            _MiniCount(label: 'Occupied', value: '${controller.countByStatus(LocationStatus.occupied, warehouse?.id ?? '')}', color: AppColors.warning),
            _MiniCount(label: 'Blocked', value: '${controller.countByStatus(LocationStatus.blocked, warehouse?.id ?? '')}', color: AppColors.danger),
          ]),
        ]),
      ),
      const SizedBox(height: 13),
      AppSearchField(hint: 'Cari kode atau zona lokasi...', controller: controller.searchController, onChanged: controller.updateSearch),
      const SizedBox(height: 10),
      SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: ['Semua', 'Available', 'Occupied', 'Blocked'].map((status) {
        final selected = controller.selectedStatus.value == status;
        return Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(status, style: const TextStyle(fontSize: 10)), selected: selected, selectedColor: AppColors.softOrange, onSelected: (_) => controller.selectedStatus.value = status));
      }).toList())),
      const SizedBox(height: 8),
      if (locations.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 35), child: Center(child: Text('Lokasi tidak ditemukan.', style: TextStyle(color: Colors.black54))))
      else
        ...locations.map((location) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _LocationCard(location: location, onEdit: () => _LocationForm.show(controller, location: location), onDelete: () => _confirmDeleteLocation(controller, location)),
        )),
    ]);
  });
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54)),
  ]));
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onEdit, required this.onDelete});
  final WarehouseLocationModel location;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final color = switch (location.status) {
      LocationStatus.available => AppColors.success,
      LocationStatus.occupied => AppColors.warning,
      LocationStatus.blocked => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.grid_view_rounded, color: color)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(location.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('Zona ${location.zone} • Rak ${location.rack} • Bin ${location.bin}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          if (location.description.isNotEmpty) Text(location.description, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _StatusPill(label: WarehouseController.statusLabel(location.status), color: color),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ]),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}

void _confirmDeleteWarehouse(WarehouseController c, WarehouseModel w) => Get.dialog(AlertDialog(
  title: const Text('Hapus gudang?'),
  content: Text('Gudang "${w.name}" akan dihapus.'),
  actions: [
    TextButton(onPressed: Get.back, child: const Text('Batal')),
    TextButton(onPressed: () { c.deleteWarehouse(w); Get.back(); }, child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
  ],
));

void _confirmDeleteLocation(WarehouseController c, WarehouseLocationModel l) => Get.dialog(AlertDialog(
  title: const Text('Hapus lokasi?'),
  content: Text('Lokasi "${l.code}" akan dihapus.'),
  actions: [
    TextButton(onPressed: Get.back, child: const Text('Batal')),
    TextButton(onPressed: () { c.deleteLocation(l); Get.back(); }, child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
  ],
));

class _WarehouseForm {
  static void show(WarehouseController c, {WarehouseModel? warehouse}) => Get.dialog(_WarehouseFormDialog(controller: c, warehouse: warehouse), barrierDismissible: false);
}

class _WarehouseFormDialog extends StatefulWidget {
  const _WarehouseFormDialog({required this.controller, this.warehouse});
  final WarehouseController controller;
  final WarehouseModel? warehouse;
  @override
  State<_WarehouseFormDialog> createState() => _WarehouseFormDialogState();
}

class _WarehouseFormDialogState extends State<_WarehouseFormDialog> {
  late final TextEditingController code, name, address;
  late bool active;
  @override
  void initState() {
    super.initState();
    final w = widget.warehouse;
    code = TextEditingController(text: w?.code ?? '');
    name = TextEditingController(text: w?.name ?? '');
    address = TextEditingController(text: w?.address ?? '');
    active = w?.isActive ?? true;
  }
  @override
  void dispose() { code.dispose(); name.dispose(); address.dispose(); super.dispose(); }
  void save() {
    if (code.text.trim().isEmpty || name.text.trim().isEmpty || address.text.trim().isEmpty) {
      Get.snackbar('Data belum lengkap', 'Kode, nama, dan alamat gudang wajib diisi.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final old = widget.warehouse;
    if (old == null) {
      widget.controller.addWarehouse(code: code.text.trim(), name: name.text.trim(), address: address.text.trim(), isActive: active);
    } else {
      widget.controller.updateWarehouse(old, code: code.text.trim(), name: name.text.trim(), address: address.text.trim(), isActive: active);
    }
    Get.back();
  }
  @override
  Widget build(BuildContext context) => _FormDialogShell(
    title: widget.warehouse == null ? 'Tambah Gudang' : 'Edit Gudang',
    children: [
      _formField(code, 'Kode gudang'),
      _formField(name, 'Nama gudang'),
      _formField(address, 'Alamat'),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Gudang aktif', style: TextStyle(fontSize: 13)), value: active, activeColor: AppColors.primary, onChanged: (v) => setState(() => active = v)),
    ],
    onSave: save,
  );
}

class _LocationForm {
  static void show(WarehouseController c, {WarehouseLocationModel? location}) => Get.dialog(_LocationFormDialog(controller: c, location: location), barrierDismissible: false);
}

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({required this.controller, this.location});
  final WarehouseController controller;
  final WarehouseLocationModel? location;
  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  late final TextEditingController zone, rack, bin, description;
  late LocationStatus status;
  @override
  void initState() {
    super.initState();
    final l = widget.location;
    zone = TextEditingController(text: l?.zone ?? '');
    rack = TextEditingController(text: l?.rack ?? '');
    bin = TextEditingController(text: l?.bin ?? '');
    description = TextEditingController(text: l?.description ?? '');
    status = l?.status ?? LocationStatus.available;
  }
  @override
  void dispose() { zone.dispose(); rack.dispose(); bin.dispose(); description.dispose(); super.dispose(); }
  void save() {
    if (zone.text.trim().isEmpty || rack.text.trim().isEmpty || bin.text.trim().isEmpty) {
      Get.snackbar('Data belum lengkap', 'Zona, rak, dan bin wajib diisi.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final z = zone.text.trim().toUpperCase(), r = rack.text.trim().padLeft(2, '0'), b = bin.text.trim().padLeft(2, '0');
    final code = '$z-$r-$b';
    final old = widget.location;
    if (old == null) {
      widget.controller.addLocation(code: code, zone: z, rack: r, bin: b, status: status, description: description.text.trim());
    } else {
      widget.controller.updateLocation(old, code: code, zone: z, rack: r, bin: b, status: status, description: description.text.trim());
    }
    Get.back();
  }
  @override
  Widget build(BuildContext context) => _FormDialogShell(
    title: widget.location == null ? 'Tambah Lokasi' : 'Edit Lokasi',
    children: [
      Row(children: [
        Expanded(child: _formField(zone, 'Zona', hint: 'A')),
        const SizedBox(width: 9),
        Expanded(child: _formField(rack, 'Rak', hint: '01', numeric: true)),
        const SizedBox(width: 9),
        Expanded(child: _formField(bin, 'Bin', hint: '01', numeric: true)),
      ]),
      _formField(description, 'Keterangan (opsional)'),
      DropdownButtonFormField<LocationStatus>(
        value: status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Status lokasi', border: OutlineInputBorder()),
        items: LocationStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(WarehouseController.statusLabel(s)))).toList(),
        onChanged: (v) { if (v != null) setState(() => status = v); },
      ),
      const SizedBox(height: 4),
      const Text('Kode lokasi dibuat otomatis dari Zona-Rak-Bin.', style: TextStyle(fontSize: 10, color: Colors.black54)),
    ],
    onSave: save,
  );
}

class _FormDialogShell extends StatelessWidget {
  const _FormDialogShell({required this.title, required this.children, required this.onSave});
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 440, maxHeight: (MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 32).clamp(140.0, 620.0).toDouble()),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Flexible(child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
          child: Column(children: children),
        )),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: Get.back, child: const Text('Batal'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.primary), onPressed: onSave, child: const Text('Simpan'))),
        ]),
      ])),
    ),
  );
}

Widget _formField(TextEditingController controller, String label, {String? hint, bool numeric = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 13),
  child: TextField(
    controller: controller,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    textCapitalization: TextCapitalization.characters,
    decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15)),
  ),
);
