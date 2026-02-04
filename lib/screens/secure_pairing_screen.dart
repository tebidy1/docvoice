import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';

class SecurePairingScreen extends StatefulWidget {
  const SecurePairingScreen({super.key});

  @override
  State<SecurePairingScreen> createState() => _SecurePairingScreenState();
}

class _SecurePairingScreenState extends State<SecurePairingScreen> {
  String? _pairingId;
  String? _pairingCode;
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initSecurePairing();
  }

  Future<void> _initSecurePairing() async {
    final response = await _authService.initiateSecurePairing();
    if (mounted) {
      if (response != null && response['success'] == true) {
        setState(() {
          _pairingId = response['pairing_id'];
          _pairingCode = response['pairing_code'];
          _isLoading = false;
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Failed to initiate pairing session")),
         );
         Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Link New Device", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Authorize Another Device",
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                "Scan this QR code from the login screen of your other device to sign in instantly.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: 'claim:$_pairingId',
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "Or enter this code manually:",
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _pairingCode ?? "------",
                    style: GoogleFonts.robotoMono(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      letterSpacing: 8,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              Text(
                "This code is valid for 5 minutes.",
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
