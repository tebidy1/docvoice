import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: const BoxDecoration(
        color: MedColors.surface,
        border: Border(top: BorderSide(color: MedColors.divider)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              return isMobile 
                ? Column(
                    children: [
                      Text(
                        "© SoutNote — 2026",
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: MedColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink("الخصوصية"),
                          const SizedBox(width: 24),
                          _FooterLink("الشروط"),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "© SoutNote — 2026",
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: MedColors.textMuted,
                        ),
                      ),
                      Row(
                        children: [
                          _FooterLink("الخصوصية"),
                          const SizedBox(width: 24),
                          _FooterLink("الشروط"),
                        ],
                      ),
                    ],
                  );
            },
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String title;
  const _FooterLink(this.title);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Text(
        title,
        style: TextStyle(color: MedColors.textMuted, fontSize: 14),
      ),
    );
  }
}


