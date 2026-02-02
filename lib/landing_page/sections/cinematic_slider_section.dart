import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class CinematicSliderSection extends StatefulWidget {
  final bool isHeroMode;
  const CinematicSliderSection({super.key, this.isHeroMode = false});

  @override
  State<CinematicSliderSection> createState() => _CinematicSliderSectionState();
}

class _CinematicSliderSectionState extends State<CinematicSliderSection> {
  // ... existing state ...
  int _currentIndex = 0;
  Timer? _timer;
  static const int _displayDuration = 5000;
  static const int _transitionDuration = 1500;

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
    if (widget.isHeroMode) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              ScannerTransition(
                key: ValueKey(_currentIndex),
                imagePath: _steps[_currentIndex]['image']!,
                prevImagePath: _steps[(_currentIndex - 1 + _steps.length) % _steps.length]['image']!,
                duration: const Duration(milliseconds: _transitionDuration),
              ),
              // Simpler Overlay for Hero
              Positioned(
                bottom: 20,
                right: 20,
                left: 20,
                child: _buildTextOverlay(compact: true),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: MedColors.background,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      child: Column(
        children: [
          Text("قصة النجاح", style: Theme.of(context).textTheme.headlineMedium)
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
                    ScannerTransition(
                      key: ValueKey(_currentIndex),
                      imagePath: _steps[_currentIndex]['image']!,
                      prevImagePath: _steps[(_currentIndex - 1 + _steps.length) % _steps.length]['image']!,
                      duration: const Duration(milliseconds: _transitionDuration),
                    ),
                    
                    // Text Overlay
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

  Widget _buildTextOverlay({bool compact = false}) {
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
        key: ValueKey(_currentIndex), 
        padding: EdgeInsets.all(compact ? 12 : 24),
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
               style: TextStyle(
                  color: Colors.white, 
                  fontSize: compact ? 18 : 24, 
                  fontWeight: FontWeight.bold
               ),
             ),
             SizedBox(height: compact ? 4 : 8),
             Text(
               step['subtitle']!,
               style: TextStyle(
                  color: MedColors.primary, 
                  fontSize: compact ? 14 : 18
               ),
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
        Image.asset(widget.prevImagePath, fit: BoxFit.cover),
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
                       Positioned(
                         right: 0,
                         top: 0,
                         bottom: 0,
                         width: revealWidth, 
                         child: Image.asset(
                            widget.imagePath, 
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight, 
                         ),
                       ),
                       if (_controller.value < 1.0)
                         Positioned(
                           right: revealWidth - 2, 
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
    return Rect.fromLTWH(size.width * (1 - progress), 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.progress != progress;
}
