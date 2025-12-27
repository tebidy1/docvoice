import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart'; // For Amplitude
import 'dart:io';
import '../../services/websocket_service.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import '../editor/editor_screen.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/audio_recording_service.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Settings
  bool _isRecording = false;
  final AudioRecordingService _audioService = AudioRecordingService();

  final List<Widget> _screens = const [
    InboxScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleTitanTap() async {
    if (!_isRecording) {
      final success = await _audioService.hasPermission();
      if (!success) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Microphone permission required")));
         return;
      }
      
      // Start Recording
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    } else {
      // Stop Recording
      setState(() => _isRecording = false);
      final path = await _audioService.stopRecording();
      
      if (path != null) {
        // Create Real Draft Note
        final draft = NoteModel()
          ..uuid = const Uuid().v4()
          ..title = "New Recording"
          ..content = "Transcribing..." // Placeholder
          ..audioPath = path
          ..status = NoteStatus.draft
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(draftNote: draft)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _screens[_selectedIndex],
      ),
      floatingActionButton: SizedBox(
        width: 80,
        height: 80,
        child: _isRecording 
          ? StreamBuilder<Amplitude>(
              stream: _audioService.onAmplitudeChanged,
              builder: (context, snapshot) {
                 final amp = snapshot.data?.current ?? -160.0;
                 // Normalize: Quiet (-60dB) -> 1.0, Loud (0dB) -> 1.5
                 // Clamp between -60 and 0
                 double normalized = (amp.clamp(-60.0, 0.0) + 60) / 60; 
                 // Scale factor: 1.0 (base) + up to 0.4 (variability)
                 double scale = 1.0 + (normalized * 0.4);
                 
                 return Transform.scale(
                   scale: scale,
                   child: Container(
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: AppTheme.recordRed.withOpacity(0.5 * normalized),
                           blurRadius: 20 * normalized,
                           spreadRadius: 5 * normalized,
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
        notchMargin: 8.0,
        color: const Color(0xFF1E1E1E), // Dark Grey
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left Tab: Inbox
              IconButton(
                icon: const Icon(Icons.inbox),
                color: _selectedIndex == 0 ? const Color(0xFF4A90E2) : const Color(0xFF757575),
                onPressed: () => _onItemTapped(0),
                tooltip: 'Inbox',
                iconSize: 28,
              ),
              
              const SizedBox(width: 48), // Spacer for the FAB
              
              // Right Tab: Settings
              IconButton(
                icon: const Icon(Icons.settings),
                color: _selectedIndex == 1 ? const Color(0xFF4A90E2) : const Color(0xFF757575),
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

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _handleTitanTap,
      backgroundColor: _isRecording ? AppTheme.recordRed : const Color(0xFF303030),
      shape: const CircleBorder(),
      elevation: 4,
      child: Icon(
        _isRecording ? Icons.stop : Icons.mic,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}
