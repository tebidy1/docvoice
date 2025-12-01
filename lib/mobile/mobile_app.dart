import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_client.dart';
import '../services/audio_recorder_service.dart';
import 'qr_scanner_screen.dart';

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  bool _isRecording = false;
  final ConnectivityClient _client = ConnectivityClient();
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  String _status = "Disconnected";
  StreamSubscription? _audioSubscription;

  @override
  void initState() {
    super.initState();
    _client.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });
  }

  Future<void> _connectToDesktop() async {
    // Temporary: Ask for IP
    final ipController = TextEditingController(text: "192.168.1.x");
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connect to Desktop"),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(labelText: "Desktop IP Address"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _client.connect(ipController.text);
              Navigator.pop(context);
            },
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!_client.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not connected to Desktop")),
      );
      return;
    }

    try {
      _client.startStreaming(); // Send Start Signal
      final stream = await _audioRecorder.startRecording();
      setState(() => _isRecording = true);
      
      _audioSubscription = stream.listen((data) {
        _client.sendAudioChunk(data);
      });
    } catch (e) {
      print("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stopRecording();
    await _audioSubscription?.cancel();
    _client.stopStreaming(); // Send Stop Signal
    setState(() => _isRecording = false);
  }

  @override
  void dispose() {
    _client.disconnect();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // OLED Black
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ScribeFlow Mobile",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                      );
                      
                      if (result != null && result is String) {
                        // Parse IP and Port
                        // Format: IP:Port
                        final parts = result.split(':');
                        if (parts.length >= 1) {
                          final ip = parts[0];
                          final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 8080 : 8080;
                          _client.connect(ip, port: port);
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _client.isConnected ? Icons.link : Icons.link_off, 
                      color: _client.isConnected ? Colors.green : Colors.red
                    ),
                    onPressed: _connectToDesktop,
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Giant Mic Button
            Center(
              child: GestureDetector(
                onTap: () {
                  if (_isRecording) {
                    _stopRecording();
                  } else {
                    _startRecording();
                  }
                },
                onLongPress: _startRecording,
                onLongPressUp: _stopRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 220 : 200,
                  height: _isRecording ? 220 : 200,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red.withOpacity(0.2) : const Color(0xFF1E1E1E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecording ? Colors.red : const Color(0xFF007AFF),
                      width: 4,
                    ),
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : const Color(0xFF007AFF),
                    size: 80,
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Status Text
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Text(
                _isRecording ? "Recording..." : (_client.isConnected ? "Tap to Record" : "Tap Link to Connect"),
                style: TextStyle(
                  color: _isRecording ? Colors.red : Colors.white38,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
