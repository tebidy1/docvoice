import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class HowItWorksSection extends StatefulWidget {
  const HowItWorksSection({super.key});

  @override
  State<HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<HowItWorksSection> {
  int _currentIndex = 0;
  Timer? _timer;
  static const int _displayDuration = 5000; // Time per slide
  static const int _transitionDuration = 1500; // Wipe duration

  final List<Map<String, String>> _steps = [
    {
      "title": "تواصل مع مريضك براحة...",
      "subtitle": "وخذ ملاحظاتك بالقلم كما تحب.",
      "image": "assets/images/landing/story_01_consult.jpg",
    },
    {
      "title": "دوّنت القياسات بسرعة...",
      "subtitle": "سجّل الملاحظة بعد الزيارة.",
      "image": "assets/images/landing/story_02_record.png",
    },
    {
      "title": "ملاحظتك جاهزة ومنسّقة...",
      "subtitle": "انسخ والصق في نظام المستشفى.",
      "image": "assets/images/landing/story_03_ehr.png",
    },
  ];

  @override
  void initState() {
    super.initState();
    _startLoop();
  }

  void _startLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: _displayDuration), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _steps.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MedColors.background,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      child: Column(
        children: [
          Text("كيف يعمل؟", style: Theme.of(context).textTheme.headlineMedium)
              .animate().fade().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 60),
          
          // The Cinematic Slider
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 600),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  children: [
                    // Background Layer (Next Image)
                    // Actually, we need to transition FROM prev TO current.
                    // But AnimatedSwitcher is tricky with the "Wipe".
                    // Let's use a custom TweenAnimationBuilder for the 'Wipe'.
                    
                    // We will overlay the Current Image ON TOP of the Previous Image.
                    // And 'Wipe' the Current Image IN from Right to Left.
                    
                    ScannerTransition(
                      key: ValueKey(_currentIndex),
                      imagePath: _steps[_currentIndex]['image']!,
                      prevImagePath: _steps[(_currentIndex - 1 + _steps.length) % _steps.length]['image']!,
                      duration: const Duration(milliseconds: _transitionDuration),
                    ),
                    
                    // Text Overlay (Always on top)
                    Positioned(
                      bottom: 40,
                      right: 40,
                      child: _buildTextOverlay(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOverlay() {
    final step = _steps[_currentIndex];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(_currentIndex), // Force rebuild
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
               step['title']!,
               style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               step['subtitle']!,
               style: const TextStyle(color: MedColors.primary, fontSize: 18),
             ),
          ],
        ),
      ),
    );
  }
}

class ScannerTransition extends StatefulWidget {
  final String imagePath;
  final String prevImagePath;
  final Duration duration;

  const ScannerTransition({
    super.key,
    required this.imagePath,
    required this.prevImagePath,
    required this.duration,
  });

  @override
  State<ScannerTransition> createState() => _ScannerTransitionState();
}

class _ScannerTransitionState extends State<ScannerTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Previous Image (Background) - Fully visible initially
        Image.asset(widget.prevImagePath, fit: BoxFit.cover),

        // 2. New Image (Foreground) - Revealed by the Wipe
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // value 0 -> 1
            // We want to wipe from Right to Left (since RTL language).
            // So we reveal from Right edge moving left.
            
            // ClipRect width = full width * value
            // Alignment: Alignment.centerRight
            
            return ClipRect(
              clipper: _WipeClipper(_controller.value),
              child: Stack(
                 fit: StackFit.expand,
                 children: [
                    Image.asset(widget.imagePath, fit: BoxFit.cover),
                    
                    // The Laser Beam Line (at the leading edge)
                    // Position depends on value
                    if (_controller.isAnimating)
                      NavigationToolbar( // Hack to get full width constraint? No, LayoutBuilder
                        
                      ),
                 ],
              ),
            );
            
            // Better approach: Use a Stack with Align + Width Factor is cleaner for "Revealing"
          }
        ),
        
        // Re-implementing Wipe Logic properly
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
             return LayoutBuilder(
               builder: (context, constraints) {
                 final width = constraints.maxWidth;
                 final progress = _controller.value;
                 final revealWidth = width * progress;
                 
                 return Stack(
                    children: [
                       // New Image (Clipped)
                       Positioned(
                         right: 0,
                         top: 0,
                         bottom: 0,
                         width: revealWidth, // Expands from Right
                         child: Image.asset(
                            widget.imagePath, 
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight, // Important to keep image static while clipping window moves
                         ),
                       ),
                       
                       // The Laser Line
                       if (_controller.value < 1.0)
                         Positioned(
                           right: revealWidth - 2, // At the edge
                           top: 0,
                           bottom: 0,
                           child: Container(
                             width: 4,
                             decoration: BoxDecoration(
                               color: Colors.white,
                               boxShadow: [
                                 BoxShadow(color: MedColors.primary, blurRadius: 15, spreadRadius: 5),
                                 BoxShadow(color: Colors.white, blurRadius: 5, spreadRadius: 1),
                               ]
                             ),
                           ),
                         ),
                    ],
                 );
               },
             );
          }
        ),
      ],
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  final double progress;
  _WipeClipper(this.progress);

  @override
  Rect getClip(Size size) {
    // Reveal from Right:
    // Rect from (Width - (Width*Progress)) to Width
    return Rect.fromLTWH(size.width * (1 - progress), 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.progress != progress;
}
