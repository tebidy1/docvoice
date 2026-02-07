import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/home_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;
  final AuthService _authService = AuthService();

  Future<void> _processPairing(String idOrCode, {bool isClaim = false}) async {
    print('🔍 Processing pairing: code=$idOrCode, isClaim=$isClaim');
    setState(() => _isProcessing = true);
    
    final bool success;
    if (isClaim) {
      print('📱 Calling claimPairing...');
      success = await _authService.claimPairing(
        idOrCode,
        deviceName: 'Mobile Device (${DateTime.now().hour}:${DateTime.now().minute})',
      );
    } else {
      print('🖥️ Calling authorizePairing...');
      success = await _authService.authorizePairing(
        idOrCode,
        deviceName: 'Desktop App (${DateTime.now().hour}:${DateTime.now().minute})',
      );
    }

    print('📊 Pairing result: success=$success, mounted=$mounted');

    if (mounted) {
      if (success) {
        print('✅ Success! Showing snackbar and navigating...');
        
        if (isClaim) {
          print('🏠 Navigating to home...');
          // Direct navigation to HomeScreen to avoid auth check race condition
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomeScreen()),
            (route) => false,
          );
          print('✅ Navigation completed');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logged In via QR!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Login Authorized!'),
              backgroundColor: Colors.green,
            ),
          );
          print('⬅️ Popping screen...');
          Navigator.pop(context);
        }
      } else {
        print('❌ Failed! Showing error...');
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Process failed or expired.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        if (code.startsWith('pairing:')) {
          _processPairing(code.replaceFirst('pairing:', ''), isClaim: false);
        } else if (code.startsWith('claim:')) {
          _processPairing(code.replaceFirst('claim:', ''), isClaim: true);
        }
      }
    }
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Enter 6-Digit Code', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            hintText: '123456',
            hintStyle: TextStyle(color: Colors.white24),
            counterStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.length == 6) {
                Navigator.pop(context);
                // Use authorize mode - this user is AUTHORIZING another device (Extension/Desktop)
                _processPairing(code, isClaim: false);
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan QR Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Scan the QR code on your Desktop screen',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard, color: Colors.blue),
                  label: const Text('Enter Code Manually', style: TextStyle(color: Colors.blue)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
