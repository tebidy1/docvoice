import 'package:flutter/material.dart';

import '../../../../core/utils/permission_fixer.dart';
import '../../../../presentation/widgets/animated_record_button.dart';
import '../../../../presentation/widgets/listening_mode_view.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/mobile_recording_orchestrator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isRecording = false;
  bool _isProcessing = false;

  late final MobileRecordingOrchestrator _orchestrator;
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _orchestrator = MobileRecordingOrchestrator();
    _orchestrator.initialize();
    _orchestrator.addListener(_onOrchestratorChanged);

    _screens = [
      InboxScreen(key: _inboxKey, getAmplitude: _orchestrator.getAmplitude),
      const SettingsScreen(),
    ];
  }

  void _onOrchestratorChanged() {
    if (!mounted) return;
    setState(() {
      _isRecording = _orchestrator.isRecording;
      _isProcessing = _orchestrator.isProcessing;
    });
    _inboxKey.currentState?.setRecordingState(_orchestrator.isRecording);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleRecording() async {
    if (_orchestrator.isRecording) {
      await _orchestrator.stopRecording();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📥 Saved Recording"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
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
          setState(() => _isRecording = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onOrchestratorChanged);
    _orchestrator.dispose();
    super.dispose();
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

            if (_isRecording)
              Positioned.fill(
                child: ListeningModeView(
                  getAmplitude: _orchestrator.getAmplitude,
                ),
              ),

            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'جاري معالجة التسجيل...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 80,
        height: 80,
        child: AnimatedRecordButton(
          initialIsRecording: _isRecording,
          initialIsProcessing: _isProcessing,
          onStartRecording: _toggleRecording,
          onStopRecording: _toggleRecording,
          onRecordingStateChanged: (isRecording) {
            setState(() => _isRecording = isRecording);
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
                    : colorScheme.onSurface.withValues(alpha: 0.5),
                onPressed: () => _onItemTapped(0),
                tooltip: 'Inbox',
                iconSize: 28,
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.5),
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
