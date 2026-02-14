import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart' as platform_utils;
import '../theme/app_colors.dart';

class PlatformsSection extends StatelessWidget {
  const PlatformsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF041B30), // Deep Dark Navy
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                "منظومة متكاملة لعيادتك",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(color: Colors.white),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildCard(
                    context,
                    icon: Icons.web,
                    title: "إضافة المتصفح",
                    desc: "بجانب نظامك اليومي",
                    btnLabel: "تحميل الإضافة (ZIP)",
                    btnColor: Colors.grey[800]!,
                    glowColor: Colors.cyan,
                    onTap: () => platform_utils.downloadFile(
                        'apps/ScribeFlow_Extension.zip',
                        'ScribeFlow_Extension.zip'),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.desktop_windows,
                    title: "Windows Desktop",
                    desc: "الأسرع للعيادة والمكتب",
                    btnLabel: "نسخة Windows",
                    btnColor: MedColors.primary,
                    glowColor: MedColors.primary,
                    isPrimary: true,
                    onTap: () {}, // Handled by default navigation or setup
                  ),
                  _buildCard(
                    context,
                    icon: Icons.phone_android,
                    title: "تطبيق الأندرويد",
                    desc: "سجّل أثناء الحركة",
                    btnLabel: "تحميل تطبيق APK",
                    btnColor: Colors.black,
                    glowColor: Colors.green,
                    onTap: () => platform_utils.downloadFile(
                        'apps/ScribeFlow.apk', 'ScribeFlow.apk'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required String btnLabel,
    required Color btnColor,
    required Color glowColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MedColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isPrimary ? glowColor.withValues(alpha: 0.5) : MedColors.divider,
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                    color: glowColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: glowColor, size: 32),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(desc,
              style: const TextStyle(fontSize: 14, color: MedColors.textMuted)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(btnLabel),
            ),
          ),
        ],
      ),
    );
  }
}
