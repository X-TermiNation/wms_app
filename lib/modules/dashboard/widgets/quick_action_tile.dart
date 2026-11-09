import 'package:flutter/material.dart';
import '../../../application/constants/app_colors.dart';

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 25),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
