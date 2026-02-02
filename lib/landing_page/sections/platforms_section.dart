import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../components/med_button.dart';

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
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Colors.white),
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
                     title: "إضافة كروم",
                     desc: "بجانب نظامك اليومي",
                     btnLabel: "إضافة إلى Chrome",
                     btnColor: Colors.grey[800]!,
                     glowColor: Colors.cyan,
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
                   ),
                   _buildCard(
                     context,
                     icon: Icons.phone_android,
                     title: "تطبيق الجوال",
                     desc: "سجّل أثناء الحركة",
                     btnLabel: "قريبًا على Play",
                     btnColor: Colors.black,
                     glowColor: Colors.green,
                   ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
    required String btnLabel,
    required Color btnColor,
    required Color glowColor,
    bool isPrimary = false,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MedColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPrimary ? glowColor.withOpacity(0.5) : MedColors.divider,
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: isPrimary ? [
           BoxShadow(color: glowColor.withOpacity(0.2), blurRadius: 24, offset: const Offset(0,8))
        ] : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor.withOpacity(0.1),
            ),
            child: Icon(icon, color: glowColor, size: 32),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 14, color: MedColors.textMuted)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(btnLabel),
            ),
          ),
        ],
      ),
    );
  }
}
