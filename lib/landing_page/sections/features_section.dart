import 'package:flutter/material.dart';
import '../components/feature_card.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              SizedBox(
                width: 350,
                child: FeatureCard(
                  icon: Icons.headphones,
                  title: "دقة تسمع ما تقصده",
                  description: "مدرّبة على اللهجات واللكنات والإنجليزية غير المتقنة لتقليل التصحيح.",
                ),
              ),
              SizedBox(
                width: 350,
                child: FeatureCard(
                  icon: Icons.extension,
                  title: "قوالب جاهزة",
                  description: "قوالب معدّة لتخرج ملاحظات طبية منظمة بسرعة بمجرد اختيارك لها.",
                ),
              ),
              SizedBox(
                width: 350,
                child: FeatureCard(
                  icon: Icons.directions_run,
                  title: "سجّل أثناء الحركة",
                  description: "سجّل أثناء الراوند عبر الجوال، وأكمل المعالجة لاحقًا من المكتب.",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
