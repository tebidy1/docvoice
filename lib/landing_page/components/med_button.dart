import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ButtonType { primary, outline, text }

class MedButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final ButtonType type;
  final IconData? icon;

  const MedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
  });

  @override
  State<MedButton> createState() => _MedButtonState();
}

class _MedButtonState extends State<MedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(milliseconds: 150), vsync: this
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    switch (widget.type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isHovered ? MedColors.primaryDark : MedColors.primary,
          ),
          child: _buildContent(),
        );
      case ButtonType.outline:
        return OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: _isHovered ? MedColors.primaryDark : MedColors.primary, 
              width: 1.5
            ),
          ),
          child: _buildContent(),
        );
      case ButtonType.text:
        return TextButton(
          onPressed: widget.onPressed,
          child: _buildContent(),
        );
    }
  }

  Widget _buildContent() {
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Text(widget.label),
        ],
      );
    }
    return Text(widget.label);
  }
}
