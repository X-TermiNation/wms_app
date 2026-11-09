import 'package:flutter/material.dart';
import '../../../application/constants/app_colors.dart';

class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({super.key, required this.title, required this.reference, required this.warehouse, required this.time, required this.icon, required this.color});
  final String title, reference, warehouse, time;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 21)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.charcoal)), const SizedBox(height: 4), Text('$reference  •  $warehouse', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54))])), const SizedBox(width: 5), Text(time, style: const TextStyle(fontSize: 10, color: Colors.black45))]));
}
