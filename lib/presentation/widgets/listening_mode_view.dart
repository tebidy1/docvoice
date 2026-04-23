import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ListeningModeView extends StatefulWidget {
  final Future<double> Function() getAmplitude;
  final List<String> messages;

  const ListeningModeView({
    super.key,
    required this.getAmplitude,
    this.messages = const [
      'أنا أستمع ..',
      'اذكر المعلومات كنقاط ..',
      'وأنا أقوم بالصياغة',
      'تكلم بارتياح',
    ],
  });

  @override
  State<ListeningModeView> createState() => _ListeningModeViewState();
}

class _ListeningModeViewState extends State<ListeningModeView>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _coreGlowController;
  late List<AnimationController> _ringControllers;

  Timer? _amplitudePollTimer;
  Timer? _msgTimer;
  int _msgIndex = 0;

  // Smoothed amplitude for fluid animation
  double _currentAmplitude = 0.0;
  double _targetAmplitude = 0.0;
  // Peak amplitude for ring burst effect
  double _peakAmplitude = 0.0;

  @override
  void initState() {
    super.initState();

    // Slow breathing for idle state
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Core dot pulsation
    _coreGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // 4 expanding ring controllers with staggered start
    _ringControllers = List.generate(4, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1800 + index * 200),
      );
      Future.delayed(Duration(milliseconds: index * 400), () {
        if (mounted) controller.repeat();
      });
      return controller;
    });

    // Rotate messages every 3s
    _msgTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _msgIndex = (_msgIndex + 1) % widget.messages.length;
        });
      }
    });

    _startAmplitudePolling();
  }

  void _startAmplitudePolling() {
    // Poll every 50ms for high sensitivity
    _amplitudePollTimer =
        Timer.periodic(const Duration(milliseconds: 50), (_) async {
      if (!mounted) return;

      final amp = await widget.getAmplitude();
      if (!mounted) return;

      // Normalize amplitude (-160 to 0 or -60 to 0) → 0.0 to 1.0
      // Handle both ranges gracefully
      double normalized;
      if (amp < -100) {
        // -160 to 0 range (native STT)
        normalized = (amp.clamp(-160.0, 0.0) + 160) / 160;
      } else {
        // -60 to 0 range (record package)
        normalized = (amp.clamp(-60.0, 0.0) + 60) / 60;
      }

      // Aggressive exponential scaling for high sensitivity
      normalized = pow(normalized, 1.2).toDouble();

      // Boost low volumes to show even whispers
      if (normalized > 0.02) {
        normalized = 0.15 + normalized * 0.85;
      }

      _targetAmplitude = normalized.clamp(0.0, 1.0);

      // Track peak for ring burst
      if (_targetAmplitude > _peakAmplitude) {
        _peakAmplitude = _targetAmplitude;
      } else {
        _peakAmplitude *= 0.95; // Decay peak
      }

      // Smooth interpolation toward target
      setState(() {
        _currentAmplitude +=
            (_targetAmplitude - _currentAmplitude) * 0.3;
      });
    });
  }

  @override
  void dispose() {
    _amplitudePollTimer?.cancel();
    _msgTimer?.cancel();
    _breathController.dispose();
    _coreGlowController.dispose();
    for (var c in _ringControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111318),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // === Main animation area ===
            SizedBox(
              width: 280,
              height: 280,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _breathController,
                  _coreGlowController,
                  ..._ringControllers,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _PrecisionRingsPainter(
                      ringAnimations: _ringControllers,
                      amplitude: _currentAmplitude,
                      peakAmplitude: _peakAmplitude,
                      breathValue: _breathController.value,
                      coreGlowValue: _coreGlowController.value,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
            // === Arabic messages with fade transition ===
            SizedBox(
              height: 30,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  widget.messages[_msgIndex],
                  key: ValueKey(_msgIndex),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Color.lerp(
                      const Color(0xFF00D4FF),
                      const Color(0xFF80EEFF),
                      _currentAmplitude,
                    ),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00D4FF)
                            .withValues(alpha: 0.4 + _currentAmplitude * 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // === Equalizer bars ===
            _buildEqualizerBars(),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizerBars() {
    const barCount = 9;
    const barWidth = 3.0;
    const barSpacing = 5.0;
    const maxHeight = 32.0;
    const minHeight = 4.0;

    return SizedBox(
      height: maxHeight,
      child: AnimatedBuilder(
        animation: _breathController,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final phase = (i / barCount) * 2 * pi;
              final wave =
                  sin((_breathController.value * 2 * pi) + phase) * 0.5 + 0.5;

              // Higher sensitivity: bars react strongly to amplitude
              final amplitudeFactor = 0.15 + _currentAmplitude * 0.85;
              final height =
                  minHeight + (maxHeight - minHeight) * wave * amplitudeFactor;

              // Center bars are brightest
              final distFromCenter =
                  (i - barCount / 2).abs() / (barCount / 2);
              final brightness = 1.0 - distFromCenter * 0.4;

              // Color shifts with amplitude
              final barColor = Color.lerp(
                const Color(0xFF0088CC),
                const Color(0xFF00EEFF),
                _currentAmplitude * brightness,
              )!;

              return Container(
                margin: EdgeInsets.only(right: i < barCount - 1 ? barSpacing : 0),
                width: barWidth,
                height: height.clamp(minHeight, maxHeight),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.6 * _currentAmplitude),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Precision Rings Painter — thin, sharp, neon-glow rings
// ═══════════════════════════════════════════════════════════════
class _PrecisionRingsPainter extends CustomPainter {
  final List<Animation<double>> ringAnimations;
  final double amplitude;
  final double peakAmplitude;
  final double breathValue;
  final double coreGlowValue;

  _PrecisionRingsPainter({
    required this.ringAnimations,
    required this.amplitude,
    required this.peakAmplitude,
    required this.breathValue,
    required this.coreGlowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Base radius reacts to amplitude
    final baseRadius = 50.0 + amplitude * 25.0;

    // ── Expanding rings — thin, sharp, with neon glow ──
    for (int i = 0; i < ringAnimations.length; i++) {
      final t = ringAnimations[i].value;

      // Ring expands further when amplitude is high
      final maxRadius = baseRadius + 30.0 + i * 25.0 + amplitude * 35.0;
      final radius = baseRadius + (maxRadius - baseRadius) * t;

      // Opacity fades as ring expands
      final fadeOut = pow(1.0 - t, 2.0).toDouble();
      // Ring is brighter when amplitude is higher
      final ampBoost = 0.3 + amplitude * 0.7;
      final opacity = (fadeOut * ampBoost).clamp(0.0, 1.0);

      if (opacity <= 0.01) continue;

      // Thin, sharp stroke
      final strokeWidth = (1.5 - i * 0.15).clamp(0.5, 1.5);

      // Core ring (crisp, no blur)
      final ringPaint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, ringPaint);

      // Subtle outer glow (very tight blur for sharpness)
      final glowPaint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(center, radius, glowPaint);
    }

    // ── Static precision ring — always visible, reacts to voice ──
    final precisionRadius = baseRadius + 5.0;
    final precisionOpacity = (0.15 + amplitude * 0.35).clamp(0.0, 1.0);

    final precisionPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: precisionOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, precisionRadius, precisionPaint);

    // Glow on the precision ring
    final precisionGlowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: precisionOpacity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(center, precisionRadius, precisionGlowPaint);

    // ── Core dot — concentrated, intense, reacts to voice ──
    final coreSize = 4.0 + amplitude * 6.0 + coreGlowValue * 2.0;

    // Intense inner glow
    final innerGlowRadius = coreSize + 8.0 + amplitude * 12.0;
    final innerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.5 + amplitude * 0.5),
          const Color(0xFF00D4FF).withValues(alpha: 0.15 + amplitude * 0.15),
          const Color(0xFF00D4FF).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: innerGlowRadius),
      );
    canvas.drawCircle(center, innerGlowRadius, innerGlowPaint);

    // Core bright dot
    final corePaint = Paint()
      ..color = Color.lerp(
        const Color(0xFF00D4FF),
        const Color(0xFFFFFFFF),
        0.3 + amplitude * 0.5,
      )!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreSize, corePaint);

    // Core halo
    final haloPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.3 + amplitude * 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + amplitude * 4.0);
    canvas.drawCircle(center, coreSize + 2.0, haloPaint);
  }

  @override
  bool shouldRepaint(_PrecisionRingsPainter oldDelegate) => true;
}


