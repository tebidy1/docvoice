import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../components/med_button.dart';

class FinalCTASection extends StatelessWidget {
  final VoidCallback onStartNow;

  const FinalCTASection({
    super.key,
    required this.onStartNow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600, // Fixed height for impact
      child: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/cta_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2. Gradient Overlay (Darker at bottom for text)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MedColors.background.withOpacity(0.6),
                    MedColors.background,
                  ],
                  stops: const [0.0, 0.9],
                ),
              ),
            ),
          ),

          // 3. Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24), // Increased Padding
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "استعد وقتك المفقود مع العائلة.",
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontSize: 48, // Bigger impact
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                           Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "أنهِ عيادتك في وقتها تماماً. جرب MedNote AI الآن.",
                      style: TextStyle(color: MedColors.textMuted, fontSize: 20, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        MedButton(
                          label: "ابدأ الآن مجانًا",
                          onPressed: onStartNow,
                          type: ButtonType.primary,
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text("شاهد الفيديو التعريفي", style: TextStyle(color: Colors.white70)),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
