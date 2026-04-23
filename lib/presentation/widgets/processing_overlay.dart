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
    with TickerProviderStateMixin {
  // ── Ring rotation: 1 full revolution every 3 seconds ──
  late AnimationController _ringController;

  // ── Revolution counter (increments each full cycle) ──
  int _revolutions = 0;

  // ── Color cycling per revolution ──
  static const List<Color> _cycleColors = [
    Color(0xFF4A90E2), // Blue (original)
    Color(0xFFE291B3), // Soft pink
    Color(0xFF66BB9A), // Soft green
  ];
  Color get _currentColor => _cycleColors[_revolutions % _cycleColors.length];

  // ── Progress bar: fake progress over 15 seconds ──
  late AnimationController _barController;

  // ── Cycling message text ──
  int _messageIndex = 0;
  Timer? _messageTimer;
  String _currentMessage = "Processing...";

  @override
  void initState() {
    super.initState();

    // Ring spins once every 3 seconds — calm and smooth
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Increment revolution counter each time the ring completes a full cycle
    _ringController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _revolutions++);
        _ringController.forward(from: 0); // restart for next revolution
      }
    });
    _ringController.forward();

    // Progress bar fills to 100% over 15 seconds (easeOut curve)
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..forward();

    // Message cycling
    if (widget.cyclingMessages != null && widget.cyclingMessages!.isNotEmpty) {
      _currentMessage = widget.cyclingMessages![0];
      _startMessageCycling();
    } else {
      _currentMessage = widget.statusText ?? "جاري تحويل الصوت إلى نص...";
    }
  }

  void _startMessageCycling() {
    if (widget.cyclingMessages == null || widget.cyclingMessages!.isEmpty) return;
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % widget.cyclingMessages!.length;
          _currentMessage = widget.cyclingMessages![_messageIndex];
        });
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _barController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Circular Timer ────────────────────────────────
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle outer glow — color changes per revolution
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _currentColor.withValues(alpha: 0.18),
                          blurRadius: 40,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  // Background track ring (subtle)
                  CustomPaint(
                    painter: _TrackRingPainter(
                      color: _currentColor.withValues(alpha: 0.12),
                      strokeWidth: 5,
                    ),
                    size: const Size(140, 140),
                  ),

                  // Animated sweep ring — one revolution every 3 seconds
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _ringController.value * 2 * pi,
                        child: CustomPaint(
                          painter: _SweepRingPainter(
                            gradientColor: _currentColor,
                            strokeWidth: 5,
                          ),
                          size: const Size(140, 140),
                        ),
                      );
                    },
                  ),

                  // Revolution counter — smooth crossfade
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.85, end: 1.0)
                              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '$_revolutions',
                      key: ValueKey<int>(_revolutions),
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ─── Status Message ────────────────────────────────
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

            const SizedBox(height: 14),

            // ─── Progress Bar with leading percentage ──────────
            AnimatedBuilder(
              animation: _barController,
              builder: (context, child) {
                final curvedValue = Curves.easeOut.transform(_barController.value);
                final percent = (curvedValue * 100).toInt().clamp(0, 99);
                return SizedBox(
                  width: 280,
                  child: Row(
                    children: [
                      // Percentage label — in front of the bar
                      SizedBox(
                        width: 44,
                        child: Text(
                          '$percent%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _currentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // The progress bar itself
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: curvedValue,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(_currentColor),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background track ring (full circle, very faint) ────────────
class _TrackRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _TrackRingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Sweep gradient ring (animated arc) ─────────────────────────
class _SweepRingPainter extends CustomPainter {
  final Color gradientColor;
  final double strokeWidth;

  _SweepRingPainter({required this.gradientColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          gradientColor.withValues(alpha: 0.0),
          gradientColor.withValues(alpha: 0.35),
          gradientColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 1.75,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


