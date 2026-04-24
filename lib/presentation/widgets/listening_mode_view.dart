import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  // Waveform history for the equalizer bars (FIFO buffer)
  final List<double> _waveHistory = List.filled(9, 0.0, growable: true);
  
  @override
  void initState() {
    super.initState();

    // Slightly faster breathing in idle
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Core dot fast pulsation
    _coreGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // 4 expanding ring controllers with staggered start
    _ringControllers = List.generate(4, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1400 + index * 150),
      );
      Future.delayed(Duration(milliseconds: index * 300), () {
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
    int _debugCounter = 0;
    // ⚡ Poll every 30ms for fast reaction time
    _amplitudePollTimer =
        Timer.periodic(const Duration(milliseconds: 30), (_) async {
      if (!mounted) return;

      final amp = await widget.getAmplitude();
      if (!mounted) return;

      // Debug: log every ~30th sample (≈1 second) to see actual values
      _debugCounter++;
      if (_debugCounter % 33 == 0) {
        debugPrint('🎤 Amplitude raw: $amp');
      }

      // ── Normalize amplitude to 0.0–1.0 ──
      // The `record` package on Android returns dBFS: typically -45 (silence) to 0 (max).
      // Normal speech sits around -30 to -10 dBFS.
      // Native STT ranges from -160 (silence) to 0 (max).
      double normalized;
      if (amp <= -100) {
        // -160 to 0 range (native STT or no signal)
        normalized = (amp.clamp(-160.0, 0.0) + 160) / 160;
      } else if (kIsWeb) {
        // Web browsers (via Web Audio API) typically report slightly lower dBFS than Android 
        final webAmp = (amp.clamp(-50.0, -10.0) + 50.0) / 40.0; // 0.0 to 1.0
        normalized = webAmp;
      } else if (amp < 0) {
        // Android/iOS record package: typically -45 to 0 dBFS
        // Use a TIGHT range (-40 to -5) so normal speech (which is -30 to -10)
        // maps to a wide output range instead of a tiny one
        final tightAmp = (amp.clamp(-40.0, -5.0) + 40.0) / 35.0; // 0.0 to 1.0
        normalized = tightAmp;
      } else {
        // Positive range (some Android devices)
        normalized = (amp / 32768.0).clamp(0.0, 1.0);
      }

      // Apply a sqrt curve to boost low/medium amplitude dramatically 
      // (sqrt is much more aggressive than pow(0.7))
      normalized = sqrt(normalized);

      // Ensure even quiet speech is visible
      if (normalized > 0.01) {
        normalized = 0.15 + normalized * 0.85;
      }

      _targetAmplitude = normalized.clamp(0.0, 1.0);

      // Track peak for ring burst
      if (_targetAmplitude > _peakAmplitude) {
        _peakAmplitude = _targetAmplitude;
      } else {
        _peakAmplitude *= 0.92;
      }

      // Update waveform history
      _waveHistory.removeAt(0);
      _waveHistory.add(_targetAmplitude);

      setState(() {
        // ⚡ ASYMMETRIC smoothing: rise FAST, fall slowly
        if (_targetAmplitude > _currentAmplitude) {
          _currentAmplitude += (_targetAmplitude - _currentAmplitude) * 0.7;
        } else {
          _currentAmplitude += (_targetAmplitude - _currentAmplitude) * 0.2;
        }
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
    const barWidth = 3.5;
    const barSpacing = 5.0;
    const maxHeight = 36.0;
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
              // ⚡ Each bar shows a slice of the waveform history
              // Left = oldest, Right = newest — like a scrolling waveform
              final historyValue = _waveHistory[i];
              
              // Add a sine-wave offset for natural-looking idle movement
              final phase = (i / barCount) * 2 * pi;
              final idleWave = sin((_breathController.value * 2 * pi) + phase) * 0.5 + 0.5;

              // Mix between idle animation and real amplitude data
              final mix = historyValue > 0.05 ? historyValue : idleWave * 0.25;
              final height = minHeight + (maxHeight - minHeight) * mix;

              // Center bars are brightest
              final distFromCenter = (i - barCount / 2).abs() / (barCount / 2);
              final brightness = 1.0 - distFromCenter * 0.3;

              // Color shifts cyan→white as voice gets louder
              final barColor = Color.lerp(
                const Color(0xFF0088CC),
                const Color(0xFF00EEFF),
                historyValue * brightness,
              )!;

              return Container(
                margin: EdgeInsets.only(right: i < barCount - 1 ? barSpacing : 0),
                width: barWidth,
                height: height.clamp(minHeight, maxHeight),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2.0),
                  boxShadow: historyValue > 0.2
                      ? [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.7 * historyValue),
                            blurRadius: 6,
                            spreadRadius: 0,
                          )
                        ]
                      : null,
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






