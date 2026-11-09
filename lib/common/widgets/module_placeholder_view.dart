import 'package:flutter/material.dart';
import '../../application/constants/app_colors.dart';

class ModulePlaceholderView extends StatelessWidget {
  const ModulePlaceholderView({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 76, height: 76, decoration: const BoxDecoration(color: AppColors.softOrange, shape: BoxShape.circle), child: const Icon(Icons.construction_rounded, color: AppColors.primary, size: 38)), const SizedBox(height: 18), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.charcoal)), const SizedBox(height: 8), const Text('Modul ini akan dikembangkan pada tahap berikutnya.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13))]))),
  );
}
