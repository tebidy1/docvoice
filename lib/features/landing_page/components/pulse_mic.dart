import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'dart:math' as math;

class PulseMic extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const PulseMic({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  @override
  State<PulseMic> createState() => _PulseMicState();
}

class _PulseMicState extends State<PulseMic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple 1
            if (widget.isRecording)
              _buildRipple(0),
            if (widget.isRecording)
              _buildRipple(1),
            
            // Core Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.isRecording ? MedColors.error : MedColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording ? MedColors.error : MedColors.primary).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  key: ValueKey(widget.isRecording),
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRipple(int delayFactor) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value + (delayFactor * 0.5)) % 1.0;
        final size = 72 + (value * 60); // Grow from 72 to 132
        final opacity = 1.0 - value; // Fade out
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MedColors.error.withOpacity(opacity * 0.5),
          ),
        );
      },
    );
  }
}
