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
      'Listening...',
      'I\'m all ears...',
      'Speak now...',
      'Recording in progress...',
    ],
  });

  @override
  State<ListeningModeView> createState() => _ListeningModeViewState();
}

class _ListeningModeViewState extends State<ListeningModeView>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late List<AnimationController> _ringControllers;

  Timer? _amplitudePollTimer;
  Timer? _msgTimer;
  int _msgIndex = 0;

  double _normalizedAmplitude = 0.0;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringControllers = List.generate(3, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
      Future.delayed(Duration(milliseconds: index * 600), () {
        if (mounted) controller.repeat();
      });
      return controller;
    });

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
    _amplitudePollTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted) return;

      final amp = await widget.getAmplitude();

      // Normalize amplitude (-60 to 0) to (0.0 to 1.0)
      double normalized = (amp.clamp(-60.0, 0.0) + 60) / 60;
      // Exponential scaling for better visual punch
      normalized = pow(normalized, 1.5).toDouble();

      setState(() {
        _normalizedAmplitude = normalized;
      });
    });
  }

  @override
  void dispose() {
    _amplitudePollTimer?.cancel();
    _msgTimer?.cancel();
    _breathController.dispose();
    for (var c in _ringControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E), // Dark background matching desktop/mobile
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(
                painter: _ListeningRingsPainter(
                  ringAnimations: _ringControllers,
                  amplitude: _normalizedAmplitude,
                  breathAnimation: _breathController,
                ),
              ),
            ),
            const SizedBox(height: 50),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                widget.messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: const TextStyle(
                  color: Color(0xFF00A6FB),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildEqualizerBars(),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizerBars() {
    const barCount = 7;
    const barWidth = 4.0;
    const barSpacing = 6.0;
    const maxHeight = 30.0;
    const minHeight = 6.0;

    return SizedBox(
      height: maxHeight,
      child: AnimatedBuilder(
        animation: _breathController,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(barCount, (i) {
              final phase = (i / barCount) * 2 * pi;
              final wave = sin(
                      (_breathController.value * 2 * pi) + phase) *
                  0.5 +
                  0.5;
              final height = minHeight +
                  (maxHeight - minHeight) *
                      wave *
                      (0.3 + _normalizedAmplitude * 0.7);

              final distFromCenter =
                  (i - barCount / 2).abs() / (barCount / 2);
              final opacity = 1.0 - distFromCenter * 0.3;

              return Container(
                margin: const EdgeInsets.only(right: barSpacing),
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A6FB).withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ListeningRingsPainter extends CustomPainter {
  final List<Animation<double>> ringAnimations;
  final double amplitude;
  final Animation<double> breathAnimation;

  _ListeningRingsPainter({
    required this.ringAnimations,
    required this.amplitude,
    required this.breathAnimation,
  }) : super(
            repaint: Listenable.merge([
          ...ringAnimations,
          breathAnimation,
        ]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final baseRadius = 60.0 + amplitude * 30.0;

    for (int i = 0; i < ringAnimations.length; i++) {
      final t = ringAnimations[i].value;

      final maxRadius = baseRadius + 40.0 + i * 35.0 + amplitude * 30.0;
      final radius = baseRadius + (maxRadius - baseRadius) * t;

      final opacity = pow(1.0 - t, 2.5).toDouble();
      final ringColor = const Color(0xFF00A6FB);

      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = ringColor.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 - i * 0.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(center, radius, paint);
    }

    final glowRadius = baseRadius * 0.55 * breathAnimation.value;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00A6FB).withValues(alpha: 0.6 + amplitude * 0.4),
          const Color(0xFF00A6FB).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: glowRadius),
      );
    canvas.drawCircle(center, glowRadius, glowPaint);
  }

  @override
  bool shouldRepaint(_ListeningRingsPainter oldDelegate) =>
      oldDelegate.amplitude != amplitude;
}
