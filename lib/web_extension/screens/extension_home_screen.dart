import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart';
import '../../mobile_app/features/inbox/inbox_screen.dart';
import '../../mobile_app/services/audio_recording_service.dart';
import 'package:record/record.dart'; // For Amplitude
import 'package:flutter_animate/flutter_animate.dart';
import 'profile_screen.dart';
import '../../mobile_app/features/editor/editor_screen.dart';
import '../../mobile_app/models/note_model.dart';
import 'package:uuid/uuid.dart';

class ExtensionHomeScreen extends StatefulWidget {
  const ExtensionHomeScreen({super.key});

  @override
  State<ExtensionHomeScreen> createState() => _ExtensionHomeScreenState();
}

class _ExtensionHomeScreenState extends State<ExtensionHomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Profile
  bool _isRecording = false;
  final AudioRecordingService _audioService = AudioRecordingService();
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      InboxScreen(key: _inboxKey),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  // Minimal FAB logic for extension (simplified from Unified Home)
  Future<void> _handleTitanTap() async {
    if (!_isRecording) {
      if (!await _audioService.hasPermission()) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Microphone permission required")),
           );
        }
        return;
      }
      
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    } else {
      setState(() => _isRecording = false);
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
            MaterialPageRoute(builder: (_) => EditorScreen(draftNote: draft)),
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
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: SizedBox(
        width: 70, // Slightly smaller for extension
        height: 70,
        child: _isRecording 
          ? StreamBuilder<Amplitude>(
              stream: _audioService.onAmplitudeChanged,
              builder: (context, snapshot) {
                 final amp = snapshot.data?.current ?? -160.0;
                 double normalized = (amp.clamp(-60.0, 0.0) + 60) / 60; 
                 double scale = 1.0 + (normalized * 0.3);
                 
                 return Transform.scale(
                   scale: scale,
                   child: Container(
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: AppTheme.recordRed.withOpacity(0.5 * normalized),
                           blurRadius: 15 * normalized,
                         )
                       ]
                     ),
                     child: _buildFab(),
                   ),
                 );
              }
            )
          : _buildFab(),
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
                icon: const Icon(Icons.person),
                color: _selectedIndex == 1 ? const Color(0xFF4A90E2) : const Color(0xFF757575),
                onPressed: () => _onItemTapped(1),
                tooltip: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _handleTitanTap,
      backgroundColor: _isRecording ? AppTheme.recordRed : const Color(0xFF303030),
      shape: const CircleBorder(),
      child: Icon(
        _isRecording ? Icons.stop : Icons.mic,
        color: Colors.white,
      ),
    );
  }
}
