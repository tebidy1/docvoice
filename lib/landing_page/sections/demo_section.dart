import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/demo_controller.dart';
import '../theme/app_colors.dart';
import '../components/med_button.dart';
import '../components/pulse_mic.dart';
import '../components/typewriter_text.dart';
import '../components/laser_beam.dart';

class DemoSection extends StatefulWidget {
  const DemoSection({super.key});

  @override
  State<DemoSection> createState() => _DemoSectionState();
}

class _DemoSectionState extends State<DemoSection> {
  final DemoController _controller = DemoController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Overlapping Mic requires a Stack with overflow visible (or ample padding)
    // We'll use a Stack where the container has margin at the bottom to allow the Mic to overlap
    
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // 1. Main Card
        Container(
          margin: const EdgeInsets.only(bottom: 30), // Space for Mic overlap
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 800),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), 
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(24),
             child: Stack(
               children: [
                 // Laser Border Effect (Animated Gradient Border)
                 Positioned.fill(
                    child: const LaserBorder(),
                 ),
                 
                 // Inner Content
                 Container(
                   margin: const EdgeInsets.all(2), // To show the laser border
                   decoration: BoxDecoration(
                     color: const Color(0xFF0F172A),
                     borderRadius: BorderRadius.circular(22),
                   ),
                   padding: const EdgeInsets.fromLTRB(32, 40, 32, 60), // Extra bottom padding for Mic area
                   child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 100),
                      child: Center(child: _buildMinimalContent()),
                   ),
                 ),
               ],
             ),
          ),
        ),

        // 2. Overlapping Mic
        Positioned(
          bottom: 0, // Overlapping the bottom margin
          child: Transform.scale(
            scale: 0.8, // 20% smaller
            child: PulseMic(
              isRecording: _controller.state == DemoState.recording,
              onTap: () {
                 if (_controller.state == DemoState.recording) {
                   _controller.stopRecording();
                 } else if (_controller.state == DemoState.finished) {
                   _controller.reset();
                 } else {
                   _controller.startRecording();
                 }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalContent() {
    switch (_controller.state) {
      case DemoState.idle:
        return const TypewriterText(
          "جرب الان ..اضعط المايك وسجل ملاحظتك الطبيه",
          style: TextStyle(color: MedColors.textMuted, fontSize: 18, height: 1.6),
          speed: Duration(milliseconds: 50),
        );
        
      case DemoState.recording:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("جاري الاستماع...", style: TextStyle(color: MedColors.error, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              "00:${_controller.recordSeconds.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 32, fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.w300),
            ),
          ],
        );

      case DemoState.processing:
      case DemoState.templateSelection:
      case DemoState.generating:
         return Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text("جاري المعالجة...", style: TextStyle(color: MedColors.primary, fontSize: 16)),
             const SizedBox(height: 16),
             SizedBox(
               width: 200, height: 2,
               child: const LinearProgressIndicator(backgroundColor: Colors.transparent).animate().fade(),
             )
           ],
         );

      case DemoState.finished:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             SelectableText(
               _controller.formattedText,
               textAlign: TextAlign.center,
               style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
             ).animate().fade(),
             const SizedBox(height: 16),
             // Minimal Copy Hint
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: MedColors.success.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: MedColors.success.withOpacity(0.2)),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.check, size: 14, color: MedColors.success),
                   const SizedBox(width: 8),
                   Text("تم إنشاء الملاحظة بنجاح", style: TextStyle(color: MedColors.success.withOpacity(0.9), fontSize: 12)),
                 ],
               ),
             ),
          ],
        );

      default:
        return const SizedBox();
    }
  }
}

// Simple Laser Border Animation
class LaserBorder extends StatefulWidget {
  const LaserBorder({super.key});

  @override
  State<LaserBorder> createState() => _LaserBorderState();
}

class _LaserBorderState extends State<LaserBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: Alignment.center,
              colors: [
                Colors.transparent, 
                MedColors.primary, 
                Colors.white, 
                MedColors.primary, 
                Colors.transparent
              ],
              stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
              transform: GradientRotation(_controller.value * 6.28), // Rotate 360 deg
            ),
          ),
        );
      },
    );
  }
}
