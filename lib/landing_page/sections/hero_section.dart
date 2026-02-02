import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../components/med_button.dart';
import '../components/highlight_line.dart';
import 'demo_section.dart';
import 'comparison_section.dart'; // Keep if needed elsewhere, but mainly we use DemoSection now.
import 'demo_section.dart';
import 'cinematic_slider_section.dart';

class HeroSection extends StatefulWidget {
  final VoidCallback onTryLive;
  final VoidCallback onSeeExample;

  const HeroSection({
    super.key,
    required this.onTryLive,
    required this.onSeeExample,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Background
        Positioned.fill(
          child: Container(color: MedColors.background),
        ),

        // 3. Content
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 120, bottom: 80, left: 24, right: 24),
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 1000;
                
                if (isMobile) {
                  return Column(
                    children: [
                      _buildTextContent(context, true),
                      const SizedBox(height: 60),
                      const DemoSection(),
                    ],
                  );
                }

                // Two-Column Desktop Layout
                // New Plan: Column containing:
                // 1. Row [CinematicSlider (Right/Start), Text (Left/End)]
                // 2. DemoSection (Bottom)
                
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Align center vertically
                      children: [
                        // Right Column (Start in RTL): Cinematic Slider
                        Expanded(
                          flex: 5,
                          child: Padding(
                             padding: const EdgeInsets.only(top: 0),
                             child: const CinematicSliderSection(isHeroMode: true),
                          ),
                        ),
                        const SizedBox(width: 60),
                        // Left Column (End in RTL): Text
                        Expanded(
                          flex: 6,
                          child: _buildTextContent(context, false), // isCentered = false
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 80),
                    
                    // Bottom: Live Demo
                    const DemoSection(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context, bool isCentered) {
    final align = isCentered ? TextAlign.center : TextAlign.right;
    final crossAlign = isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final alignment = isCentered ? WrapAlignment.center : WrapAlignment.start;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: crossAlign,
          mainAxisSize: MainAxisSize.min,
          children: [
             // 1. Strong Short H1
             Text(
              "سجّل ملاحظتك الطبية… وخذها جاهزة للصق خلال ثوانٍ",
              textAlign: align,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.displayLarge!.copyWith(
                fontSize: 42,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.2,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 2. Animated Highlight Line
             const HighlightLine(),

            const SizedBox(height: 24),
            
            // 3. One-line Flow
            Text(
              "سجّل → اختر قالبًا → انسخ للصق في نظام المستشفى",
              textAlign: align,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: MedColors.textMuted.withOpacity(0.8),
                fontSize: 18,
                height: 1.6
              ),
            ),
            
            const SizedBox(height: 48),

            // 4. CTAs
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: alignment,
              children: [
                MedButton(
                  label: "جرّب الآن",
                  onPressed: widget.onTryLive,
                  type: ButtonType.primary,
                  icon: Icons.mic,
                ),
                MedButton(
                  label: "شاهد مثال جاهز",
                  onPressed: widget.onSeeExample,
                  type: ButtonType.text, // Link style per request
                  icon: Icons.play_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "بدون بطاقة — جرّب التجربة مباشرة.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            
            if (isCentered) ...[
               const SizedBox(height: 80),
               TextButton(
                  onPressed: widget.onSeeExample,
                  child: const Text("أو شاهد فيديو توضيحي للنظام", style: TextStyle(color: MedColors.textMuted)),
               ),
            ]
          ],
        ),
      ),
    );
  }
} // End of class
