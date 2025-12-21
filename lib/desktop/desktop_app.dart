import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import '../services/connectivity_server.dart';

import '../services/audio_recorder_service.dart';
import '../services/inbox_service.dart';
import '../services/gemini_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'qr_pairing_dialog.dart';
import 'macro_manager_dialog.dart';
import 'inbox_manager_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../utils/window_manager_helper.dart';
import '../widgets/user_profile_header.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  final ConnectivityServer _server = ConnectivityServer();

  final AudioRecorderService _recorder = AudioRecorderService();
  final InboxService _inboxService = InboxService();
  late final GeminiService _geminiService;
  
  String _status = "Initializing...";
  String _ipAddress = "Loading...";
  bool _isRecording = false;
  bool _isMinimizeHovered = false;
  bool _isMaximizeHovered = false;
  bool _isCloseHovered = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
    _startServer();
    _listInputDevices();
    
    // Position window after first frame and set appropriate size
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setInitialWindowSize();
      await _positionWindowToRightCenter();
    });
  }

  Future<void> _setInitialWindowSize() async {
    try {
      // Set window size to match the main container (500x100 + padding 40 + header 32 = 500x172)
      await windowManager.setSize(const Size(500, 172));
    } catch (e) {
      print("Error setting initial window size: $e");
    }
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



  Future<void> _minimizeWindow() async {
    await windowManager.minimize();
  }

  Future<void> _maximizeWindow() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.restore();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _closeWindow() async {
    await windowManager.close();
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
      
      try {
        // Analyze with Gemini
        final analysis = await _geminiService.analyzeNote(text);
        
        // Save to Inbox
        try {
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
        } catch (e) {
          print('Error adding note to inbox: $e');
          // Show error notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ Failed to save note: ${e.toString().contains('timeout') ? 'Connection timeout' : 'Network error'}"),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        print('Error analyzing note: $e');
        // Try to save without analysis if analysis fails
        try {
          await _inboxService.addNote(text);
          print("Added to Smart Inbox (without analysis)");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("📥 Saved (analysis unavailable)"),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.blue,
              ),
            );
          }
        } catch (saveError) {
          print('Error saving note without analysis: $saveError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ Failed to save: ${saveError.toString().contains('timeout') ? 'Connection timeout' : 'Network error'}"),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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

  @override
  Widget build(BuildContext context) {
    final isConnected = _status.contains("Client Connected");
    
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900 - matches theme
        body: Stack(
          children: [
            // Window Control Bar (Top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onPanStart: (details) {
                  windowManager.startDragging();
                },
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.8),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - App title or drag area
                      Expanded(
                        child: GestureDetector(
                          onPanStart: (details) {
                            windowManager.startDragging();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                            children: [
                              const Icon(
                                Icons.drag_indicator,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ScribeFlow',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ),
                      // Center - User Profile (only show when window is expanded)
                      if (MediaQuery.of(context).size.width >= 500)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {}, // Prevent window dragging when clicking on profile
                            child: const UserProfileHeader(),
                          ),
                        ),
                      // Right side - Window controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // Minimize button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isMinimizeHovered = true),
                          onExit: (_) => setState(() => _isMinimizeHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _minimizeWindow,
                            child: Container(
                              width: 46,
                              height: 32,
                              color: _isMinimizeHovered
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.transparent,
                              child: Icon(
                                Icons.remove,
                                color: Colors.grey[400],
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        // Maximize/Restore button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isMaximizeHovered = true),
                          onExit: (_) => setState(() => _isMaximizeHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _maximizeWindow,
                            child: Container(
                              width: 46,
                              height: 32,
                              color: _isMaximizeHovered
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.transparent,
                              child: Icon(
                                Icons.crop_square,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        // Close button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _isCloseHovered = true),
                          onExit: (_) => setState(() => _isCloseHovered = false),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeWindow,
                            child: Container(
                              width: 46,
                              height: 32,
                              color: _isCloseHovered
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.transparent,
                              child: Icon(
                                Icons.close,
                                color: _isCloseHovered
                                    ? Colors.red[300]
                                    : Colors.grey[400],
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    ],
                  ),
              ),
            ),
          ),
            // Main floating bar
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40), // Add space from top bar
                child: GestureDetector(
                  onPanStart: (details) {
                    windowManager.startDragging();
                  },
                  child: Container(
                    width: 500,
                    height: 100,
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
                    // Drag Handle (removed - now in top bar)
                    
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
            ),
          ],
      ),
      ),
    );
  }
}
