import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MobileAppButton extends StatelessWidget {
  final VoidCallback onTap;

  const MobileAppButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Only show on small screens
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (!isMobile) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: SafeArea(
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MedColors.primary, Color(0xFF00D1FF)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: MedColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      "ابدأ الآن — مجاناً",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}






