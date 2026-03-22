import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/brand/brand_colors.dart';
import '../../../services/auth_service.dart';
import '../../features/home/home_screen.dart';

/// Redesigned login screen – white background, brand blue accents,
/// static logo at top (continues splash's visual identity).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscure = true;

  late AnimationController _entranceCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _formOpacity;
  late Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut),
    );
    _formOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _formSlide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();
  }

  Future<void> _checkAuth() async {
    if (await AuthService().isAuthenticated() && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'الرجاء إدخال البريد الإلكتروني وكلمة المرور';
      });
      return;
    }

    try {
      final ok = await AuthService()
          .login(email, password, deviceName: 'Mobile Device');
      if (ok && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() => _error = 'بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      setState(() => _error = 'فشل تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Logo icon (static custom paint, matches splash icon)
  // ─────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return SizedBox(
      width: 110,
      height: 100,
      child: CustomPaint(painter: _LoginLogoPainter()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _entranceCtrl,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.06),

                  // ── Logo ─────────────────────────────────────
                  Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 14),
                          RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: 'Sout',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: BrandColors.darkNavy,
                                ),
                              ),
                              TextSpan(
                                text: 'Note',
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: BrandColors.primaryBlue,
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'صوت نوت',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: BrandColors.darkNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Form ─────────────────────────────────────
                  SlideTransition(
                    position: _formSlide,
                    child: FadeTransition(
                      opacity: _formOpacity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error message
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color:
                                    BrandColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      BrandColors.error.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: GoogleFonts.cairo(
                                  color: BrandColors.error,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                              ),
                            ),

                          // Email
                          _buildField(
                            controller: _emailCtrl,
                            label: 'البريد الإلكتروني / Email',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password
                          _buildField(
                            controller: _passwordCtrl,
                            label: 'كلمة المرور / Password',
                            icon: Icons.lock_outline,
                            obscure: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: BrandColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Login button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: BrandColors.primaryBlue,
                                disabledBackgroundColor: BrandColors.primaryBlue
                                    .withValues(alpha: 0.5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'تسجيل الدخول / Login',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Sync
                          TextButton.icon(
                            onPressed: _showSyncDialog,
                            icon: const Icon(Icons.sync,
                                color: BrandColors.accentCyan, size: 20),
                            label: Text(
                              'مزامنة مع جهاز / Sync',
                              style: GoogleFonts.cairo(
                                color: BrandColors.accentCyan,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('تواصل مع الإدارة للحصول على حساب'),
                                ),
                              ),
                              child: Text(
                                'تحتاج مساعدة؟ / Need help?',
                                style: GoogleFonts.cairo(
                                  color: BrandColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: BrandColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(
          color: BrandColors.textMuted,
          fontSize: 13,
        ),
        filled: true,
        fillColor: BrandColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: BrandColors.primaryBlue, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: BrandColors.textMuted, size: 20),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showSyncDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrandColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('أدخل رمز المزامنة',
            style: GoogleFonts.cairo(color: BrandColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'احصل على الرمز من الإعدادات > ربط جهاز جديد',
              style:
                  GoogleFonts.cairo(color: BrandColors.textMuted, fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: GoogleFonts.inter(
                color: BrandColors.navy,
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                hintText: '123456',
                hintStyle: TextStyle(color: BrandColors.textHint),
                counterStyle: TextStyle(color: BrandColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: GoogleFonts.cairo(color: BrandColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.length == 6) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final ok = await AuthService().claimPairing(code,
                    deviceName:
                        'Mobile (${DateTime.now().hour}:${DateTime.now().minute})');
                if (mounted) {
                  if (ok) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    );
                  } else {
                    setState(() {
                      _isLoading = false;
                      _error = 'رمز المزامنة غير صحيح أو منتهي الصلاحية';
                    });
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text('مزامنة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Static logo painter (clipboard + badge – same as splash final frame)
// ═══════════════════════════════════════════════════════════════

class _LoginLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;

    final stroke = Paint()
      ..color = BrandColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = BrandColors.navy;

    // Clipboard body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 20 * s, 50 * s, 62 * s),
        Radius.circular(5 * s),
      ),
      stroke,
    );
    // Clip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(15 * s, 15 * s, 20 * s, 10 * s),
        Radius.circular(2 * s),
      ),
      fill,
    );
    canvas.drawCircle(Offset(25 * s, 10 * s), 5 * s, fill);

    // Lines
    for (int i = 0; i < 3; i++) {
      final y = (36 + i * 15) * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8 * s, y - 3.5 * s, 7 * s, 7 * s),
          Radius.circular(1.5 * s),
        ),
        Paint()
          ..color = BrandColors.navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s,
      );
      canvas.drawLine(
        Offset(20 * s, y),
        Offset((i == 2 ? 35 : 42) * s, y),
        Paint()
          ..color = BrandColors.navy
          ..strokeWidth = 2.5 * s
          ..strokeCap = StrokeCap.round,
      );
    }

    // Badge
    final bCx = 62 * s;
    final bCy = 20 * s;
    // Shadow
    canvas.drawCircle(
      Offset(bCx, bCy + 1.5 * s),
      19 * s,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );
    canvas.drawCircle(Offset(bCx, bCy), 19 * s, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(bCx, bCy),
      15 * s,
      Paint()
        ..color = BrandColors.accentCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s,
    );
    // Mic
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(bCx, bCy - 3 * s), width: 6 * s, height: 11 * s),
        Radius.circular(3 * s),
      ),
      Paint()..color = BrandColors.darkNavy,
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(bCx, bCy + 1 * s), width: 12 * s, height: 9 * s),
      0,
      pi,
      false,
      Paint()
        ..color = BrandColors.darkNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
        Offset(bCx, bCy + 6 * s),
        Offset(bCx, bCy + 10 * s),
        Paint()
          ..color = BrandColors.darkNavy
          ..strokeWidth = 2 * s
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
