import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart'; // For Amplitude
import 'package:universal_io/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/websocket_service.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import '../editor/editor_screen.dart';
import '../inbox/inbox_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/audio_recording_service.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/permission_fixer.dart';
import '../../../widgets/animated_record_button.dart';
import '../../../widgets/listening_mode_view.dart';
import '../../../services/oracle_live_speech_service.dart';
import '../../../services/audio_recorder_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // 0: Inbox, 1: Settings
  bool _isRecording = false;
  final AudioRecordingService _audioService = AudioRecordingService();

  // Oracle Live Speech — stream-mode recorder + service
  final AudioRecorderService _streamRecorder = AudioRecorderService();
  OracleLiveSpeechService? _oracleService;
  Future<String>? _oracleTranscriptFuture;

  // Native STT
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  String _nativeTranscript = '';
  double _nativeAmplitude = -160.0;
  
  // Key to control Inbox state
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  // Screens list must use the key
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      InboxScreen(key: _inboxKey),
      const SettingsScreen(),
    ];
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (errorNotification) {
        print('SpeechToText Error: $errorNotification');
        if (mounted) {
           setState(() => _isRecording = false);
        }
      },
      onStatus: (status) {
        print('SpeechToText Status: $status');
        if (status == 'done' || status == 'notListening') {
           if (mounted && _isRecording) {
              // The system stopped listening automatically. We should handle the stop logic.
              _stopNativeRecording();
           }
        }
      },
    );
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startRecording() async {
    final prefs = await SharedPreferences.getInstance();
    final sttEngine = prefs.getString('stt_engine_pref') ?? 'groq';

    if (sttEngine == 'native') {
       if (!_speechEnabled) {
           _speechEnabled = await _speechToText.initialize();
       }
       if (_speechEnabled) {
          setState(() {
            _nativeTranscript = '';
            _nativeAmplitude = -160.0;
          });
          await _speechToText.listen(
             onResult: (result) {
               setState(() {
                 _nativeTranscript = result.recognizedWords;
               });
             },
             onSoundLevelChange: (level) {
               // level is mapped from -50 to 50 broadly, let's normalize roughly to our expected -160 to 0 range for the animation
               setState(() {
                 _nativeAmplitude = (level * 2) - 100; // e.g., level 50 -> 0, level 0 -> -100
               });
             },
             listenFor: const Duration(minutes: 60), // Allow very long recording sessions
             pauseFor: const Duration(minutes: 5), // Don't stop immediately on pause
             localeId: 'ar_SA', // Arabic for medical context
             listenOptions: stt.SpeechListenOptions(
               partialResults: true,
               cancelOnError: true,
               listenMode: stt.ListenMode.dictation,
             ),
          );
       } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Speech recognition not available")));
          setState(() => _isRecording = false);
       }
    } else if (sttEngine == 'oracle_live') {
      // ── Oracle OCI Live Speech ────────────────────────────────────────────
      final hasPermission = await _streamRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Microphone permission required"),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: "FIX",
                textColor: Colors.white,
                onPressed: openPermissionFixPage,
              ),
            ),
          );
          setState(() => _isRecording = false);
        }
        return;
      }

      try {
        final useWhisper = prefs.getBool('oracle_use_whisper_model') ?? false;
        final creds = OciCredentials(
          tenancyId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
          userId: 'ocid1.user.oc1..aaaaaaaa3ykq2ykgaixlhze3yip5m3fxrsbkghnzecezym7c7neqk57fupdq',
          fingerprint: 'fb:38:d1:b4:7c:47:61:fd:95:e6:5a:e8:bb:2c:43:ee',
          compartmentId: 'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
          privateKeyPem: '''
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDLQFaVcyVWbo1j
q4LqN1jQ6E25nbE1Ks6nUE6zhH1h6B6kUSOYLihsKVxmKI5wVKKKYUnTTqUCYmtr
KBlan46q9vfk0ccV1dxDDFIdZezk5+vuEdLklBxia/acfKZib3CThCuPX6NPoUPG
rXDDeDqwsp4dhvu1QkZJRoGyMEoV5qrl2Boj0H+yVoSlAw1gCN8PZYCgstv7xgAg
Cwx78KIulc8uIwyl0SmEuyl9DzihqdMNjOf84yeulC5wvGE4UoQVMgiifUn3j59I
io+Wua1SYoas2cHGUxq17t7Y0Ti5iVPtL5DTASXjNbqL8woeDRFiTtcV+mmkwsBC
4kXaib69AgMBAAECggEAAvqC+lGJFR/tda3hry3XS50dPHs1ibECUnHgbAw6QSkj
anw06xSWwOUHRrOmng9OICcxANt+GrpCAZHsHdzzkd5Tf4MyfsesS2rpY3xm+8DJ
VJW8Hd+XczrKpFGa/PDN+R9z+vfSFHHpehvNvf5A+pjCLUPD5GIKVnsQc1chUs+l
9keRZfHinCf3ao6fYK7hRxC5pYIrmf2f2AuPb/K0UaC3hS+oa+XLNxe5bZUuQDPu
Wr1dMRWKAfraHxSC+psmlqWnhpJA8DLYp1K+zRyotTyZhI3NmdWSJh3PnbtOEVCs
lXtaRTT/9zXkZZ7yu7PSZrg1ob1SnN7B9M3nKFVmeQKBgQDrZMOJgd29sNHh26bO
crAkQmSNyC+bElNSBWvwnBEbvqeHiSCcADWIDd4VWnLMbqUNN0GusxJhQxGvzZXl
XD8K0LxnEDspecEaWiTPuYnQ752v28YRZosxSUB7bl89FjQpcu3GPd1hK3UJtpo1
qQrauOMyjWA/4uT7grfVLso5aQKBgQDdC0G+Dc28r6T1Rx4cxYR0W2hnHFq1X7yD
rVx0H3PEdH8+fyJPAJPkk5m/LdgE2l068NL1/39Ru3IehPM+8ZDEd2rEfvhP3IMO
3uAm7IvkJMIbFFcEuR5YcABm3p2pdsEUT+/N2qjjBrvuSsghscowHsjR1rEJebW+
SuBfD1V8NQKBgQDZR8Ouk+9of2TcxHHusrKgZaCHtzcqPvomBdci3Ax2vb/KPeuZ
1B+VnKdYsoqw5Zj43/6DEcxvdwdGbdBlTIbspsyhnbvehwKWHotIKw1pjSTTBVyJ
B0yIjAM3bCQBMROpBuswSD6myQRZmPIzgfwA9RTSvukPT5LqDjk+UNhdsQKBgD1c
j56D1HYpyEAywuA30KJAccYV7/RjpEBlksHFrWx+7ofZ4RtPTL7qXobc4hfOyoy/
J8EUcTKuN2rTe3cgthBkGiZ8HNCGpXcuVclYZykpLx03U0TDYvIn/WSRLfFKPyU1
X5uktLd5OhhXeCEqardbBGKEF9dKizJNNOYOqqt1AoGBAOa107lq0koA7A1oSlay
eJY/Rw/MR3Qgzmv6Xn7dF1K2dxySo6c/8erNWt17qsC2lRFlo3p8UhyuyywvIYpN
y8g1uEYVTGTAtgJKhOGSSMOpkdivygLgHGv1e+1/m79c6oGGUqdf2xmxSgxjHzsv
jFhu1HSrW46DXj424N8jFYGS
-----END PRIVATE KEY-----''',
        );

        _oracleService = OracleLiveSpeechService(
          credentials: creds,
          model: useWhisper ? OracleSTTModel.whisperGeneric : OracleSTTModel.oracleMedical,
          language: 'ar-SA',
          onError: (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Oracle STT error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() => _isRecording = false);
            }
          },
        );

        // Start streaming recorder (PCM 16kHz Mono)
        final audioStream = await _streamRecorder.startRecording();

        // Begin the Oracle session — returns a Future<String> that resolves on final result
        _oracleTranscriptFuture = _oracleService!.startSession(audioStream);
      } catch (e) {
        debugPrint('Oracle STT start error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start Oracle STT: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isRecording = false);
        }
      }
    } else {
      // --- GROQ FLOW ---
      final success = await _audioService.hasPermission();
      if (!success) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Microphone permission required"),
               backgroundColor: Colors.orange,
               action: SnackBarAction(
                 label: "FIX PERMISSION",
                 textColor: Colors.white,
                 onPressed: () {
                   openPermissionFixPage();
                 },
               ),
               duration: const Duration(seconds: 10),
             ),
           );
           setState(() => _isRecording = false);
         }
         return;
      }
      
      // Start Recording
      await _audioService.startRecording();
    }
  }

  Future<void> _stopRecording() async {
    final prefs = await SharedPreferences.getInstance();
    final sttEngine = prefs.getString('stt_engine_pref') ?? 'groq';

    // Stop Recording manually when the user taps
    if (sttEngine == 'native') {
       await _stopNativeRecording();
    } else if (sttEngine == 'oracle_live') {
      // ── Oracle stop: flush audio stream, await final result ───────────────
      setState(() => _isRecording = false);
      await _streamRecorder.stopRecording();

      if (_oracleService == null || _oracleTranscriptFuture == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏳ Waiting for Oracle final transcription...'),
            duration: Duration(seconds: 30),
          ),
        );
      }

      try {
        final transcript = await _oracleService!.stopSession();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (transcript.isNotEmpty) {
          _processAndNavigate(nativeText: transcript);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No speech detected by Oracle'), backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Oracle transcription failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        _oracleService = null;
        _oracleTranscriptFuture = null;
      }
    } else {
       final audioPath = await _audioService.stopRecording();
       if (audioPath != null) {
          _processAndNavigate(audioPath: audioPath);
       }
    }
  }
  Future<void> _stopNativeRecording() async {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _nativeAmplitude = -160.0;
    });

    await _speechToText.stop();
    final nativeText = _nativeTranscript;

    if (nativeText.isNotEmpty) {
      _processAndNavigate(nativeText: nativeText);
    }
  }

  Future<void> _processAndNavigate({String? audioPath, String? nativeText}) async {
      // Create Real Draft Note
      final draft = NoteModel()
        ..uuid = const Uuid().v4()
        ..title = "New Recording"
        ..content = nativeText ?? "Transcribing..." // Use Native Text if ready
        ..originalText = nativeText ?? "" 
        ..audioPath = audioPath ?? ""
        ..status = NoteStatus.draft
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      if (mounted) {
        // Navigate to Editor and wait for result
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditorScreen(draftNote: draft)),
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
                    final prefs = await SharedPreferences.getInstance();
                    final sttEngine = prefs.getString('stt_engine_pref') ?? 'groq';
                    if (sttEngine == 'native') {
                      return _nativeAmplitude;
                    } else {
                      final amp = await _audioService.getAmplitude();
                      return amp.current;
                    }
                  },
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


}
