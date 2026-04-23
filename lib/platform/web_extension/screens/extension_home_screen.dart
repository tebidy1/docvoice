import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart';
import '../../mobile_app/data/repositories/audio_recording_service.dart';
import 'extension_settings_screen.dart';
import 'extension_inbox_screen.dart'; // New Extension Inbox
import 'extension_editor_screen.dart';
import '../../mobile_app/core/entities/note_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../../presentation/widgets/animated_record_button.dart';
import '../../../presentation/widgets/listening_mode_view.dart';

class ExtensionHomeScreen extends StatefulWidget {
  const ExtensionHomeScreen({super.key});

  @override
  State<ExtensionHomeScreen> createState() => _ExtensionHomeScreenState();
}

class _ExtensionHomeScreenState extends State<ExtensionHomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Profile
  bool _isRecording = false;
  final AudioRecordingService _audioService = AudioRecordingService();
  final GlobalKey<ExtensionInboxScreenState> _inboxKey = GlobalKey<ExtensionInboxScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ExtensionInboxScreen(key: _inboxKey), // Use Extension Version
      const ExtensionSettingsScreen(),
    ];
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
           final stream = await web.window.navigator.mediaDevices.getUserMedia(
             web.MediaStreamConstraints(audio: true.toJS)
           ).toDart;
           
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
                 content: const Text("Microphone access denied."),
                 action: SnackBarAction(
                   label: "Fix Permissions", 
                   textColor: Colors.white,
                   onPressed: () {
                      web.window.open('permissions.html', '_blank');
                   }
                 ),
                 duration: const Duration(seconds: 5),
               ),
             );
           }
           if (mounted) setState(() => _isRecording = false);
           return; // Stop here
         }
      }
      
      // 2. Start Recording
      await _audioService.startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioService.stopRecording();
      
      if (path != null && mounted) {
        final draft = NoteModel()
          ..uuid = const Uuid().v4()
          ..title = "Extension Note"
          ..content = "Processing..."
          ..audioPath = path
          ..status = NoteStatus.draft
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
  
         final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExtensionEditorScreen(draftNote: draft)),
          );
  
          if (result != null && result is String) {
             draft.content = result;
             draft.status = NoteStatus.processed;
             setState(() => _selectedIndex = 0); // Go to inbox
             Future.delayed(const Duration(milliseconds: 100), () {
                _inboxKey.currentState?.addNote(draft);
             });
          }
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
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                  getAmplitude: () async {
                    final amp = await _audioService.getAmplitude();
                    return amp.current;
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 70, // Slightly smaller for extension
        height: 70,
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
        notchMargin: 6.0,
        color: const Color(0xFF1E1E1E),
        child: SizedBox(
          height: 50.0, // Comapct
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox),
                color: _selectedIndex == 0 ? const Color(0xFF4A90E2) : const Color(0xFF757575),
                onPressed: () => _onItemTapped(0),
                tooltip: 'Inbox',
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1 ? const Color(0xFF4A90E2) : const Color(0xFF757575),
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


