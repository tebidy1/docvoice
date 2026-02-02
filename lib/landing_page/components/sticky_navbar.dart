import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StickyNavbar extends StatefulWidget {
  final ScrollController scrollController;

  const StickyNavbar({super.key, required this.scrollController});

  @override
  State<StickyNavbar> createState() => _StickyNavbarState();
}

class _StickyNavbarState extends State<StickyNavbar> {
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final offset = widget.scrollController.hasClients ? widget.scrollController.offset : 0;
    final isScrolled = offset > 10;
    if (isScrolled != _isScrolled) {
      if (mounted) setState(() => _isScrolled = isScrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 80,
      decoration: BoxDecoration(
        color: MedColors.background.withOpacity(_isScrolled ? 0.98 : 1.0),
        border: Border(
          bottom: BorderSide(
            color: _isScrolled ? MedColors.divider : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: _isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Logo Area
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MedColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: MedColors.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                'MedNote AI',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: MedColors.textMain,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Desktop Links (Hidden on small screens - TODO: Responsive)
          if (MediaQuery.of(context).size.width > 900)
            Row(
              children: [
                _NavLink(title: "كيف تعمل؟"),
                _NavLink(title: "القوالب"),
                _NavLink(title: "المنصات"),
                _NavLink(title: "الأمان"),
                _NavLink(title: "الأسعار"),
              ],
            ),
          
          const Spacer(),
          
          // Actions
          Row(
            children: [
              OutlinedButton(
                onPressed: () {},
                child: const Text("تسجيل الدخول"),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {},
                child: const Text("جرّب الآن مجانًا"),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  const _NavLink({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: () {},
        child: Text(
          title,
          style: const TextStyle(
            color: MedColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
