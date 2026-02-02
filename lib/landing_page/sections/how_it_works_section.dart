import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../components/hover_scale.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MedColors.background,
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
      child: Column(
        children: [
          // Section Header
          Text("كيف يعمل؟", style: Theme.of(context).textTheme.headlineMedium)
              .animate().fade().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          const Text("تدفق ذكي يحول صوتك إلى بيانات منظمة", style: TextStyle(color: MedColors.textMuted))
              .animate(delay: 200.ms).fade().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 120),

          // The Steps Content
          LayoutBuilder(builder: (context, constraints) {
             final isMobile = constraints.maxWidth < 800;
             return Stack(
               children: [
                 // 1. The Central Neural Line (Desktop Only)
                 if (!isMobile)
                   Positioned.fill(
                     child: Center(
                       child: Container(
                         width: 4,
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.topCenter,
                             end: Alignment.bottomCenter,
                             colors: [
                               MedColors.background,
                               MedColors.primary.withOpacity(0.5),
                               MedColors.primary,
                               MedColors.primary.withOpacity(0.5),
                               MedColors.background,
                             ],
                           ),
                         ),
                       ),
                     ),
                   ).animate().fade(duration: 1000.ms),

                 // 2. The Steps
                 Column(
                   children: [
                     _buildNeuralStep(
                       context,
                       index: 1,
                       title: "استرح من الكتابة",
                       desc: "تواصلك مع مريضك هو القيمة الأهم.",
                       imagePath: "assets/images/landing/step_01_record_v3.png",
                       isRight: true,
                       color: MedColors.primary,
                       isMobile: isMobile,
                       delay: 400.ms,
                     ),
                     const SizedBox(height: 160), // Space for flow
                     _buildNeuralStep(
                       context,
                       index: 2,
                       title: "مرونة الإدخال",
                       desc: "ملاحظاتك محفوظة الصقها في النظام براحتك.",
                       imagePath: "assets/images/landing/step_02_process.png",
                       isRight: false,
                       color: MedColors.accent,
                       isMobile: isMobile,
                       delay: 600.ms,
                     ),
                     const SizedBox(height: 160),
                     _buildNeuralStep(
                       context,
                       index: 3,
                       title: "مرونة الحركة",
                       desc: "سواء كنت في الراوند او في المكتب سجل ملاحظاتك براحتك.",
                       imagePath: "assets/images/landing/step_03_result.jpg",
                       isRight: true,
                       color: MedColors.success,
                       isMobile: isMobile,
                       delay: 800.ms,
                     ),
                   ],
                 ),
               ],
             );
          }),
        ],
      ),
    );
  }

  Widget _buildNeuralStep(BuildContext context, {
    required int index,
    required String title,
    required String desc,
    required String imagePath,
    required bool isRight,
    required Color color,
    required bool isMobile,
    required Duration delay,
  }) {
    final textSection = Expanded(
      child: Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.center : (isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 28), textAlign: isMobile ? TextAlign.center : null),
          const SizedBox(height: 16),
          Text(desc, style: const TextStyle(fontSize: 18, color: MedColors.textMuted, height: 1.6), textAlign: isMobile ? TextAlign.center : (isRight ? TextAlign.right : TextAlign.left)),
        ],
      ).animate(delay: delay + 200.ms).fade().slideX(begin: isRight ? -0.2 : 0.2, end: 0),
    );

    final cardSection = Expanded(
      child: HoverScale(
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10))
            ],
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(30),
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
               child: Container(
                 decoration: BoxDecoration(
                   color: MedColors.surface.withOpacity(0.6),
                   border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                   borderRadius: BorderRadius.circular(30),
                 ),
                 child: Stack(
                   alignment: Alignment.center,
                   children: [
                      // Image Content
                      Image.asset(
                         imagePath,
                         fit: BoxFit.cover,
                         width: double.infinity,
                         height: double.infinity,
                      ).animate().fade(duration: 800.ms),
                      
                      // Gradient Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
                          ),
                          child: Text(
                            "Step 0$index", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                          ),
                        ),
                      )
                   ],
                 ),
               ),
             ),
          ),
        ),
      ).animate(delay: delay).fade(duration: 800.ms).slideY(begin: 0.2, end: 0),
    );

    final spacer = const SizedBox(width: 60);

    // The Central Node
    final node = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: MedColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)
        ]
      ),
      child: Center(
        child: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    ).animate(delay: delay + 400.ms).scale(begin: const Offset(0,0), end: const Offset(1,1), curve: Curves.elasticOut);

    if (isMobile) {
      return Column(
        children: [
          node,
          const SizedBox(height: 24),
          cardSection,
          const SizedBox(height: 24),
          textSection,
        ],
      );
    }

    return Row(
      children: isRight
          ? [textSection, spacer, node, spacer, cardSection] 
          : [cardSection, spacer, node, spacer, textSection], 
    );
  }
}
