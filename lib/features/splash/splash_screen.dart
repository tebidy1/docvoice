import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:soutnote/core/services/auth_service.dart';
import 'package:soutnote/desktop/desktop_app.dart'
    if (dart.library.html) 'package:soutnote/desktop/desktop_app_stub.dart';
import 'package:soutnote/features/landing_page/landing_page.dart';

import 'package:soutnote/features/landing_page/theme/app_theme.dart';
import 'package:soutnote/shared/widgets/auth_guard.dart';
import 'package:soutnote/features/onboarding/onboarding_screen.dart';
import 'package:soutnote/features/auth/login_screen.dart';
import 'package:soutnote/features/home/home_screen.dart';

/// Full-screen splash with a 2.2 s "Record → Structure" animation.
/// After the animation:
///   • first-run  → OnboardingScreen
///   • returning + authenticated → HomeScreen
///   • returning + not auth → LoginScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Phase intervals (normalised to 0-1 over 2200 ms)
  // P1  0.00–0.055  bg settle
  // P2  0.055–0.145 clipboard appears
  // P3  0.145–0.227 badge appears (micro-bounce)
  // P4  0.227–0.386 pulse rings + wave ticks
  // P5  0.386–0.568 morph to text lines
  // P6  0.568–0.659 list items finalise
  // P7  0.659–0.818 wordmark
  // P8  0.818–1.000 hold

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _start();
  }


  Future<void> _start() async {
    // We want the splash to run for AT LEAST 2.2 seconds (the animation length).
    // If the auth request takes longer, we will timeout after 2.5s maximum to avoid blocking the user.
    _ctrl.forward();

    final prefsFuture = SharedPreferences.getInstance();
    final authFuture = AuthService().isAuthenticated().timeout(
          const Duration(milliseconds: 2500),
          onTimeout: () =>
              false, // fallback to login screen if network is too slow
        );

    // Wait for the animation to finish OR a reasonable timeout if it hangs
    final animFuture = _ctrl.forward().orCancel.catchError((_) {});

    // Run everything in parallel
    final results = await Future.wait([
      prefsFuture,
      authFuture,
      animFuture,
    ]);

    final prefs = results[0] as SharedPreferences;
    final isAuth = results[1] as bool;
    final firstRun = !(prefs.getBool('soutnote_onboarding_complete') ?? false);

    // Small hold so the final frame is clearly visible (100ms)
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    final isDesktopPlatform =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    Widget destination;

    if (firstRun) {
      destination = const OnboardingScreen();
    } else if (isAuth) {
      destination = isDesktopPlatform ? const DesktopApp() : const HomeScreen();
    } else {
      // If unauthenticated: Desktop/Web go to Landing, Mobile goes to LoginScreen
      if (isDesktopPlatform || kIsWeb) {
        destination = Theme(
          data: MedTheme.darkTheme,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: LandingHomeScaffold(),
          ),
        );
      } else {
        destination = const LoginScreen();
      }
    }

    // For DestkopApp, we also need AuthGuard:
    if (isAuth && destination is DesktopApp) {
      destination = AuthGuard(child: destination);
    } else if (isAuth && destination is HomeScreen) {
      destination = AuthGuard(child: destination);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────
  double _interval(double begin, double end) {
    final t = _ctrl.value;
    if (t <= begin) return 0.0;
    if (t >= end) return 1.0;
    return ((t - begin) / (end - begin)).clamp(0.0, 1.0);
  }

  double _ease(double t) => Curves.easeOut.transform(t);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // ── Phase values ────────────────────────────────────
          final clipOp = _ease(_interval(0.055, 0.145));
          final clipSc = 0.96 + 0.04 * _ease(_interval(0.055, 0.145));

          final badgeT = _interval(0.145, 0.227);
          final badgeOp = _ease(badgeT);
          double badgeSc;
          if (badgeT < 0.6) {
            badgeSc = 0.80 + 0.25 * (badgeT / 0.6);
          } else {
            badgeSc = 1.05 - 0.05 * ((badgeT - 0.6) / 0.4);
          }

          final pulseT = _interval(0.227, 0.386);
          final waveT = _interval(0.227, 0.386);

          final morphT = _interval(0.386, 0.568);
          final finalT = _interval(0.568, 0.659);

          final wordOp = _ease(_interval(0.659, 0.818));
          final wordSlide = 8.0 * (1.0 - _ease(_interval(0.659, 0.818)));

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ─────────────────────────────────────
                SizedBox(
                  width: 160,
                  height: 140,
                  child: CustomPaint(
                    painter: _SplashIconPainter(
                      theme: theme,
                      clipboardOpacity: clipOp,
                      clipboardScale: clipSc,
                      badgeOpacity: badgeOp,
                      badgeScale: badgeSc,
                      pulseProgress: pulseT,
                      waveProgress: waveT,
                      morphProgress: morphT,
                      finalizeProgress: finalT,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Wordmark ─────────────────────────────────
                Opacity(
                  opacity: wordOp,
                  child: Transform.translate(
                    offset: Offset(0, wordSlide),
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: 'Sout',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: 'Note',
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'صوت نوت',
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'استمع أكثر. اكتب أقل.',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // Fade in the bottom trust badge near the end of the animation
            final badgeOp = _ease(_interval(0.7, 1.0));
            return Opacity(
              opacity: badgeOp,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                child: Text(
                  'قوالب الملاحظات تتماشى مع توصيات SABAHI',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Custom painter – draws Clipboard + Badge + animations
// ═══════════════════════════════════════════════════════════════

class _SplashIconPainter extends CustomPainter {
  final ThemeData theme;
  final double clipboardOpacity;
  final double clipboardScale;
  final double badgeOpacity;
  final double badgeScale;
  final double pulseProgress;
  final double waveProgress;
  final double morphProgress;
  final double finalizeProgress;

  _SplashIconPainter({
    required this.theme,
    required this.clipboardOpacity,
    required this.clipboardScale,
    required this.badgeOpacity,
    required this.badgeScale,
    required this.pulseProgress,
    required this.waveProgress,
    required this.morphProgress,
    required this.finalizeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Reference coords from logo_icon.svg (90×85 logical space).
    final s = size.width / 110; // scale factor

    // ── 1) Clipboard ──────────────────────────────────────────
    if (clipboardOpacity > 0) {
      canvas.save();

      // Apply scale around clipboard centre.
      final cx = 25 * s;
      final cy = 50 * s;
      canvas.translate(cx, cy);
      canvas.scale(clipboardScale);
      canvas.translate(-cx, -cy);

      final stroke = Paint()
        ..color =
            theme.colorScheme.onSurface.withValues(alpha: clipboardOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * s
        ..strokeCap = StrokeCap.round;

      final fill = Paint()
        ..color =
            theme.colorScheme.onSurface.withValues(alpha: clipboardOpacity)
        ..style = PaintingStyle.fill;

      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 22 * s, 50 * s, 62 * s),
          Radius.circular(6 * s),
        ),
        stroke,
      );

      // Top clip rectangle
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(15 * s, 16 * s, 20 * s, 10 * s),
          Radius.circular(2 * s),
        ),
        fill,
      );

      // Top circle
      canvas.drawCircle(Offset(25 * s, 11 * s), 5 * s, fill);

      // ── Content lines (appear during morph/finalise) ──────
      if (morphProgress > 0) {
        for (int i = 0; i < 3; i++) {
          final stagger = (morphProgress - i * 0.20).clamp(0.0, 1.0);
          final lineOp = Curves.easeOut.transform(stagger.clamp(0.0, 1.0));
          final slideX = 4 * s * (1 - lineOp);
          final y = (38 + i * 15) * s;
          final endX = (i == 2 ? 32 : 40) * s;

          // Checkbox square
          final sqPaint = Paint()
            ..color = theme.colorScheme.onSurface
                .withValues(alpha: lineOp * clipboardOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH((8 + slideX / s) * s, (y - 3.5 * s), 7 * s, 7 * s),
              Radius.circular(1.5 * s),
            ),
            sqPaint,
          );

          // Text line
          final linePaint = Paint()
            ..color = theme.colorScheme.onSurface
                .withValues(alpha: lineOp * clipboardOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * s
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset((20 + slideX / s) * s, y),
            Offset(endX + slideX, y),
            linePaint,
          );
        }
      }

      canvas.restore();
    }

    // ── 2) Pulse rings ────────────────────────────────────────
    if (pulseProgress > 0 && pulseProgress < 1) {
      final ringCx = 68 * s;
      final ringCy = 22 * s;
      for (int i = 0; i < 2; i++) {
        final delay = i * 0.35;
        final t = ((pulseProgress - delay) / 0.65).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final radius = 20 * s + 18 * s * t;
        final opacity = (1.0 - t) * 0.5;
        canvas.drawCircle(
          Offset(ringCx, ringCy),
          radius,
          Paint()
            ..color = theme.colorScheme.primary.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s,
        );
      }
    }

    // ── 3) Badge (mic circle) ─────────────────────────────────
    if (badgeOpacity > 0) {
      canvas.save();

      final bCx = 68 * s;
      final bCy = 22 * s;
      canvas.translate(bCx, bCy);
      canvas.scale(badgeScale);
      canvas.translate(-bCx, -bCy);

      // White background circle + subtle shadow
      canvas.drawCircle(
        Offset(bCx, bCy + 1.5 * s),
        22 * s,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.06 * badgeOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
      );
      canvas.drawCircle(
        Offset(bCx, bCy),
        22 * s,
        Paint()..color = Colors.white.withValues(alpha: badgeOpacity),
      );

      // Cyan ring
      canvas.drawCircle(
        Offset(bCx, bCy),
        18 * s,
        Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: badgeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * s,
      );

      // Mic body (capsule)
      final micFill = Paint()
        ..color = theme.colorScheme.onSurface.withValues(alpha: badgeOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(65 * s, 12 * s, 6 * s, 12 * s),
          Radius.circular(3 * s),
        ),
        micFill,
      );

      // Mic cup arc
      final micStroke = Paint()
        ..color = theme.colorScheme.onSurface.withValues(alpha: badgeOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(68 * s, 21 * s), width: 14 * s, height: 10 * s),
        0,
        pi,
        false,
        micStroke,
      );

      // Mic stand
      canvas.drawLine(
        Offset(68 * s, 26.5 * s),
        Offset(68 * s, 31 * s),
        micStroke,
      );
      canvas.drawLine(
        Offset(64 * s, 31 * s),
        Offset(72 * s, 31 * s),
        micStroke,
      );

      // ── Sound-wave ticks (visible while recording, fade during morph)
      if (waveProgress > 0 && morphProgress < 1) {
        final waveOp = (1.0 - morphProgress) * badgeOpacity;
        final wavePaint = Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: waveOp * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..strokeCap = StrokeCap.round;

        final wobble = sin(waveProgress * pi * 4) * 2 * s;
        // Left tick
        canvas.drawLine(
          Offset(57 * s, (18 + wobble / s) * s),
          Offset(57 * s, (25 - wobble / s) * s),
          wavePaint,
        );
        // Right tick
        canvas.drawLine(
          Offset(79 * s, (17 - wobble / s) * s),
          Offset(79 * s, (26 + wobble / s) * s),
          wavePaint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SplashIconPainter old) => true;
}
