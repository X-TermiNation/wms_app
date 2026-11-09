import 'package:flutter/material.dart';
import '../../application/constants/app_colors.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.label, this.color = AppColors.success});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: color, size: 7), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))]),
  );
}
