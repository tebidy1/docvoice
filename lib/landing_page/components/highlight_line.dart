import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class HighlightLine extends StatelessWidget {
  const HighlightLine({super.key});

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion preference
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;
    final textStyle = Theme.of(context).textTheme.headlineMedium!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 28, // Distinctive highlight size
    );

    return Wrap( // Wrap to be safe on small screens
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start, // Left aligned in Hero context (or Right for RTL)
      textDirection: TextDirection.rtl, // Ensure Arabic order
      children: [
        _buildWord("مكتبة", textStyle, 0.ms, disableAnimations),
        _buildSeparator(textStyle),
        _buildWord("منسّقة", textStyle, 1000.ms, disableAnimations),
        _buildSeparator(textStyle),
        _buildWord("جاهزة للصق", textStyle, 2000.ms, disableAnimations),
      ],
    );
  }

  Widget _buildSeparator(TextStyle style) {
    return Text("•", style: style.copyWith(color: MedColors.primary.withOpacity(0.5)));
  }

  Widget _buildWord(String text, TextStyle style, Duration delay, bool disableAnimations) {
    if (disableAnimations) {
      // Static Version
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
         decoration: BoxDecoration(
           color: const Color(0xFF2BB7FF).withOpacity(0.18),
           borderRadius: BorderRadius.circular(8),
           border: Border(bottom: BorderSide(color: const Color(0xFF2BB7FF).withOpacity(0.6), width: 3)),
         ),
        child: Text(text, style: style.copyWith(color: const Color(0xFF2BB7FF))),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Highlight
          Positioned.fill(
             child: Container(
               decoration: BoxDecoration(
                 color: const Color(0xFF2BB7FF).withOpacity(0.18),
                 borderRadius: BorderRadius.circular(8),
               ),
             ).animate(
               onPlay: (c) => c.repeat(),
               delay: delay,
             )
             .fadeIn(duration: 500.ms, curve: Curves.easeIn)
             .then(delay: 500.ms) // Sustain
             .fadeOut(duration: 500.ms)
             .then(delay: 1500.ms) // Wait cycle
          ),
          
          // Text
          Text(text, style: style),

          // Animated Underline
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: Container(
               height: 3,
               color: const Color(0xFF2BB7FF).withOpacity(0.8),
             ).animate(
               onPlay: (c) => c.repeat(),
               delay: delay,
             )
             .scaleX(begin: 0, end: 1, duration: 500.ms, curve: Curves.easeOut, alignment: Alignment.centerRight) 
             .then(delay: 500.ms)
             .fadeOut(duration: 300.ms)
             .then(delay: 1700.ms)
          ),
        ],
      ),
    );
  }
}
