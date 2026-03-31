import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SecuritySection extends StatelessWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MedColors.background,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Icon(Icons.lock_outline, size: 64, color: MedColors.textMain),
              const SizedBox(height: 16),
              Text(
                "خصوصيتك أولًا",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  _buildCheckItem(context, "لا نضيف تعقيدًا على سير العمل"),
                  _buildCheckItem(context, "تحكم واضح في ما تُسجّله وما تُخرجه"),
                  _buildCheckItem(context, "مصمم لتقليل إدخال البيانات يدويًا"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: MedColors.success, size: 20),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
