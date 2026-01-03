import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import '../services/connectivity_server.dart';

import '../services/audio_recorder_service.dart';
import '../services/inbox_service.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'qr_pairing_dialog.dart';
import 'macro_manager_dialog.dart';
import 'inbox_manager_dialog.dart';
import '../screens/settings_dialog.dart'; // Import Settings Dialog
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../utils/window_manager_helper.dart';
import '../widgets/user_profile_header.dart';
import '../screens/admin_dashboard_screen.dart';
import '../services/theme_service.dart';
import '../models/app_theme.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  final ConnectivityServer _server = ConnectivityServer();

  final AudioRecorderService _recorder = AudioRecorderService();
  final InboxService _inboxService = InboxService();
  final AuthService _authService = AuthService();
  late final GeminiService _geminiService;
  
  String _status = "Initializing...";
  String _ipAddress = "Loading...";
  bool _isRecording = false;
  bool _isMinimizeHovered = false;
  bool _isMaximizeHovered = false;
  bool _isCloseHovered = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
    _startServer();
    _listInputDevices();
    _checkAdminStatus();
    
    // Position window after first frame and set appropriate size
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setInitialWindowSize();
      await _positionWindowToRightCenter();
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null && (user['role'] == 'admin' || user['role'] == 'Admin')) {
        setState(() {
          _isAdmin = true;
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _setInitialWindowSize() async {
    try {
      // Enforce Capsule Mode Properties
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      // Set window size to match the capsule content (tight fit)
      await windowManager.setSize(const Size(280, 56));
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
    
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, theme, child) {
        return GestureDetector(
          onPanStart: (details) {
            windowManager.startDragging();
          },
          child: MouseRegion(
            onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
            onExit: (_) => WindowManagerHelper.setOpacity(0.7),
            child: Scaffold(
            backgroundColor: Colors.transparent, // Transparent for frameless mode
            body: Stack(
              children: [
                // Top bar removed for capsule mode
                // Main floating bar
                Center(
                  child: Padding(
                    padding: EdgeInsets.zero, // No padding needed
                    child: GestureDetector(
                      onPanStart: (details) {
                        windowManager.startDragging();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(theme.borderRadius), // From Theme
                        child: Container(
                          width: double.infinity, // Fill the window explicitly
                          padding: const EdgeInsets.symmetric(horizontal: 4), // Spec: Dense padding
                          height: 56, // Spec: 56px
                        decoration: BoxDecoration(
                          color: theme.backgroundColor, // From Theme
                          borderRadius: BorderRadius.circular(theme.borderRadius),
                          border: Border.all(color: theme.borderColor, width: 1), // From Theme
                          boxShadow: theme.shadows, // From Theme
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                         // 1. Close Button (Far Left / End)
                         _buildIconButton(
                           icon: Icons.close,
                           onTap: _closeWindow,
                           tooltip: "Close",
                           color: theme.iconColor,
                           theme: theme,
                         ),
                         
                         const SizedBox(width: 4), // Spec: 4px gap

                         // 0. Admin/Settings Button (Before Last)
                         _buildIconButton(
                           icon: Icons.settings,
                           onTap: () async {
                             await showDialog(
                               context: context,
                               barrierDismissible: true,
                               barrierColor: Colors.transparent, // Or semi-transparent if centered
                               builder: (context) => const SettingsDialog(),
                             );
                           },
                           tooltip: "Settings",
                           color: theme.iconColor,
                           theme: theme,
                         ),
                         
                         const SizedBox(width: 4), // Spec: 4px gap
                        
                         // 2. Lightning Icon (Macros)
                         _buildIconButton(
                           icon: Icons.flash_on,
                           onTap: () async {
                              await showDialog(
                                context: context,
                                barrierDismissible: true,
                                barrierColor: Colors.transparent,
                                builder: (context) => const MacroManagerDialog(),
                              );
                           },
                           tooltip: "Macros",
                           color: theme.iconColor,
                           theme: theme,
                         ),

                         const SizedBox(width: 4), // Spec: 4px gap
                         
                         // 3. Messages Icon (Inbox)
                         StreamBuilder<List>(
                            stream: _inboxService.watchPendingNotes(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _buildIconButton(
                                     icon: Icons.chat_bubble_outline, 
                                     onTap: () async {
                                        await WindowManagerHelper.expandToSidebar(context);
                                        await showDialog(
                                          context: context,
                                          barrierDismissible: true,
                                          barrierColor: Colors.transparent,
                                          builder: (context) => const InboxManagerDialog(),
                                        );
                                        await WindowManagerHelper.collapseToPill(context);
                                     },
                                     tooltip: "Inbox",
                                     color: theme.iconColor,
                                     theme: theme,
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                         ),

                         const SizedBox(width: 4), // Spec: 4px gap

                         // Divider
                         Container(
                           width: 1,
                           height: 20, // Spec: 20px
                           color: theme.dividerColor, // From Theme
                         ),
                         
                         const SizedBox(width: 4), // Spec: 4px gap

                         // 4. Microphone Button (Hero - Rounded Square)
                         MouseRegion(
                           cursor: SystemMouseCursors.click,
                           child: GestureDetector(
                             onTap: _toggleRecording,
                             child: AnimatedContainer(
                               duration: const Duration(milliseconds: 200),
                               width: 40,
                               height: 40,
                               decoration: BoxDecoration(
                                 color: _isRecording ? theme.micRecordingBackground : theme.micIdleBackground, // From Theme
                                 borderRadius: BorderRadius.circular(4), // Spec: 4px radius
                                 border: Border.all(
                                   color: _isRecording ? theme.micRecordingBorder : theme.micIdleBorder, // From Theme
                                   width: 1
                                 ),
                               ),
                               child: Icon(
                                 _isRecording ? Icons.stop : Icons.mic,
                                 color: _isRecording ? theme.micRecordingIcon : theme.micIdleIcon, // From Theme
                                 size: 20,
                               ),
                             ),
                           ),
                         ),

                         const SizedBox(width: 4), // Spec: 4px gap



                         // 5. Drag Handle (Far Right - Grid Pattern)
                         MouseRegion(
                           cursor: SystemMouseCursors.grab,
                           child: GestureDetector(
                             onPanStart: (details) {
                               windowManager.startDragging();
                             },
                             child: Container(
                               width: 32, 
                               height: 40,
                               color: Colors.transparent,
                               alignment: Alignment.center,
                               child: Icon(
                                 Icons.grid_view, // Grid dots look
                                 color: theme.dragHandleColor, // From Theme
                                 size: 18,
                               ),
                             ),
                           ),
                         ),
                      ],
                    ),
                  ),
                  ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ), // MouseRegion
    ); // Method
  }
  ); // ValueListenableBuilder
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    required Color color,
    required AppTheme theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4), // Spec: 4px radius
          hoverColor: theme.hoverColor, // From Theme
          child: Container(
            width: 40, // Spec: 40x40
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: color, // Using passed color (which is likely theme.iconColor)
            ),
          ),
        ),
      ),
    );
  }
}
