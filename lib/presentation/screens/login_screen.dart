import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/pairing/domain/entities/pairing_session.dart';
import '../../features/auth/pairing/presentation/providers/pairing_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/window_manager_proxy.dart';

/// Desktop login screen — shows credentials form + QR code side by side.
/// QR code is generated automatically on screen open (like WhatsApp Web).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    Future.microtask(() {
      ref.read(pairingProvider.notifier).initiate();
      ref.listen<AsyncValue<PairingSession?>>(pairingProvider, (prev, next) {
        next.whenData((session) {
          if (session != null && _pollingTimer == null) {
            _startPollingForQr(session.id);
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startPollingForQr(String pairingId) {
    if (_pollingTimer != null) return;
    final pairingNotifier = ref.read(pairingProvider.notifier);
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await pairingNotifier.checkStatus(pairingId);
        if (result['success'] == true && result['status'] == 'authorized') {
          final token = result['token'];
          if (token != null) {
            _stopPolling();
            final apiClient = ApiClient();
            await apiClient.setToken(token);
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/');
            }
          }
        } else if (result['success'] == false) {
          _stopPolling();
        }
      } catch (e) {
        debugPrint('QR polling error: $e');
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('remembered_email') ?? '';
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = rememberMe;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', _emailController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remembered_email');
        await prefs.setBool('remember_me', false);
      }
    } catch (_) {}
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final success = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
        deviceName: 'Desktop App',
      );
      if (success && mounted) {
        await _saveCredentials();
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        setState(() {
          _errorMessage = 'بيانات الدخول غير صحيحة';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairingState = ref.watch(pairingProvider);
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          // Drag handle for frameless window
          if (isDesktop)
            GestureDetector(
              onPanStart: (_) => windowManager.startDragging(),
              child: Container(height: 32, color: Colors.transparent),
            ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ──────────────────────────────────
                    const SizedBox(height: 4),
                    Text(
                      'ScribeFlow',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: Colors.white54),
                    ),

                    const SizedBox(height: 20),

                    // ── Error ──────────────────────────────────
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),

                    // ── Email ──────────────────────────────────
                    _buildField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        if (!v.contains('@')) return 'بريد غير صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // ── Password ───────────────────────────────
                    _buildField(
                      controller: _passwordController,
                      label: 'كلمة المرور',
                      icon: Icons.lock_outlined,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        if (v.length < 6) return 'قصيرة جداً';
                        return null;
                      },
                    ),

                    // ── Remember me ────────────────────────────
                    Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Checkbox(
                            value: _rememberMe,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            activeColor: const Color(0xFF4FC3F7),
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: const Text('تذكرني',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),

                    // ── Login button ───────────────────────────
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : Text('تسجيل الدخول',
                                style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── QR Divider ─────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                            child:
                                Divider(color: Colors.white24, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'أو سجّل الدخول بـ QR',
                            style: GoogleFonts.cairo(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ),
                        const Expanded(
                            child:
                                Divider(color: Colors.white24, thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Instructions ───────────────────────────
                    Text(
                      'افتح التطبيق على هاتفك ← الإعدادات ← Scan QR to Authorize',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          color: Colors.white38, fontSize: 11),
                    ),

                    const SizedBox(height: 12),

                    // ── QR Code ────────────────────────────────
                    pairingState.when(
                      data: (session) {
                        if (session == null) {
                          return const Center(
                              child: SizedBox(
                            height: 170,
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF4FC3F7))),
                          ));
                        }
                        return Center(
                          child: Column(
                            children: [
                              // QR code card
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4FC3F7)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: QrImageView(
                                  data: 'pairing:${session.id}',
                                  version: QrVersions.auto,
                                  size: 160.0,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Refresh button
                              TextButton.icon(
                                onPressed: () {
                                  _stopPolling();
                                  ref.read(pairingProvider.notifier).initiate();
                                },
                                icon: const Icon(Icons.refresh,
                                    size: 13, color: Colors.white30),
                                label: Text('تجديد الرمز',
                                    style: GoogleFonts.cairo(
                                        color: Colors.white30, fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 170,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF4FC3F7))),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off,
                                color: Colors.white30, size: 32),
                            const SizedBox(height: 6),
                            Text('تعذر توليد رمز QR',
                                style: GoogleFonts.cairo(
                                    color: Colors.white38, fontSize: 12)),
                            TextButton(
                              onPressed: () =>
                                  ref.read(pairingProvider.notifier).initiate(),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    );
  }
}
