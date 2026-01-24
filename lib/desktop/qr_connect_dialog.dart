import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/connectivity_server.dart';

class QrConnectDialog extends StatefulWidget {
  const QrConnectDialog({super.key});

  @override
  State<QrConnectDialog> createState() => _QrConnectDialogState();
}

class _QrConnectDialogState extends State<QrConnectDialog> {
  String? _ipAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  Future<void> _loadIp() async {
    final ip = await ConnectivityServer.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _ipAddress = ip;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionUrl = "ws://$_ipAddress:8080";

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.qr_code_2, color: Colors.white),
          SizedBox(width: 10),
          Text("Connect Mobile", style: TextStyle(color: Colors.white)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(height: 200, width: 200, child: Center(child: CircularProgressIndicator(color: Colors.amber)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: QrImageView(
                    data: connectionUrl,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Scan with ScribeFlow Mobile",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    connectionUrl,
                    style: const TextStyle(color: Colors.white30, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close", style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}
