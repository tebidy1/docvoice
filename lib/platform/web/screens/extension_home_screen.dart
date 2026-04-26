import 'package:flutter/material.dart';
import '../../android/services/audio_recording_service.dart';
import 'extension_settings_screen.dart';
import 'extension_inbox_screen.dart'; // New Extension Inbox
import 'extension_editor_screen.dart';
import '../../../core/entities/note_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../presentation/widgets/animated_record_button.dart';
import '../../../presentation/widgets/listening_mode_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExtensionHomeScreen extends StatefulWidget {
  const ExtensionHomeScreen({super.key});

  @override
  State<ExtensionHomeScreen> createState() => _ExtensionHomeScreenState();
}

class _ExtensionHomeScreenState extends State<ExtensionHomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Profile
  late final WebRecordingOrchestrator _orchestrator;
  final GlobalKey<ExtensionInboxScreenState> _inboxKey =
      GlobalKey<ExtensionInboxScreenState>();

  late List<Widget> _screens;
  String _currentSttEngine = 'oracle_live';

  @override
  void initState() {
    super.initState();
    _orchestrator = WebRecordingOrchestrator();
    _orchestrator.initialize();
    _orchestrator.addListener(_onOrchestratorChanged);

    _screens = [
      ExtensionInboxScreen(key: _inboxKey), // Use Extension Version
      const ExtensionSettingsScreen(),
    ];
    _loadPreferences();
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onOrchestratorChanged);
    _orchestrator.dispose();
    super.dispose();
  }

  void _onOrchestratorChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startRecording() async {
    try {
      // 1. Explicit Web Permission Check (Force Prompt)
      if (kIsWeb) {
        try {
          final stream = await web.window.navigator.mediaDevices
              .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
              .toDart;

          // Got permission! Stop these tracks immediately to release mic for the actual recorder
          final tracks = stream.getTracks().toDart;
          for (final track in tracks) {
            track.stop();
          }
        } catch (e) {
          print("Web Permission Error: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("عذراً، يجب منح إذن الوصول للميكروفون للمتابعة."),
                backgroundColor: Colors.orange.shade900,
                action: SnackBarAction(
                    label: "منح الإذن",
                    textColor: Colors.white,
                    onPressed: () {
                      web.window.open('permissions.html', '_blank');
                    }),
                duration: const Duration(seconds: 8),
              ),
            );
          }
          return; // Stop here
        }
      }

      await _orchestrator.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _orchestrator.stopRecording();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📥 تم حفظ الملاحظة في الوارد"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.cardTheme.color ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
            if (_orchestrator.isRecording)
              Positioned.fill(
                child: ListeningModeView(
                  getAmplitude: () async {
                    final amp = await _orchestrator.transcriptionService.getAmplitude();
                    return amp;
                  },
                ),
              ),

            // AAC/M4A/WebM indicator — must be ABOVE ListeningModeView
            if (_orchestrator.isRecording && _currentSttEngine == 'gemini_oneshot')
              Positioned(
                bottom: 60,
                left: 12,
                child: Text(
                  "WebM / Opus",
                  style: TextStyle(
                    color: Colors.blueGrey.withOpacity(0.6),
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 70, // Slightly smaller for extension
        height: 70,
        child: AnimatedRecordButton(
          initialIsRecording: _orchestrator.isRecording,
          initialIsProcessing: _orchestrator.isProcessing,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onRecordingStateChanged: (isRecording) {
            // Orchestrator handles state, but we might need to trigger rebuild
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: surfaceColor,
        child: SizedBox(
          height: 50.0, // Comapct
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox),
                color: _selectedIndex == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                onPressed: () => _onItemTapped(0),
                tooltip: 'Inbox',
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                onPressed: () => _onItemTapped(1),
                tooltip: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
