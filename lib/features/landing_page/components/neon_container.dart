import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dart:math' as math;

class NeonContainer extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final Color glowColor;

  const NeonContainer({
    super.key,
    required this.child,
    this.borderWidth = 3.0,
    this.glowColor = MedColors.primary,
  });

  @override
  State<NeonContainer> createState() => _NeonContainerState();
}

class _NeonContainerState extends State<NeonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Rotating Gradient Border
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: SweepGradient(
                    center: Alignment.center,
                    startAngle: 0,
                    endAngle: math.pi * 2,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      widget.glowColor.withOpacity(0.2),
                      widget.glowColor,
                      widget.glowColor.withOpacity(0.2),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.25, 0.4, 0.5, 0.6, 0.75, 1.0],
                    transform: GradientRotation(_controller.value * 2 * math.pi),
                  ),
                ),
              );
            },
          ),
        ),
        
        // 2. The Inner Content Mask (Hides the center of the gradient)
        Container(
          margin: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            color: MedColors.surface, // Match component bg
            borderRadius: BorderRadius.circular(24 - widget.borderWidth),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.4),
                 blurRadius: 20,
                 offset: const Offset(0, 10),
               )
             ],
          ),
          child: widget.child,
        ),
      ],
    );
  }
}
