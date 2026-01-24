import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrPairingDialog extends StatelessWidget {
  final String ipAddress;
  final int port;

  const QrPairingDialog({
    super.key,
    required this.ipAddress,
    required this.port,
  });

  @override
  Widget build(BuildContext context) {
    final data = "$ipAddress:$port"; // Simple format for now

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Scan to Pair",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "IP: $ipAddress",
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }
}
