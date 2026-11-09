import 'package:flutter/material.dart';
import '../../application/constants/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.isLoading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon ?? Icons.login_rounded),
      label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    ),
  );
}
