import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isLast = index == totalSteps - 1;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 32 : 12,
              height: 12,
              decoration: BoxDecoration(
                color: isActive ? MedColors.primary : MedColors.divider,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (!isLast)
              const SizedBox(width: 8),
          ],
        );
      }),
    );
  }
}
