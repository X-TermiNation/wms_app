import 'package:flutter/material.dart';
import '../../application/constants/app_colors.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, this.hint = 'Cari...', this.controller, this.onChanged});
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, onChanged: onChanged, decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded, color: AppColors.charcoal), filled: true, fillColor: Colors.white));
}
