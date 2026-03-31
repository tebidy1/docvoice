import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class LaserBeam extends StatelessWidget {
  const LaserBeam({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Animate(
              onPlay: (controller) => controller.repeat(),
              effects: [
                MoveEffect(
                  begin: const Offset(0, -150),
                  end: Offset(0, constraints.maxHeight + 150),
                  duration: 2500.ms,
                  curve: Curves.easeInOut,
                ),
              ],
              child: Container(
                height: 40, // Height of the fade
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MedColors.primary.withOpacity(0),
                      MedColors.primary.withOpacity(0.4), // The beam
                      MedColors.primary.withOpacity(0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
                child: Center(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: MedColors.primary, blurRadius: 10, spreadRadius: 2),
                      ],
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
