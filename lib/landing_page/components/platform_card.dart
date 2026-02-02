import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PlatformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const PlatformCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MedColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MedColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: MedColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: MedColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MedColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
