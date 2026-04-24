import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soutnote/core/brand/brand_colors.dart';
import '../auth/login_screen.dart';

/// 4-screen onboarding flow (Arabic + English, RTL aware).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _totalPages = 4;

  final _pages = const <_PageData>[
    _PageData(
      titleEn: 'Speak comfortably',
      titleAr: 'تحدّث براحة',
      bodyEn: 'Record your voice in seconds.',
      bodyAr: 'سجّل صوتك خلال ثوانٍ.',
      icon: _IllustrationKind.mic,
    ),
    _PageData(
      titleEn: 'We structure your note',
      titleAr: 'نحوّل صوتك لملاحظة مرتّبة',
      bodyEn: 'Voice → structured clinical note.',
      bodyAr: 'صوت → ملاحظة طبية منظمة.',
      icon: _IllustrationKind.clipboard,
    ),
    _PageData(
      titleEn: 'Templates ready',
      titleAr: 'قوالب جاهزة',
      bodyEn: 'Choose a template and copy into your HIS.',
      bodyAr: 'اختر القالب وانسخ للنظام.',
      icon: _IllustrationKind.templates,
    ),
    _PageData(
      titleEn: 'Enable microphone',
      titleAr: 'تفعيل الميكروفون',
      bodyEn: 'We only use audio to create your notes.',
      bodyAr: 'نستخدم الصوت فقط لإنشاء ملاحظاتك.',
      icon: _IllustrationKind.permission,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soutnote_onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  void _next() {
    if (_currentPage == _totalPages - 1) {
      _completeOnboarding();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() => _completeOnboarding();

  Future<void> _requestMic() async {
    await Permission.microphone.request();
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: BrandColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // ── Skip button ──────────────────────────────────
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 16, left: 16),
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(
                        'تخطي / Skip',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: BrandColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Page view ────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _totalPages,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
                  ),
                ),

                // ── Dots ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? BrandColors.primaryBlue
                            : BrandColors.inputBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // ── Buttons ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _currentPage == _totalPages - 1
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _requestMic,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'تفعيل / Enable',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _skip,
                              child: Text(
                                'تخطي / Skip',
                                style: GoogleFonts.cairo(
                                  color: BrandColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            if (_currentPage > 0)
                              TextButton(
                                onPressed: () => _pageCtrl.previousPage(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                ),
                                child: Text(
                                  'رجوع / Back',
                                  style: GoogleFonts.cairo(
                                    color: BrandColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _next,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 32),
                                ),
                                child: Text(
                                  'التالي / Next',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                SizedBox(height: mq.padding.bottom + 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────

enum _IllustrationKind { mic, clipboard, templates, permission }

class _PageData {
  final String titleEn, titleAr, bodyEn, bodyAr;
  final _IllustrationKind icon;

  const _PageData({
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────
//  Page widget
// ─────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(
              painter: _IllustrationPainter(kind: data.icon),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data.titleEn,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: BrandColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              data.titleAr,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: BrandColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.bodyEn,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: BrandColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              data.bodyAr,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 15,
                color: BrandColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Illustrations (CustomPainter – brand icon language)
// ─────────────────────────────────────────────────────────────

class _IllustrationPainter extends CustomPainter {
  final _IllustrationKind kind;
  _IllustrationPainter({required this.kind});

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _IllustrationKind.mic:
        _paintMic(canvas, size);
      case _IllustrationKind.clipboard:
        _paintClipboard(canvas, size);
      case _IllustrationKind.templates:
        _paintTemplates(canvas, size);
      case _IllustrationKind.permission:
        _paintPermission(canvas, size);
    }
  }

  // ── 1. Mic with sound-waves ──────────────────────────────
  void _paintMic(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 200;

    // Outer circle (light fill)
    canvas.drawCircle(
      Offset(cx, cy),
      70 * s,
      Paint()..color = BrandColors.primaryBlue.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      70 * s,
      Paint()
        ..color = BrandColors.accentCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );

    // Mic capsule
    final micFill = Paint()
      ..color = BrandColors.darkNavy
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 8 * s), width: 20 * s, height: 36 * s),
        Radius.circular(10 * s),
      ),
      micFill,
    );

    // Mic cup
    final micStroke = Paint()
      ..color = BrandColors.darkNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 2 * s), width: 40 * s, height: 30 * s),
      0, pi, false, micStroke,
    );

    // Stand
    canvas.drawLine(Offset(cx, cy + 17 * s), Offset(cx, cy + 30 * s), micStroke);
    canvas.drawLine(
      Offset(cx - 14 * s, cy + 30 * s),
      Offset(cx + 14 * s, cy + 30 * s),
      micStroke,
    );

    // Sound waves
    final wavePaint = Paint()
      ..color = BrandColors.accentCyan.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      final r = 30.0 * s + i * 14 * s;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + 40 * s, cy - 5 * s), width: r, height: r),
        -pi / 3, pi * 0.4, false, wavePaint..color = BrandColors.accentCyan.withValues(alpha: 0.7 - i * 0.15),
      );
    }
  }

  // ── 2. Clipboard with lines ──────────────────────────────
  void _paintClipboard(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final s = size.width / 200;
    final left = cx - 40 * s;

    final stroke = Paint()
      ..color = BrandColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = BrandColors.navy
      ..style = PaintingStyle.fill;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 40 * s, 80 * s, 120 * s),
        Radius.circular(8 * s),
      ),
      stroke,
    );

    // Clip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 16 * s, 34 * s, 32 * s, 14 * s),
        Radius.circular(3 * s),
      ),
      fill,
    );
    canvas.drawCircle(Offset(cx, 28 * s), 6 * s, fill);

    // Content lines (staggered)
    final lines = [0.88, 0.88, 0.65];
    for (int i = 0; i < 3; i++) {
      final y = (70 + i * 26) * s;
      final w = 56 * s * lines[i];
      // Checkbox
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 10 * s, y - 4 * s, 9 * s, 9 * s),
          Radius.circular(2 * s),
        ),
        stroke..strokeWidth = 2 * s,
      );
      // Line
      canvas.drawLine(
        Offset(left + 24 * s, y),
        Offset(left + 24 * s + w, y),
        stroke..strokeWidth = 3 * s,
      );
    }

    // Arrow animation hint (down arrow → text)
    final arrowPaint = Paint()
      ..color = BrandColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + 55 * s, 55 * s), Offset(cx + 55 * s, 95 * s), arrowPaint);
    canvas.drawLine(Offset(cx + 50 * s, 88 * s), Offset(cx + 55 * s, 95 * s), arrowPaint);
    canvas.drawLine(Offset(cx + 60 * s, 88 * s), Offset(cx + 55 * s, 95 * s), arrowPaint);
  }

  // ── 3. Templates (SOAP, Discharge, Referral) ──────────────
  void _paintTemplates(Canvas canvas, Size size) {
    final s = size.width / 200;
    // Labels for reference: SOAP, Discharge, Referral
    final colors = [BrandColors.primaryBlue, BrandColors.accentCyan, BrandColors.primaryDark];

    for (int i = 0; i < 3; i++) {
      final x = 20.0 * s + i * 18 * s;
      final y = 25.0 * s + i * 16 * s;
      final w = 120.0 * s;
      final h = 90.0 * s;

      // Card shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, y + 3, w, h),
          Radius.circular(10 * s),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.05)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
      );

      // Card bg
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(10 * s),
        ),
        Paint()..color = Colors.white,
      );

      // Card border
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(10 * s),
        ),
        Paint()
          ..color = colors[i].withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * s,
      );

      // Accent bar at top
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 12 * s, y + 10 * s, 30 * s, 4 * s),
          Radius.circular(2 * s),
        ),
        Paint()..color = colors[i],
      );

      // Mini lines
      for (int j = 0; j < 3; j++) {
        canvas.drawLine(
          Offset(x + 12 * s, y + 24 * s + j * 12 * s),
          Offset(x + (90 - j * 18) * s, y + 24 * s + j * 12 * s),
          Paint()
            ..color = BrandColors.inputBorder
            ..strokeWidth = 2 * s
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  // ── 4. Permission (shield + mic) ──────────────────────────
  void _paintPermission(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 200;

    // Shield shape
    final shield = Path()
      ..moveTo(cx, cy - 60 * s)
      ..quadraticBezierTo(cx + 55 * s, cy - 50 * s, cx + 50 * s, cy + 10 * s)
      ..quadraticBezierTo(cx + 30 * s, cy + 55 * s, cx, cy + 70 * s)
      ..quadraticBezierTo(cx - 30 * s, cy + 55 * s, cx - 50 * s, cy + 10 * s)
      ..quadraticBezierTo(cx - 55 * s, cy - 50 * s, cx, cy - 60 * s)
      ..close();

    canvas.drawPath(
      shield,
      Paint()..color = BrandColors.primaryBlue.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = BrandColors.primaryBlue.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s,
    );

    // Mic capsule inside shield
    final micFill = Paint()..color = BrandColors.darkNavy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 8 * s), width: 16 * s, height: 28 * s),
        Radius.circular(8 * s),
      ),
      micFill,
    );

    final micStroke = Paint()
      ..color = BrandColors.darkNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 2 * s), width: 32 * s, height: 24 * s),
      0, pi, false, micStroke,
    );
    canvas.drawLine(Offset(cx, cy + 14 * s), Offset(cx, cy + 24 * s), micStroke);
    canvas.drawLine(Offset(cx - 10 * s, cy + 24 * s), Offset(cx + 10 * s, cy + 24 * s), micStroke);

    // Checkmark
    final checkPaint = Paint()
      ..color = BrandColors.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final check = Path()
      ..moveTo(cx + 22 * s, cy + 32 * s)
      ..lineTo(cx + 30 * s, cy + 40 * s)
      ..lineTo(cx + 42 * s, cy + 26 * s);
    canvas.drawPath(check, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) => old.kind != kind;
}






