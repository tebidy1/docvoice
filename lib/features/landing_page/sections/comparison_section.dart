import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../components/hover_scale.dart';

class ComparisonSection extends StatefulWidget {
  const ComparisonSection({super.key});

  @override
  State<ComparisonSection> createState() => _ComparisonSectionState();
}

class _ComparisonSectionState extends State<ComparisonSection> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Timelines (normalized 0.0 -> 1.0 for 12 seconds)
  // 0.8s / 12s = 0.066 (Entry end)
  // 2.0s / 12s = 0.166 (AI Pop-in)
  // 6.5s / 12s = 0.54 (Badges appear)
  // 10.5s / 12s = 0.875 (Loop start fade out)
  
  static const int totalDurationMs = 12000;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: totalDurationMs));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 0.0 -> 0.066: Entry Fade In
    final entryAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.066, curve: Curves.easeOut),
    );

    // 0.875 -> 1.0: Exit Fade Out (for loop)
    final exitAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.875, 1.0, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = entryAnim.value * (1.0 - exitAnim.value);
        return Opacity(
          opacity: opacity,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00162B), Color(0xFF0B2C55)], // Dark Blue Spec
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    return isMobile 
                      ? _buildMobileLayout() 
                      : _buildDesktopLayout(constraints);
                  },
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return SizedBox(
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              // Left: Handwriting
              Expanded(child: _buildPanel(isLeft: true)),
              const SizedBox(width: 80), // Gap for Divider
              // Right: AI Dictation
              Expanded(child: _buildPanel(isLeft: false)),
            ],
          ),
          // Center Divider & Counter
          _buildCenterDivider(),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SizedBox(height: 300, child: _buildPanel(isLeft: true)),
        const SizedBox(height: 40),
        _buildCenterDivider(isVertical: false),
        const SizedBox(height: 40),
        SizedBox(height: 300, child: _buildPanel(isLeft: false)),
      ],
    );
  }

  Widget _buildCenterDivider({bool isVertical = true}) {
    // Counter Animation: 2.0s to 6.5s (0.166 -> 0.54)
    final counterAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.166, 0.54, curve: Curves.easeOutCubic),
    );

    // 40 -> 160
    final count = 40 + (120 * counterAnim.value).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVertical) 
           Container(
             width: 2, 
             height: 100, 
             margin: const EdgeInsets.only(bottom: 16),
             decoration: BoxDecoration(
               color: const Color(0xFF00A6FB).withOpacity(0.5),
               boxShadow: const [BoxShadow(color: Color(0xFF00A6FB), blurRadius: 15, spreadRadius: 2)],
             ),
           ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 1000.ms),
        
        // Counter Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0B2C55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00A6FB).withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
          ),
          child: Column(
            children: [
              Text(
                "$count",
                style: const TextStyle(
                  color: Color(0xFF00A6FB), 
                  fontSize: 32, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'
                ),
              ),
              const Text("كلمة / دقيقة", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),

        if (isVertical) 
           Container(
             width: 2, 
             height: 100, 
             margin: const EdgeInsets.only(top: 16),
             decoration: BoxDecoration(
               color: const Color(0xFF00A6FB).withOpacity(0.5),
               boxShadow: const [BoxShadow(color: Color(0xFF00A6FB), blurRadius: 15, spreadRadius: 2)],
             ),
           ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1.0, duration: 1000.ms),

        const SizedBox(height: 16),
        // Final Badge under divider
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final showResult = _controller.value > 0.54; // > 6.5s
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: showResult ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MedColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MedColors.success),
                ),
                child: const Text("نفس الدقة — وقت أقل", style: TextStyle(color: MedColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            );
          }
        )
      ],
    );
  }

  Widget _buildPanel({required bool isLeft}) {
    // Motion Spec Data
    final title = isLeft ? "كتابة يدوية" : "إملاء ذكي";
    final fullText = isLeft 
        ? "المريض يشتكي من صداع نصفي حاد منذ ثلاثة أيام مع غثيان ورهاب الضوء..."
        : "المريض يشتكي من صداع نصفي حاد منذ ثلاثة أيام مع غثيان ورهاب الضوء. الفحص العصبي طبيعي ولا علامات لتهيج سحائي.";
    
    // Logic for Typing (Left)
    // Starts at 0.066 (0.8s) -> Ends ??? (Slow)
    // 40 chars * 0.3s = 12s... it takes forever.
    final typingStart = 0.066;
    final charsToShow = math.max(0, ((_controller.value - typingStart) * 50).toInt()); // Slow typing
    final visibleTextLeft = fullText.substring(0, math.min(charsToShow, fullText.length));

    // Logic for AI (Right)
    // Waveform 0.0 -> 0.166 (2.0s)
    // Pop-in at 0.166
    final showAiText = _controller.value > 0.166;
    final showWaveform = !showAiText;

    // Badges (6.5s -> 0.54)
    final showBadges = _controller.value > 0.54;

    return HoverScale(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(isLeft ? Icons.keyboard : Icons.mic, color: isLeft ? Colors.grey : MedColors.primary),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: isLeft ? Colors.grey : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLeft 
                  // LEFT: Typing
                  ? Text(
                      "$visibleTextLeft|", // Cursor
                      style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    )
                  // RIGHT: Waveform -> Pop-in
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        if (showWaveform) 
                           const AudioWaveform(),
                        
                        if (showAiText)
                           Text(
                             fullText,
                             style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                             textAlign: TextAlign.right,
                             textDirection: TextDirection.rtl,
                           ).animate()
                            .fade(duration: 200.ms)
                            .blur(begin: const Offset(4,4), end: Offset.zero, duration: 300.ms) // Blur to Sharp
                            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1,1), duration: 300.ms),
                             
                        if (showAiText)
                           Positioned(
                             bottom: 0, left: 0,
                             child: const Icon(Icons.check_circle, color: MedColors.success, size: 20)
                               .animate().scale(curve: Curves.elasticOut, duration: 400.ms),
                           ),
                      ],
                    ),
              ),
            ),
            
            // Footer Badge (6.5s)
            const SizedBox(height: 16),
            AnimatedOpacity(
               duration: const Duration(milliseconds: 500),
               opacity: showBadges ? 1.0 : 0.0,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 decoration: BoxDecoration(
                   color: isLeft ? Colors.red.withOpacity(0.1) : MedColors.primary.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: isLeft ? Colors.red.withOpacity(0.5) : MedColors.primary),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(isLeft ? Icons.timelapse : Icons.bolt, size: 14, color: isLeft ? Colors.red : MedColors.primary),
                     const SizedBox(width: 8),
                     Text(
                       isLeft ? "ما زال يكتب..." : "اكتمل خلال 2 ثانية",
                       style: TextStyle(color: isLeft ? Colors.red : MedColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioWaveform extends StatelessWidget {
  const AudioWaveform({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: MedColors.primary,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: MedColors.primary.withOpacity(0.5), blurRadius: 4)]
            ),
          ).animate(
             onPlay: (c) => c.repeat(reverse: true),
             delay: (index * 50).ms, // Staggered
          ).scaleY(
             begin: 0.2, 
             end: 1.5, 
             duration: (300 + (index % 3) * 100).ms, // Variegated speed
             curve: Curves.easeInOut,
          );
        }),
      ),
    );
  }
}
