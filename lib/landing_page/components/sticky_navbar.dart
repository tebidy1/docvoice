import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';


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
    final offset =
        widget.scrollController.hasClients ? widget.scrollController.offset : 0;
    final isScrolled = offset > 10;
    if (isScrolled != _isScrolled) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isScrolled = isScrolled);
        });
      }
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
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24,
      ),
      child: Row(
        children: [
          // Logo Area
          Row(
            textDirection: TextDirection.ltr, // Keep Icon on the Left of Text
            children: [
              // 1. Icon
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(
                  'assets/images/logo_icon.svg',
                  height: 32,
                  width: 32,
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) => const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 2. Bilingual Text
              if (MediaQuery.of(context).size.width > 500)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Sout',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: 'Note',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: const Color(0xFF06B6D4), // Cyan
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.0,
                        ),
                        children: [
                          const TextSpan(text: 'صوت '),
                          const TextSpan(
                            text: 'ن',
                            style: TextStyle(color: Color(0xFF06B6D4)), // Cyan 'N'
                          ),
                          const TextSpan(text: 'وت'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const Spacer(),

          // Desktop Links (Hidden on small screens - TODO: Responsive)
          if (MediaQuery.of(context).size.width > 900)
            const Row(
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
              if (MediaQuery.of(context).size.width > 600) ...[
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text("تسجيل الدخول"),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: Text(
                  MediaQuery.of(context).size.width < 500 ? "جرّب الآن" : "جرّب الآن مجانًا",
                ),
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






