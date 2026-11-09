import 'package:flutter/material.dart';
import '../../../application/constants/app_colors.dart';

class DashboardStatGrid extends StatelessWidget {
  const DashboardStatGrid({super.key});
  static const _items = <_StatData>[
    _StatData('1.248', 'Total Produk', Icons.inventory_2_rounded, AppColors.primary),
    _StatData('82.560', 'Total Stok', Icons.widgets_rounded, Color(0xFFE69A16)),
    _StatData('128', 'Stok Minimum', Icons.warning_amber_rounded, AppColors.warning),
    _StatData('320', 'Barang Masuk', Icons.call_received_rounded, AppColors.success),
    _StatData('215', 'Barang Keluar', Icons.call_made_rounded, AppColors.danger),
    _StatData('12', 'Transfer Hari Ini', Icons.swap_horiz_rounded, AppColors.info),
  ];
  @override
  Widget build(BuildContext context) => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.72), itemBuilder: (context, index) {
    final item = _items[index];
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 39, height: 39, decoration: BoxDecoration(color: item.color.withValues(alpha: .11), borderRadius: BorderRadius.circular(11)), child: Icon(item.icon, color: item.color, size: 22)), const SizedBox(width: 9), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(item.value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.charcoal))), const SizedBox(height: 3), Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54))]))]));
  });
}

class _StatData {
  const _StatData(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
}
