import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../features/auth/pairing/presentation/providers/pairing_provider.dart';
import '../../../services/auth_service.dart';
import '../home/home_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _hasPermission = false;
  bool _isCameraStarted = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_hasPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isCameraStarted) {
          _controller.start();
          _isCameraStarted = true;
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_isCameraStarted) {
          _controller.stop();
          _isCameraStarted = false;
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      setState(() {
        _hasPermission = true;
      });
      // Give the widget a frame to mount before starting the controller
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _controller.start();
          if (mounted) {
            setState(() {
              _isCameraStarted = true;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _cameraError = "Failed to start camera: $e";
            });
          }
        }
      });
      return;
    }

    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        if (_hasPermission) {
          _controller.start().then((_) {
            if (mounted) setState(() => _isCameraStarted = true);
          }).catchError((e) {
            if (mounted)
              setState(() => _cameraError = "Camera start error: $e");
          });
        } else {
          _cameraError = "Camera permission is required to scan QR codes.";
        }
      });
    }
  }

  Future<void> _processPairing(String idOrCode, {bool isClaim = false}) async {
    print('🔍 Processing pairing: code=$idOrCode, isClaim=$isClaim');
    setState(() => _isProcessing = true);

    final bool success;
    if (isClaim) {
      print(
          '📱 Calling claimPairing via Legacy AuthService (Refactoring Pending)...');
      // For now, keep using AuthService for claim as it affects local state significantly
      final authService = AuthService();
      success = await authService.claimPairing(
        idOrCode,
        deviceName:
            'Mobile Device (${DateTime.now().hour}:${DateTime.now().minute})',
      );
    } else {
      print('🖥️ Calling authorizePairing via Riverpod...');
      success = await ref.read(pairingProvider.notifier).authorize(
            idOrCode,
            deviceName:
                'Desktop App (${DateTime.now().hour}:${DateTime.now().minute})',
          );
    }

    if (mounted) {
      if (success) {
        if (isClaim) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Logged In via QR!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Login Authorized!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
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
        title: Text('Enter 6-Digit Code',
            style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, letterSpacing: 8),
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
        title: Text('Scan QR Code',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (!_hasPermission)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography,
                        color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _cameraError ?? "Camera permission denied",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _checkPermission,
                      child: const Text("Grant Permission"),
                    ),
                  ],
                ),
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        "Camera Error: ${error.errorCode.name}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _controller.start(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              },
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
                  label: const Text('Enter Code Manually',
                      style: TextStyle(color: Colors.blue)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
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
