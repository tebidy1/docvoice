import 'package:flutter/material.dart';
import 'extension_settings_screen.dart';
import 'extension_inbox_screen.dart';
import '../../../core/entities/note_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../core/services/recording_orchestrator.dart';
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
  late final RecordingOrchestrator _orchestrator;
  final GlobalKey<ExtensionInboxScreenState> _inboxKey =
      GlobalKey<ExtensionInboxScreenState>();

  late List<Widget> _screens;
  String _currentSttEngine = 'oracle_live';

  @override
  void initState() {
    super.initState();
    _orchestrator = RecordingOrchestrator();
    _orchestrator.initialize();
    _orchestrator.addListener(_onOrchestratorChanged);

    _screens = [
      ExtensionInboxScreen(key: _inboxKey),
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
      if (kIsWeb) {
        try {
          final stream = await web.window.navigator.mediaDevices
              .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
              .toDart;
          final tracks = stream.getTracks().toDart;
          for (final track in tracks) {
            track.stop();
          }
        } catch (e) {
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
          return;
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
      await _orchestrator.stopRecording(defaultTitle: 'Extension Note');
      
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
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        width: 70,
        height: 70,
        child: AnimatedRecordButton(
          initialIsRecording: _orchestrator.isRecording,
          initialIsProcessing: _orchestrator.isProcessing,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onRecordingStateChanged: (isRecording) {
            // Orchestrator handles state
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: colorScheme.surface,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox),
                color: _selectedIndex == 0
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                onPressed: () => _onItemTapped(0),
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                onPressed: () => _onItemTapped(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
