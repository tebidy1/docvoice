import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../mobile_app/services/websocket_service.dart' as unified_ws;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'extension_home_screen.dart';

/// Extension-specific login screen that displays a QR code for the mobile app to scan.
/// This is similar to WhatsApp Web login flow.
class ExtensionLoginScreen extends StatefulWidget {
  const ExtensionLoginScreen({super.key});

  @override
  State<ExtensionLoginScreen> createState() => _ExtensionLoginScreenState();
}

class _ExtensionLoginScreenState extends State<ExtensionLoginScreen> {
  String? _pairingId;
  String? _pairingCode;
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  StreamSubscription? _wsSubscription;
  Timer? _refreshTimer;

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
    super.dispose();
  }

  Future<void> _initPairing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get('/pairing/initiate');
      if (response['success'] == true) {
        setState(() {
          _pairingId = response['pairing_id'];
          _pairingCode = response['pairing_code'];
          _isLoading = false;
        });
        _listenForPairing();
        _startRefreshTimer();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not initiate pairing. Please try again.";
        });
      }
    } catch (e) {
      debugPrint("Pairing Init Failed: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Connection error. Please check your network.";
      });
    }
  }

  Timer? _pollTimer;

  void _startRefreshTimer() {
    // Refresh QR code every 2 minutes to prevent expiration
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _initPairing();
    });
    
    // Poll for pairing status every 3 seconds (fallback if WebSocket not connected)
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pairingId == null) return;
      
      try {
        final response = await _apiService.get('/pairing/status/$_pairingId');
        
        if (response['status'] == 'authorized' && response['token'] != null) {
          _pollTimer?.cancel();
          
          final token = response['token'];
          await _apiService.setToken(token);
          
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ExtensionHomeScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        // Silently ignore polling errors
        debugPrint('Polling error: $e');
      }
    });
  }

  void _listenForPairing() {
    try {
      final ws = context.read<unified_ws.WebSocketService>();
      
      _wsSubscription = ws.messages.listen((message) async {
        try {
          final data = jsonDecode(message.toString());
          if (data['event'] == 'pairing.success' && data['pairingId'] == _pairingId) {
            final token = data['token'];
            
            if (token != null) {
              await _apiService.setToken(token);
              
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ExtensionHomeScreen()),
                  (route) => false,
                );
              }
            }
          }
        } catch (e) {
          // Silently ignore non-JSON or unrelated messages
        }
      });
    } catch (e) {
      debugPrint("WebSocket not available: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Text(
                  "ScribeFlow",
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Medical Dictation Companion",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.phone_android, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "Scan with your phone",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Open ScribeFlow app → Settings → Scan QR",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Display
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _initPairing,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 180,
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : QrImageView(
                            data: 'pairing:$_pairingId',
                            version: QrVersions.auto,
                            size: 180.0,
                          ),
                  ),

                const SizedBox(height: 24),

                // Manual Code Entry Option
                if (!_isLoading && _pairingCode != null) ...[
                  Text(
                    "Or enter this code on your phone:",
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _pairingCode!,
                      style: GoogleFonts.robotoMono(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Session Info
                if (!_isLoading && _pairingId != null)
                  Text(
                    "Session: ${_pairingId!.substring(0, 8)}...",
                    style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10),
                  ),

                const SizedBox(height: 24),

                // Refresh Button
                TextButton.icon(
                  onPressed: _initPairing,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                  label: Text(
                    "Generate New Code",
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
