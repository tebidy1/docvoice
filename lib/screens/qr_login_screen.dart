import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../mobile_app/services/websocket_service.dart' as unified_ws;
import 'package:provider/provider.dart';
import 'dart:convert';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _pairingId;
  String? _pairingCode;
  bool _isLoading = true;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _initPairing();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initPairing() async {
    try {
      final response = await _apiService.get('/pairing/initiate');
      if (response['success'] == true) {
        setState(() {
          _pairingId = response['pairing_id'];
          _pairingCode = response['pairing_code'];
          _isLoading = false;
        });
        _listenForPairing();
      }
    } catch (e) {
      debugPrint("Pairing Init Failed: $e");
    }
  }

  void _listenForPairing() {
    final ws = context.read<unified_ws.WebSocketService>();
    // Note: In a real Reverb setup, we'd subscribe to the 'pairing.{pairingId}' channel.
    // For now, we assume the WS service is connected and we listen for a specific message pattern.
    
    _wsSubscription = ws.messages.listen((message) async {
       try {
         final data = jsonDecode(message.toString());
         if (data['event'] == 'pairing.success' && data['pairingId'] == _pairingId) {
            final token = data['token'];
            final userData = data['user'];
            
            if (token != null) {
              await _apiService.setToken(token);
              // Save user data if needed using the same logic as login
              // (AuthService usually handles this, so we might need a method there)
              
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            }
         }
       } catch (e) {
         // Silently ignore non-JSON or unrelated messages
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Login with QR Code",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Scan this code with your mobile app to login instantly",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : QrImageView(
                      data: 'pairing:$_pairingId',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
            ),
            const SizedBox(height: 30),
            if (!_isLoading && _pairingCode != null) ...[
              Text(
                "Or enter this code on your phone:",
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _pairingCode!,
                  style: GoogleFonts.robotoMono(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (!_isLoading)
              Text(
                "Session: ${_pairingId?.substring(0, 8)}...",
                style: GoogleFonts.robotoMono(color: Colors.white30, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}
