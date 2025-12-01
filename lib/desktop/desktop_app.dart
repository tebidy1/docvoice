import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/connectivity_server.dart';
import '../services/keyboard_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/inbox_service.dart';
import '../services/gemini_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/wav_utils.dart';
import 'qr_pairing_dialog.dart';
import 'macro_manager_dialog.dart';
import 'inbox_manager_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../utils/window_manager_helper.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  final ConnectivityServer _server = ConnectivityServer();
  final KeyboardService _keyboard = KeyboardService();
  final AudioRecorderService _recorder = AudioRecorderService();
  final InboxService _inboxService = InboxService();
  late final GeminiService _geminiService;
  
  String _status = "Initializing...";
  String _ipAddress = "Loading...";
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
    _startServer();
    _listInputDevices();
    
    // Position window after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _positionWindowToRightCenter();
    });
  }

  Future<void> _positionWindowToRightCenter() async {
    try {
      // Get primary display (actual screen)
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      final windowSize = await windowManager.getSize();
      
      // Calculate position: far right, centered vertically
      final x = screenSize.width - windowSize.width - 10; // 10px margin from edge
      final y = (screenSize.height - windowSize.height) / 2;
      
      await windowManager.setPosition(Offset(x, y));
      
      print("Window positioned at: ($x, $y)");
      print("Screen size: ${screenSize.width}x${screenSize.height}");
      print("Window size: ${windowSize.width}x${windowSize.height}");
    } catch (e) {
      print("Error positioning window: $e");
    }
  }

  Future<void> _dockWindow() async {
    if (mounted) {
      await WindowManagerHelper.dockToRight(context);
    }
  }

  Future<void> _listInputDevices() async {
    try {
      final devices = await _recorder.listInputDevices();
      print("Available Input Devices:");
      for (var device in devices) {
        print("- ${device.label} (ID: ${device.id})");
      }
    } catch (e) {
      print("Error listing devices: $e");
    }
  }

  Future<void> _startServer() async {
    await _server.startServer();
    final ip = await ConnectivityServer.getLocalIpAddress();
    setState(() {
      _ipAddress = ip;
    });
    
    _server.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });

    _server.audioStream.listen((audioChunk) {
      print("Received Audio Chunk: ${audioChunk.length} bytes");
    });

    _server.textStream.listen((text) async {
      if (text.trim().isEmpty) {
        print("Skipping: Text is empty");
        return;
      }
      
      print("Received transcription: '$text'");
      
      // Analyze with Gemini
      final analysis = await _geminiService.analyzeNote(text);
      
      // Save to Inbox
      await _inboxService.addNote(
        text,
        patientName: analysis['patientName'],
        summary: analysis['summary'],
      );
      
      print("Added to Smart Inbox: ${analysis['patientName']}");
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📥 Saved: ${analysis['patientName']}"),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Timer? _amplitudeTimer;
  double _currentVolume = 0.0;

  Future<void> _toggleRecording() async {
    print("Mic Button Tapped. Current State: Recording=$_isRecording");
    
    if (_isRecording) {
      // Stop
      _amplitudeTimer?.cancel();
      setState(() => _currentVolume = 0.0);
      
      print("Stopping recording...");
      try {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _status = "Processing...";
        });
        
        if (path != null) {
          print("Recording saved to: $path");
          final file = File(path);
          
          // Check if file exists
          if (!await file.exists()) {
            print("ERROR: Recording file does not exist at $path");
            setState(() => _status = "Error: File not found");
            return;
          }
          
          // Check file size
          final fileSize = await file.length();
          print("Recording file size: $fileSize bytes");
          
          if (fileSize == 0) {
            print("ERROR: Recording file is empty (0 bytes)");
            setState(() => _status = "Error: Empty recording");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Recording failed: File is empty. Please check microphone permissions."),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            await file.delete();
            return;
          }
          
          final bytes = await file.readAsBytes();
          print("Read ${bytes.length} bytes from recording file");
          
          await _server.transcribeWav(bytes);
          
          // Cleanup
          await file.delete();
        } else {
          print("ERROR: Recorder returned null path");
          setState(() => _status = "Error: No file");
        }
      } catch (e) {
        print("Error stopping: $e");
        setState(() => _status = "Error: $e");
      }
    } else {
      // Start
      print("Starting recording...");
      try {
        if (!await _recorder.hasPermission()) {
          print("Permission denied");
          setState(() => _status = "Permission Denied");
          return;
        }
        
        // Get temp path
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/temp_recording.wav';
        
        await _recorder.startRecordingToFile(path);
        
        // Start Visualizer Timer
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
          final amp = await _recorder.getAmplitude();
          final db = amp.current;
          double vol = (db + 60) / 60;
          if (vol < 0) vol = 0;
          if (vol > 1) vol = 1;
          
          if (mounted) {
            setState(() => _currentVolume = vol);
          }
        });

        print("Recording started successfully to $path");
        setState(() {
          _isRecording = true;
          _status = "Recording...";
        });
      } catch (e) {
        print("Error recording: $e");
        setState(() {
          _status = "Mic Error";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Mic Error: $e"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _server.stopServer();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final isConnected = _status.contains("Client Connected");
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main floating bar
          Center(
            child: GestureDetector(
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: Container(
                width: 300,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xDD1E1E1E),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Drag Handle
                    const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                    
                    // Status Dot
                    Tooltip(
                      message: "$_status\nIP: $_ipAddress\nTap to Pair",
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => QrPairingDialog(
                              ipAddress: _ipAddress,
                              port: 8080,
                            ),
                          );
                        },
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    
                    // Mic Button with Visualizer
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isRecording)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            width: 40 + (_currentVolume * 40),
                            height: 40 + (_currentVolume * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                        
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleRecording,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.red : Colors.white10,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isRecording ? Colors.redAccent : Colors.white24, 
                                  width: 2
                                ),
                                boxShadow: _isRecording 
                                  ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10)] 
                                  : [],
                              ),
                              child: Icon(
                                _isRecording ? Icons.stop : Icons.mic, 
                                color: Colors.white, 
                                size: 20
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Macro Button
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.amber),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierColor: Colors.transparent,
                          builder: (context) => const MacroManagerDialog(),
                        );
                      },
                    ),
                    
                    // Inbox Button
                    StreamBuilder<List>(
                      stream: _inboxService.watchPendingNotes(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.inbox, color: Colors.blue),
                              onPressed: () async {
                                // Expand window to sidebar mode first
                                await WindowManagerHelper.expandToSidebar(context);
                                
                                // Show inbox dialog
                                await showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  barrierColor: Colors.transparent,
                                  builder: (context) => const InboxManagerDialog(),
                                );
                                
                                // Collapse back to pill mode after closing
                                await WindowManagerHelper.collapseToPill(context);
                              },
                            ),
                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    
                    // Menu Button
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.grey),
                      onPressed: () {
                        // Open Settings
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
