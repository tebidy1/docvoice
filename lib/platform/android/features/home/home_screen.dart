import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/services/recording_orchestrator.dart';
import '../../../../core/utils/permission_fixer.dart';
import '../../../../presentation/widgets/animated_record_button.dart';
import '../../../../presentation/widgets/listening_mode_view.dart';
import 'package:soutnote/core/entities/note_model.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Settings
  late final RecordingOrchestrator _orchestrator;

  // Key to control Inbox state
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  // Screens list must use the key
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _orchestrator = RecordingOrchestrator();
    _orchestrator.initialize();
    _orchestrator.addListener(_onOrchestratorChanged);

    _screens = [
      InboxScreen(key: _inboxKey),
      const SettingsScreen(),
    ];
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startRecording() async {
    try {
      await _orchestrator.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start recording: $e"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "FIX",
              textColor: Colors.white,
              onPressed: openPermissionFixPage,
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _orchestrator.stopRecording(defaultTitle: 'Android Note');
      
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
                  getAmplitude: _orchestrator.transcriptionService.getAmplitude,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 80,
        height: 80,
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
        notchMargin: 8.0,
        color: colorScheme.surface,
        elevation: 8,
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
                tooltip: 'Inbox',
                iconSize: 28,
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                onPressed: () => _onItemTapped(1),
                tooltip: 'Settings',
                iconSize: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
