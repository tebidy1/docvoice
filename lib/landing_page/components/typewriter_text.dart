import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;

  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.speed = const Duration(milliseconds: 60),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedString = "";
  Timer? _timer;
  int _charIndex = 0;
  bool _showCursor = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _startCursorBlink();
  }

  void _startTyping() {
    _timer?.cancel();
    _charIndex = 0;
    _displayedString = "";
    
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_charIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _charIndex++;
            _displayedString = widget.text.substring(0, _charIndex);
          });
        }
      } else {
        timer.cancel();
      }
    });
  }
  
  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
       if(mounted) setState(() => _showCursor = !_showCursor);
    });
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTyping();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style ?? const TextStyle(color: MedColors.textMain, fontSize: 18),
        children: [
          TextSpan(text: _displayedString),
          TextSpan(
            text: "|",
            style: TextStyle(
              color: _showCursor ? MedColors.primary : Colors.transparent,
              fontWeight: FontWeight.w200
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    );
  }
}
