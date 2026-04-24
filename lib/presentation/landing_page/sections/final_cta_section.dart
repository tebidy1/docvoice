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
          // 1. Background Gradient (Replaced missing asset with professional medical-themed gradient)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B1F3B), // Navy from logo
                    Color(0xFF082E5A),
                    Color(0xFF06B6D4), // Cyan from logo
                  ],
                ),
              ),
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
                        fontSize: MediaQuery.of(context).size.width < 600 ? 32 : 48,
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
                      "أنهِ عيادتك في وقتها تماماً. جرب SoutNote الآن.",
                      style: TextStyle(color: MedColors.textMuted, fontSize: 16, height: 1.6),
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






