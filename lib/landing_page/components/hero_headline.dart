import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class AnimatedHeroHeadline extends StatelessWidget {
  const AnimatedHeroHeadline({super.key});

  @override
  Widget build(BuildContext context) {
    // Style for the main text
    final mainStyle = Theme.of(context).textTheme.displayLarge!.copyWith(
      fontSize: 42,
      height: 1.3,
      color: Colors.white,
      shadows: [
        Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );

    // Style for the highlighted text
    final highlightStyle = mainStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: const Color(0xFF27B3FF), // Accent
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: mainStyle,
        children: [
          const TextSpan(text: "سجّل ملاحظتك الطبية وشاهدها تتحول إلى ملاحظة "),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _AnimatedWord(
              text: "مكتوبة", 
              style: highlightStyle, 
              delay: 0.ms
            ),
          ),
          const TextSpan(text: "، "),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _AnimatedWord(
              text: "منسّقة", 
              style: highlightStyle, 
              delay: 1000.ms
            ),
          ),
          const TextSpan(text: "، "),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _AnimatedWord(
              text: "جاهزة للصق", 
              style: highlightStyle, 
              delay: 2000.ms
            ),
          ),
          const TextSpan(text: "… في ثوانٍ."),
        ],
      ),
    );
  }
}

class _AnimatedWord extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration delay;

  const _AnimatedWord({
    required this.text, 
    required this.style, 
    required this.delay
  });

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion preference
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    if (disableAnimations) {
      // Static Version (Permanent Highlight)
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Stack(
          children: [
             Positioned.fill(
               bottom: 4,
               child: Container(
                 decoration: BoxDecoration(
                   color: const Color(0xFF27B3FF).withOpacity(0.18),
                   borderRadius: BorderRadius.circular(4),
                 ),
               ),
             ),
             Text(text, style: style),
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
               child: Container(
                 height: 3,
                 color: const Color(0xFF27B3FF).withOpacity(0.6),
               ),
             ),
          ],
        ),
      );
    }

    // Animated Version
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        children: [
          // The Highlight Background
          Positioned.fill(
             bottom: 4,
             child: Container(
               decoration: BoxDecoration(
                 color: const Color(0xFF27B3FF).withOpacity(0.18),
                 borderRadius: BorderRadius.circular(4),
               ),
             ).animate(
               onPlay: (c) => c.repeat(),
               delay: delay,
             )
             .fadeIn(duration: 400.ms, curve: Curves.easeIn)
             .then(delay: 600.ms) // Stay visible
             .fadeOut(duration: 400.ms) // Fade out
             .then(delay: 1600.ms) // Wait for cycle
          ),
          
          // The Text
          Text(text, style: style),

          // The Moving Underline
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: Container(
               height: 3,
               color: const Color(0xFF27B3FF).withOpacity(0.6),
             ).animate(
               onPlay: (c) => c.repeat(),
               delay: delay,
             )
             .scaleX(begin: 0, end: 1, duration: 400.ms, curve: Curves.easeOut, alignment: Alignment.centerRight) // RTL underline
             .then(delay: 600.ms)
             .fadeOut(duration: 300.ms)
             .then(delay: 1700.ms)
          ),
        ],
      ),
    );
  }
}
