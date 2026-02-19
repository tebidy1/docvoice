import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProcessingOverlay extends StatefulWidget {
  final String? statusText;
  final List<String>? cyclingMessages;

  const ProcessingOverlay({
    super.key,
    this.statusText,
    this.cyclingMessages,
  });

  @override
  State<ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<ProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _progress = 0;
  
  // Cycling text state
  int _messageIndex = 0;
  Timer? _messageTimer;
  String _currentMessage = "Processing...";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Initial Message logic
    if (widget.cyclingMessages != null && widget.cyclingMessages!.isNotEmpty) {
      _currentMessage = widget.cyclingMessages![0];
      _startMessageCycling();
    } else {
      _currentMessage = widget.statusText ?? "Converting audio to text...";
    }

    _startSimulatedProgress();
  }
  
  void _startMessageCycling() {
    if (widget.cyclingMessages == null || widget.cyclingMessages!.isEmpty) return;
    
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % widget.cyclingMessages!.length;
          _currentMessage = widget.cyclingMessages![_messageIndex];
        });
      }
    });
  }

  void _startSimulatedProgress() {
    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
      if (!mounted) return false;
      
      setState(() {
        if (_progress < 30) {
           _progress += 2;
        } else if (_progress < 70) {
           _progress += 1;
        } else if (_progress < 95) {
           if (Random().nextBool()) _progress += 1;
        }
      });
      return _progress < 95;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom Ring Animation
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                   // Outer Glow
                   Container(
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: const Color(0xFF4A90E2).withOpacity(0.2),
                           blurRadius: 30,
                           spreadRadius: 10,
                         )
                       ]
                     ),
                   ),
                   // Spinner
                   AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 2 * pi,
                        child: CustomPaint(
                          painter: RingPainter(
                            gradientColor: const Color(0xFF4A90E2),
                          ),
                          size: const Size(100, 100),
                        ),
                      );
                    },
                   ),
                   // Percentage in Center
                   Text(
                     "$_progress%",
                     style: GoogleFonts.inter(
                       fontSize: 24,
                       fontWeight: FontWeight.bold,
                       color: Colors.white,
                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Text with Typing effect or just Fade
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _currentMessage,
                key: ValueKey(_currentMessage),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final Color gradientColor;

  RingPainter({required this.gradientColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          gradientColor.withOpacity(0.0),
          gradientColor,
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 1.8, // Open circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
