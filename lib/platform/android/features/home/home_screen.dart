import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/services/speech_transcription_service.dart';
import '../../../../core/utils/permission_fixer.dart';
import '../../../../presentation/widgets/animated_record_button.dart';
import '../../../../presentation/widgets/listening_mode_view.dart';
import 'package:soutnote/core/entities/note_model.dart';
import '../editor/editor_screen.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Settings
  bool _isRecording = false;
  final SpeechTranscriptionService _transcriptionService = SpeechTranscriptionService();

  // Key to control Inbox state
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  // Screens list must use the key
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      InboxScreen(key: _inboxKey),
      const SettingsScreen(),
    ];
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startRecording() async {
    try {
      await _transcriptionService.startRecording();
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

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    final transcriptFuture = _transcriptionService.stopAndTranscribe();
    _processAndNavigate(oracleTranscriptFuture: transcriptFuture);
  }

  Future<void> _processAndNavigate({Future<String>? oracleTranscriptFuture}) async {
    // Create Real Draft Note
    final draft = NoteModel()
      ..uuid = const Uuid().v4()
      ..title = "New Recording"
      ..content = "Transcribing..."
      ..originalText = ""
      ..audioPath = ""
      ..status = NoteStatus.draft
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    if (mounted) {
      // Navigate to Editor and wait for result
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditorScreen(
                draftNote: draft,
                oracleTranscriptFuture: oracleTranscriptFuture)),
      );

      // If note returned, animate it into inbox
      if (result != null && result is String && result.isNotEmpty) {
        draft.content = result;
        draft.title = "Processed Note";
        draft.status = NoteStatus.processed;

        setState(() => _selectedIndex = 0);

        Future.delayed(const Duration(milliseconds: 100), () {
          _inboxKey.currentState?.addNote(draft);
        });
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

            if (_isRecording)
              Positioned.fill(
                child: ListeningModeView(
                  getAmplitude: _transcriptionService.getAmplitude,
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
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
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
              // Left Tab: Inbox
              IconButton(
                icon: const Icon(Icons.inbox),
                color: _selectedIndex == 0
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                onPressed: () => _onItemTapped(0),
                tooltip: 'Inbox',
                iconSize: 28,
              ),

              const SizedBox(width: 48), // Spacer for the FAB

              // Right Tab: Settings
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
