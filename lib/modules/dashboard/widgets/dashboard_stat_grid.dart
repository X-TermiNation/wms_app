import 'package:flutter/material.dart';
import '../../../application/constants/app_colors.dart';

class DashboardStatGrid extends StatelessWidget {
  const DashboardStatGrid({super.key});

  static const _items = <_StatData>[
    _StatData(
      '1.248',
      'Total Produk',
      Icons.inventory_2_rounded,
      AppColors.primary,
    ),
    _StatData('82.560', 'Total Stok', Icons.widgets_rounded, Color(0xFFE69A16)),
    _StatData(
      '128',
      'Stok Minimum',
      Icons.warning_amber_rounded,
      AppColors.warning,
    ),
    _StatData(
      '320',
      'Barang Masuk',
      Icons.call_received_rounded,
      AppColors.success,
    ),
    _StatData(
      '215',
      'Barang Keluar',
      Icons.call_made_rounded,
      AppColors.danger,
    ),
    _StatData(
      '12',
      'Transfer Hari Ini',
      Icons.swap_horiz_rounded,
      AppColors.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, color: item.color, size: 19),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.value,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatData {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatData(this.value, this.label, this.icon, this.color);
}
