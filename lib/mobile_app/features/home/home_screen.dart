import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../services/audio_recorder_service.dart';
import '../../../services/oracle_live_speech_service.dart';
import '../../../utils/permission_fixer.dart';
import '../../../widgets/animated_record_button.dart';
import '../../../widgets/listening_mode_view.dart';
import '../../models/note_model.dart';
import '../../services/audio_recording_service.dart';
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
  final AudioRecordingService _audioService = AudioRecordingService();

  // Oracle Live Speech — stream-mode recorder + service
  final AudioRecorderService _streamRecorder = AudioRecorderService();
  OracleLiveSpeechService? _oracleService;
  Future<String>? _oracleTranscriptFuture;
  bool _usingGroqFallback =
      false; // true when Oracle failed on web and fell back to Groq
  List<int> _webAudioBuffer = []; // PCM buffer for web Groq fallback

  // Native STT
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  String _nativeTranscript = '';
  double _nativeAmplitude = -160.0;

  // Key to control Inbox state
  final GlobalKey<InboxScreenState> _inboxKey = GlobalKey<InboxScreenState>();

  // Screens list must use the key
  late List<Widget> _screens;
  String _currentSttEngine = 'oracle_live';

  @override
  void initState() {
    super.initState();
    _screens = [
      InboxScreen(key: _inboxKey),
      const SettingsScreen(),
    ];
    _initSpeech();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentSttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
    });
  }

  void _initSpeech() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _startRecording() async {
    final prefs = await SharedPreferences.getInstance();
    final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
    setState(() => _currentSttEngine = sttEngine);

    if (sttEngine == 'system_native') {
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
              _nativeAmplitude =
                  (level * 2) - 100; // e.g., level 50 -> 0, level 0 -> -100
            });
          },
          listenFor:
              const Duration(minutes: 60), // Allow very long recording sessions
          pauseFor:
              const Duration(minutes: 5), // Don't stop immediately on pause
          localeId: 'ar_SA', // Arabic for medical context
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: stt.ListenMode.dictation,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Speech recognition not available")));
        setState(() => _isRecording = false);
      }
    } else if (sttEngine == 'oracle_live') {
      // ── Oracle OCI Live Speech ──────────────────────────────────────────
      _usingGroqFallback = false;

      // ⚠️ Note: On Web, the OracleLiveSpeechService will automatically use
      // the backend proxy (/api/audio/oracle-token) to fetch the session token.

      // ── Desktop/Mobile: Oracle works directly ──────────────────────────
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
        final useWhisper = prefs.getBool('oracle_use_whisper_model') ?? true;
        final creds = OciCredentials(
          tenancyId:
              'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
          userId:
              'ocid1.user.oc1..aaaaaaaa3ykq2ykgaixlhze3yip5m3fxrsbkghnzecezym7c7neqk57fupdq',
          fingerprint: 'a6:24:f0:9f:9a:f0:77:18:c5:85:2d:03:90:02:6d:c2',
          compartmentId:
              'ocid1.tenancy.oc1..aaaaaaaadt3eulxchu6ygrisqsai4z6qji5dyqiam7tgwgd6rrxe2wsocp2a',
          privateKeyPem: '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC9aeoZKxpjh42c
Gy5DFMUe/Qu9zn5e+jI2uFZ28liFl+K5vok6dUW/pG0H3htbNH03pdo2419nBZ5W
6or6vFf7lnhHY8eTsZ8ZVXP7UG3yHV5hyG7e4iWCEQgOcprjjWDY9v2Rg5NIRi8V
36FAvcIgUXLKCHUTIuq6RSKKicbj/QsZsiEBdA6ZB20agIMwjhmMNeQuBG6R2JDe
WLg6kx6vUhzxqV0ULIBuRpSaUmEZ1JAzOHMKLhzZgEj423ga2Z1hRAjySdznNuoH
fKGYnDcq1QN8/vcdslDKUq51WcAWI/8kFrMULqwEb6TQz1iggSPTSzaJVaTT7eN8
jzC8b01VAgMBAAECggEAQeJxd0ey6iPgcghSUysKVfkW+HK3KjpE9Ruxl7Y8bFuk
lY9dFGRuWnbLJg1v3o2ncI/UE3uLV75wkTMMHKMex3hTZiGi7hC+koVSznvvgmQM
zF53kjd/bHqYHs5mafhnU5C2KsNlm6IuBqG+6VIYED3Ee9ntPzbKBvi9Rwsdj3d/
wKzuyM/QurCaf2rbNgEK3z8YXqYKywo0Vnfg1owcPVK8Wn4dES6xeOB0y+1Hmx6P
zwsYxpl5BXQmk1Pf1RK13FK564FMe6MhvBkRnPariW6/BJPBEOcMfZIET+tHljdM
i7FVEgzQh6v+YqNMxTbSXrrYOjeprWClN0Q1upWTkQKBgQDqqHhZI9jqOJhAw2Hg
HlKlIWBt5qogBIPkWj6X7JbA9/TCWJMp8LR3hXYZyAtdOpwrURxZ3JMPDY0ucNH3
oAc23y6yqyQypFxlneNHT/TsA54mw55Ksdz+VcFUm+3+oVN+Ob6HN7K8ugs9QXIi
9hUrTllGdSBmA7gc9bJMrD9kEwKBgQDOpAXQbQHEcassVw8+qj094YkloKCAOLwh
y4XOv08IZZOZP3F7g0lJu+rfwLC3rtEieSTFHQzARssI1rWwtqCBj5kEiwe/lnRO
91Xohevhi3NR1q3q8VWwMl9J7QK85w8XXUYmV9BPjI3Ave1o9XFpKWJW+qZPgw5Z
9K04KtUl9wKBgQDo9ujEVrp7jkRZx5/cCT6zgjdh5Kbxsoneo1mRKulgGst8RsOT
18zS/EULw3bEz/NLbfNfo4S8ZQ/NE2ThGpcO+vQ5nX8KZ/LzT5Tcr5zQ06anhX4Z
Wgu01R5jCYt2SGPD5UAqrjlc9LdD0T2nR/gsTlSDhrTrkrWuyp6BUGB+0QKBgBnt
bKlVNBaQ6JhcqBYFyD9ecBXfjKPp+nkHD1f8mw8Dp7xfwH5t36E3yeWfSM0TSzxX
FO0CkxoBB/Ko9g0hLQx0lw+B3kwEtb0+vXG6c/lNxP9sv0+uTkEYYOpmqaRIHZWh
525iMEn66cJYUlSMD1nRjnw5YOqzF/bjg2R7w1jLAoGBAIN+zY0VUwMoPSrD84lP
PX/UnDv9wjrl95oGxuahSW3LfrrLXGdeN4KAL2IFMQLhghu7O3G72DHM3LboUWQm
OONRokqHJyqd1n1fNXCCk8wUJJSAVzv3atnDtxP1Vs03yhwL6OkBnr+jyvRT/VSf
cQBOFhw1ZkYvxx4A6HSNxyae
-----END PRIVATE KEY-----''',
        );

        _oracleService = OracleLiveSpeechService(
          credentials: creds,
          model: useWhisper
              ? OracleSTTModel.whisperGeneric
              : OracleSTTModel.oracleMedical,
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

        // Begin the Oracle session
        _oracleTranscriptFuture = _oracleService!.startSession(audioStream);
      } catch (e) {
        debugPrint('Oracle STT start error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to start Oracle STT: $e'),
                backgroundColor: Colors.red),
          );
          setState(() => _isRecording = false);
        }
      }
    } else if (sttEngine == 'gemini_oneshot') {
      // ⚡ Gemini One-Shot: record to local file (compressed)
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
                onPressed: () => openPermissionFixPage(),
              ),
              duration: const Duration(seconds: 10),
            ),
          );
          setState(() => _isRecording = false);
        }
        return;
      }
      // ⚡ Mobile Gemini One-Shot uses the compressed M4A path
      await _audioService.startRecordingCompressed();
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
    final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';

    // Stop Recording manually when the user taps
    if (sttEngine == 'system_native') {
      await _stopNativeRecording();
    } else if (sttEngine == 'oracle_live' && !_usingGroqFallback) {
      // ── Oracle stop (successful Oracle session) ───────────────────────
      setState(() => _isRecording = false);

      if (_oracleService == null || _oracleTranscriptFuture == null) {
        await _streamRecorder.stopRecording();
        return;
      }

      final oracleService = _oracleService!;
      final oracleFuture = _oracleTranscriptFuture!;
      _oracleService = null;
      _oracleTranscriptFuture = null;

      final transcriptFuture = () async {
        try {
          final transcript = await oracleService.stopSession();
          await _streamRecorder.stopRecording();
          return transcript;
        } catch (e) {
          await _streamRecorder.stopRecording();
          rethrow;
        }
      }();

      _processAndNavigate(oracleTranscriptFuture: transcriptFuture);
    } else if (sttEngine == 'gemini_oneshot') {
      // ⚡ One-Shot: stop recording and navigate directly to editor in One-Shot mode
      final audioPath = await _audioService.stopRecording();
      if (audioPath != null && audioPath.isNotEmpty) {
        _processOneShotAndNavigate(audioPath: audioPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚡ لم يتم التقاط الصوت بشكل صحيح، يرجى المحاولة مرة أخرى'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // ── Groq flow (explicit selection or Oracle web fallback) ────
      _usingGroqFallback = false; // Reset for next recording
      final audioPath = await _audioService.stopRecording();
      debugPrint('Groq stopRecording returned: $audioPath');
      if (audioPath != null && audioPath.isNotEmpty) {
        _processAndNavigate(audioPath: audioPath);
      } else {
        debugPrint('⚠️ Groq recording returned null/empty path');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('لم يتم التقاط الصوت بشكل صحيح، يرجى المحاولة مرة أخرى'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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

  Future<void> _processOneShotAndNavigate({required String audioPath}) async {
    // Create draft with audio path — editor will open in One-Shot mode
    final draft = NoteModel()
      ..uuid = const Uuid().v4()
      ..title = "⚡ One-Shot Recording"
      ..content = ""
      ..originalText = ""
      ..audioPath = audioPath
      ..status = NoteStatus.draft
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            draftNote: draft,
            oneShotAudioPath: audioPath, // ⚡ triggers One-Shot mode in editor
          ),
        ),
      );

      if (result != null && result is String && result.isNotEmpty) {
        draft.content = result;
        draft.title = "⚡ One-Shot Note";
        draft.status = NoteStatus.processed;
        setState(() => _selectedIndex = 0);
        Future.delayed(const Duration(milliseconds: 100), () {
          _inboxKey.currentState?.addNote(draft);
        });
      }
    }
  }

  Future<void> _processAndNavigate(
      {String? audioPath,
      String? nativeText,
      Future<String>? oracleTranscriptFuture}) async {
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
                  getAmplitude: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final sttEngine =
                        prefs.getString('stt_engine_pref') ?? 'oracle_live';
                    if (sttEngine == 'system_native') {
                      return _nativeAmplitude;
                    } else {
                      final amp = await _audioService.getAmplitude();
                      return amp.current;
                    }
                  },
                ),
              ),

            // AAC/M4A indicator — must be ABOVE ListeningModeView
            if (_isRecording && _currentSttEngine == 'gemini_oneshot')
              Positioned(
                bottom: 80,
                left: 12,
                child: Text(
                  kIsWeb ? "WebM / Opus" : "AAC / M4A",
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
