import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../core/theme.dart';

// Helper Widget for Rotating Text
class AnimatedLoadingText extends StatefulWidget {
  const AnimatedLoadingText({super.key});

  @override
  State<AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<AnimatedLoadingText> {
  final List<String> _states = [
    "Analyzing Transcript...",
    "Applying Medical Context...",
    "Structuring Note...",
    "Formatting...",
    "Finalizing Output..."
  ];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() => _index = (_index + 1) % _states.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2.5)),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(animation),
              child: child
            ));
          },
          child: Text(
            _states[_index],
            key: ValueKey<String>(_states[_index]),
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 13, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}
