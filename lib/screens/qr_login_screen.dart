import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../features/auth/pairing/presentation/providers/pairing_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class QrLoginScreen extends ConsumerStatefulWidget {
  const QrLoginScreen({super.key});

  @override
  ConsumerState<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends ConsumerState<QrLoginScreen> {
  final AuthService _authService = AuthService();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pairingProvider.notifier).initiate());
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _listenForPairing(String pairingId) {
    if (_pollingTimer != null) return;

    final pairingNotifier = ref.read(pairingProvider.notifier);

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final result = await pairingNotifier.checkStatus(pairingId);

        if (result['success'] == true && result['status'] == 'authorized') {
          final token = result['token'];
          if (token != null) {
            _stopPolling();
            final ApiService apiService = ApiService();
            await apiService.setToken(token);
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/');
            }
          }
        } else if (result['success'] == false) {
          // If session expired or error, stop polling
          _stopPolling();
        }
      } catch (e) {
        debugPrint("Error during pairing polling: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pairingState = ref.watch(pairingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: pairingState.when(
          data: (session) {
            if (session == null) return const CircularProgressIndicator();

            // Start listening for WS events once we have the ID
            _listenForPairing(session.id);

            return Column(
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
                  child: QrImageView(
                    data: 'pairing:${session.id}',
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 30),
                if (session.shortCode != null) ...[
                  Text(
                    "Or enter this code on your phone:",
                    style:
                        GoogleFonts.inter(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      session.shortCode!,
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
                Text(
                  "Session: ${session.id.substring(0, 8)}...",
                  style: GoogleFonts.robotoMono(
                      color: Colors.white30, fontSize: 10),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, st) => Center(
            child: Text(
              "Error: $e",
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
