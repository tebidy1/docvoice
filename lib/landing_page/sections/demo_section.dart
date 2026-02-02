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
    // Medical Card Container
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: MedColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MedColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: MedColors.surface.withOpacity(0.5),
              border: Border(bottom: BorderSide(color: MedColors.divider)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: MedColors.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "جرّبها هنا الآن — ملاحظة طبية جاهزة خلال ثوانٍ",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                // Trust Badge (Moved from Hero)
                Tooltip(
                  message: "محسّن للهجات الإنجليزية للناطقين بالعربية",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MedColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MedColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                         const Icon(Icons.verified, size: 14, color: MedColors.success),
                         const SizedBox(width: 4),
                         Text("دقة عالية", style: TextStyle(fontSize: 12, color: MedColors.success.withOpacity(0.9), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),



          // 3. Main Interaction Area
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: _buildStageContent(),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _controller.selectedTemplate == label;
    final isProcessing = _controller.state == DemoState.recording || _controller.state == DemoState.processing;
    
    return InkWell(
      onTap: isProcessing ? null : () => _controller.selectTemplate(label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MedColors.primary.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? MedColors.primary : MedColors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? MedColors.primary : MedColors.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_controller.state) {
      case DemoState.idle:
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: TypewriterText(
                "سجّل ملاحظتك الطبية... اختر القالب... ملاحظتك جاهزة.",
                style: TextStyle(color: MedColors.textMuted, fontSize: 16, height: 1.5, fontFamily: 'monospace'),
              ),
            ),
            // Visual Input Box Placeholder
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: MedColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MedColors.divider),
              ),
              child: const Center(
                child: Text("اضغط الميكروفون للبدء...", style: TextStyle(color: MedColors.textMuted)),
              ),
            ),
            PulseMic(
              isRecording: false,
              onTap: _controller.startRecording,
            ),
            const SizedBox(height: 16),
             TextButton(
              onPressed: _controller.useSampleText,
              child: const Text("أو جرّب بنص مثال جاهز", style: TextStyle(color: MedColors.primary, decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 16),
          ],
        );
        
      case DemoState.recording:
        return Column(
          children: [
             const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text("جاري الاستماع...", style: TextStyle(color: MedColors.error, fontWeight: FontWeight.bold)),
            ),
            // Active Recording Box
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: MedColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MedColors.error.withOpacity(0.5)),
                boxShadow: [BoxShadow(color: MedColors.error.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Animate(
                    onPlay: (c) => c.repeat(reverse: true),
                    effects: [ScaleEffect(begin: const Offset(1,1), end: const Offset(1.02, 1.02), duration: 500.ms)],
                    child: const Icon(Icons.mic, color: MedColors.error, size: 40),
                  ),
                ],
              ),
            ),
            
            PulseMic(
              isRecording: true,
              onTap: _controller.stopRecording,
            ),
            const SizedBox(height: 16),
            Text(
              "00:${_controller.recordSeconds.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 24, fontFamily: 'monospace', color: Colors.white),
            ),
            const SizedBox(height: 24),
          ],
        );

      case DemoState.processing:
        return SizedBox(
           height: 300,
           child: Stack(
             children: [
               _buildOutputBox("النص المستخرج", "جاري المعالجة...", false),
               const LaserBeam(), // Processing Effect
             ],
           ),
        );

      case DemoState.templateSelection:
         return Column(
           children: [
             _buildOutputBox("النص المستخرج", _controller.transcribedText, false),
             const SizedBox(height: 24),
             
             const Text("اختر القالب للمتابعة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
             const SizedBox(height: 16),
             
             // Template Chips (Now appearing here)
             Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildChip("SOAP Note"),
                _buildChip("Radiology Request"),
                _buildChip("Progress Note"),
                _buildChip("Discharge Summary"),
              ],
            ).animate().fade().slideY(begin: 0.2, end: 0),
             
             const SizedBox(height: 24),
           ],
         );

      case DemoState.generating:
         return Column(
          children: [
            _buildOutputBox("النص المستخرج", _controller.transcribedText, false),
            const SizedBox(height: 24),
            SizedBox(
              height: 100, // Space for laser
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text("نولّد الملاحظة وفق القالب...", style: TextStyle(color: MedColors.textMuted)),
                  const LaserBeam(),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );

      case DemoState.finished:
        return Column(
          children: [
            _buildOutputBox("الملاحظة النهائية (${_controller.selectedTemplate})", _controller.formattedText, true),
            
            if (_controller.demoCompleted)
              _buildGatingBanner(),
              
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MedButton(
                  label: "ابدأ من جديد", 
                  onPressed: _controller.reset,
                  type: ButtonType.text,
                  icon: Icons.refresh,
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildOutputBox(String title, String content, bool isFeatured) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MedColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFeatured ? MedColors.success.withOpacity(0.5) : MedColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: isFeatured ? MedColors.success : MedColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: MedColors.textMuted),
                onPressed: () {
                   Clipboard.setData(ClipboardData(text: content));
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم النسخ!")));
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            content, 
            style: TextStyle(
              fontSize: 14, 
              height: 1.6, 
              fontFamily: isFeatured ? 'monospace' : null,
              color: Colors.white
            ),
            textDirection: TextDirection.ltr, // Medical notes usually English
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0);
  }

  Widget _buildGatingBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [MedColors.primary.withOpacity(0.1), MedColors.primary.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MedColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text("جاهز للمزيد؟", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            "سجّل الدخول لتجربة قوالب إضافية وحفظ إعداداتك وتشغيلها عبر الجوال/ويندوز/إضافة كروم.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MedColors.textMuted),
          ),
          const SizedBox(height: 16),
           MedButton(
              label: "سجّل الدخول وجرّب مرة أخرى",
              onPressed: () {}, // Redirect logic
              type: ButtonType.primary,
            ),
           const SizedBox(height: 8),
           const Text("يستغرق أقل من دقيقة.", style: TextStyle(fontSize: 11, color: MedColors.textMuted)),
        ],
      ),
    ).animate().fade(duration: 800.ms);
  }
}
