import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/api_config.dart';
import '../../android/services/websocket_service.dart' as unified_ws;
import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import 'extension_home_screen.dart';

/// Extension login screen — shows credentials form + QR code together.
/// QR is generated automatically (WhatsApp Web style).
class ExtensionLoginScreen extends StatefulWidget {
  const ExtensionLoginScreen({super.key});

  @override
  State<ExtensionLoginScreen> createState() => _ExtensionLoginScreenState();
}

class _ExtensionLoginScreenState extends State<ExtensionLoginScreen> {
  // ── QR state ─────────────────────────────────────────────────
  String? _pairingId;
  bool _qrLoading = true;
  String? _qrError;
  StreamSubscription? _wsSubscription;
  Timer? _refreshTimer;
  Timer? _pollTimer;

  // ── Login form state ──────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loginLoading = false;
  bool _obscure = true;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _initPairing();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _refreshTimer?.cancel();
    _pollTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── QR Pairing (raw HTTP — same endpoints as Dio/Windows) ───

  Future<void> _initPairing() async {
    setState(() {
      _qrLoading = true;
      _qrError = null;
    });
    try {
      final baseUrl = ApiConfig.baseUrl;
      final url = '$baseUrl/pairing/initiate';
      debugPrint('QR: Initiating pairing at $url');

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      debugPrint(
          'QR: Initiate response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pairingId = data['pairing_id'] ?? data['pairingId'] ?? data['id'];
        if (pairingId != null) {
          setState(() {
            _pairingId = pairingId.toString();
            _qrLoading = false;
          });
          _listenForPairing();
          _startPollTimer();
          // Auto-refresh QR every 2 minutes
          _refreshTimer?.cancel();
          _refreshTimer =
              Timer.periodic(const Duration(minutes: 2), (_) => _initPairing());
        } else {
          throw Exception('No pairing_id in response: $data');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('QR: Initiate error: $e');
      setState(() {
        _qrLoading = false;
        _qrError = 'تعذر توليد رمز QR: $e';
      });
    }
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pairingId == null) return;
      try {
        final baseUrl = ApiConfig.baseUrl;
        // Use correct endpoint: /pairing/check/{id} (same as Dio/Windows)
        final url = '$baseUrl/pairing/check/$_pairingId';

        final response = await http.get(
          Uri.parse(url),
          headers: ApiConfig.defaultHeaders,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('QR: Poll status: ${data['status']}');

          if (data['status'] == 'authorized' && data['token'] != null) {
            _pollTimer?.cancel();
            _refreshTimer?.cancel();

            // Save the token
            final apiClient = ApiClient();
            await apiClient.setToken(data['token']);

            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ExtensionHomeScreen()),
                (route) => false,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('QR: Poll error: $e');
      }
    });
  }

  void _listenForPairing() {
    try {
      final ws = context.read<unified_ws.WebSocketService>();
      _wsSubscription = ws.messages.listen((message) async {
        try {
          final data = jsonDecode(message.toString());
          if (data['event'] == 'pairing.success' &&
              data['pairingId'] == _pairingId) {
            final token = data['token'];
            if (token != null) {
              _pollTimer?.cancel();
              _refreshTimer?.cancel();
              final apiClient = ApiClient();
              await apiClient.setToken(token);
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const ExtensionHomeScreen()),
                  (route) => false,
                );
              }
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('WebSocket not available: $e');
    }
  }

  // ─── Credentials Login ────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      final success = await _authService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        deviceName: 'Chrome Extension',
      );
      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExtensionHomeScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _loginError = 'بيانات الدخول غير صحيحة';
          _loginLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loginError = 'خطأ في الاتصال بالخادم';
        _loginLoading = false;
      });
    }
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final primary = colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Logo ──────────────────────────────────
              Text(
                'ScribeFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Medical Dictation Companion',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: onSurface.withValues(alpha: 0.54)),
              ),

              const SizedBox(height: 24),

              // ── Login error ────────────────────────────
              if (_loginError != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_loginError!,
                      style: TextStyle(color: colorScheme.error, fontSize: 12)),
                ),

              // ── Form ──────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      controller: _emailCtrl,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      icon: Icons.lock_outlined,
                      obscure: _obscure,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: onSurface.withValues(alpha: 0.38),
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _loginLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loginLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary),
                              )
                            : const Text('Sign In',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── QR Divider ─────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: Divider(color: theme.dividerColor, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Or scan QR with your phone',
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.38),
                          fontSize: 11),
                    ),
                  ),
                  Expanded(
                      child: Divider(color: theme.dividerColor, thickness: 1)),
                ],
              ),

              const SizedBox(height: 14),

              // ── Instructions ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_android, color: primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'App → Settings → Scan QR to Authorize',
                    style: TextStyle(
                        color: onSurface.withValues(alpha: 0.54), fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── QR Code ────────────────────────────────
              Center(
                child: _qrError != null
                    ? Column(
                        children: [
                          Icon(Icons.wifi_off,
                              color: onSurface.withValues(alpha: 0.3),
                              size: 32),
                          const SizedBox(height: 6),
                          Text(_qrError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: colorScheme.error, fontSize: 11)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _initPairing,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : _qrLoading || _pairingId == null
                        ? Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                                child:
                                    CircularProgressIndicator(color: primary)),
                          )
                        : Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: 'pairing:$_pairingId',
                                  version: QrVersions.auto,
                                  size: 160.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _pollTimer?.cancel();
                                  _refreshTimer?.cancel();
                                  _initPairing();
                                },
                                icon: Icon(Icons.refresh,
                                    size: 13,
                                    color: onSurface.withValues(alpha: 0.3)),
                                label: Text('Generate New Code',
                                    style: TextStyle(
                                        color: onSurface.withValues(alpha: 0.3),
                                        fontSize: 11)),
                              ),
                            ],
                          ),
              ),

              const SizedBox(height: 16),
            ],
          ),
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
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(color: onSurface, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: onSurface.withValues(alpha: 0.38), fontSize: 12),
        prefixIcon:
            Icon(icon, color: onSurface.withValues(alpha: 0.38), size: 16),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
