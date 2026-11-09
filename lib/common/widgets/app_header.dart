import 'package:flutter/material.dart';
import '../../application/constants/app_colors.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.name, required this.role});
  final String name;
  final String role;
  @override
  Widget build(BuildContext context) => Row(children: [
    const CircleAvatar(radius: 23, backgroundColor: AppColors.softOrange, child: Icon(Icons.person_rounded, color: AppColors.darkOrange, size: 27)),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Selamat Datang, $name', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.charcoal)), const SizedBox(height: 3), Text(role, style: const TextStyle(fontSize: 12, color: Colors.black54))])),
  ]);
}
