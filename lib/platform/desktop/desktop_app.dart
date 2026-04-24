import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/entities/app_theme.dart';
import '../../core/entities/inbox_note.dart';
import '../../presentation/screens/settings_dialog.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/audio_chunker_service.dart';
import '../../core/services/connectivity_server.dart';
import '../../core/services/inbox_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/whisper_asset_service.dart';
import '../../core/services/whisper_isolate_service.dart';
import '../../core/utils/window_manager_helper.dart';
import 'inbox_manager_dialog.dart';
import 'inbox_note_detail_view.dart'; // Import Detail View for instant open
import 'macro_manager_dialog.dart';
import '../../core/services/oracle_live_speech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopApp extends StatefulWidget {
  const DesktopApp({super.key});

  @override
  State<DesktopApp> createState() => _DesktopAppState();
}

class _DesktopAppState extends State<DesktopApp> {
  final ConnectivityServer _server = ConnectivityServer();

  final AudioRecorderService _recorder = AudioRecorderService();
  final InboxService _inboxService = InboxService();

  bool _isRecording = false;
  bool _isProcessing = false; // Visual feedback for processing
  int _lastViewedCount = 0; // For Smart Badge logic

  // Oracle streaming
  OracleLiveSpeechService? _oracleService;
  Future<String>? _oracleTranscriptFuture;

  // Gemini One-Shot
  String? _geminiOneShotPath; // Path to the WAV recorded in gemini_oneshot mode

  // Offline Whisper (Local STT)
  WhisperIsolateService? _whisperService;
  AudioChunkerService? _audioChunker;
  StreamSubscription? _whisperRecordSub;
  bool _isWhisperModelLoading = false;

  @override
  void initState() {
    super.initState();
    _startServer();
    _listInputDevices();

    // Position window after first frame and set appropriate size
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setInitialWindowSize();
      await _positionWindowToRightCenter();

      // Initialize last viewed count to current count (assume initially read)
      final notes = await _inboxService.getPendingNotes();
      setState(() {
        _lastViewedCount = notes.length;
      });
    });
  }

  Future<void> _setInitialWindowSize() async {
    try {
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
      // 300px gives enough room for 7 buttons + Windows window chrome overhead
      await windowManager.setSize(const Size(300, 56));
    } catch (e) {
      print("Error setting initial window size: $e");
    }
  }

  Future<void> _positionWindowToRightCenter() async {
    try {
      // Get primary display (actual screen)
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final screenSize = primaryDisplay.size;
      final windowSize = await windowManager.getSize();

      // Calculate position: far right, centered vertically
      final x =
          screenSize.width - windowSize.width - 10; // 10px margin from edge
      final y = (screenSize.height - windowSize.height) / 2;

      await windowManager.setPosition(Offset(x, y));

      print("Window positioned at: ($x, $y)");
      print("Screen size: ${screenSize.width}x${screenSize.height}");
      print("Window size: ${windowSize.width}x${windowSize.height}");
    } catch (e) {
      print("Error positioning window: $e");
    }
  }

  Future<void> _closeWindow() async {
    await windowManager.close();
  }

  Future<void> _listInputDevices() async {
    try {
      final devices = await _recorder.listInputDevices();
      print("Available Input Devices:");
      for (var device in devices) {
        print("- ${device.label} (ID: ${device.id})");
      }
    } catch (e) {
      print("Error listing devices: $e");
    }
  }

  Future<void> _startServer() async {
    await _server.startServer();

    _server.statusStream.listen((status) {
      if (status.startsWith("Error")) {
        setState(() {
          _isProcessing = false;
        });
      }
    });

    _server.audioStream.listen((audioChunk) {
      print("Received Audio Chunk: ${audioChunk.length} bytes");
    });

    _server.textStream.listen((text) async {
      setState(() => _isProcessing = false); // Stop processing spinner

      if (text.trim().isEmpty) {
        print("Skipping: Text is empty");
        return;
      }

      print("Received transcription: '$text'");

      try {
        // Save raw text directly without analysis
        await _inboxService.addNote(
          text,
          patientName: 'Untitled', // Will be updated later by Macro
          summary: null,
        );

        print("Added to Inbox (Raw)");

        // Show confirmation
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
      } catch (e) {
        print('Error adding valid note to inbox: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⚠️ Failed to save: $e"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  bool _isToggling = false;
  bool _isRecordingDialogOpen = false;
  Timer? _amplitudeTimer;

  Future<void> _toggleRecording() async {
    if (_isToggling) return;
    _isToggling = true;
    try {
      print("Mic Button Tapped. Current State: Recording=$_isRecording");

      final prefs = await SharedPreferences.getInstance();
      final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';

      if (_isRecording) {
        // Stop
        _amplitudeTimer?.cancel();

        print("Stopping recording...");
        try {
          if (sttEngine == 'offline_whisper') {
            // --- OFFLINE WHISPER STOP ---
            await _stopOfflineWhisperRecording();
            return;
          } else if (sttEngine == 'oracle_live') {
            // --- ORACLE STREAMING STOP ---
            if (mounted) {
              setState(() {
                _isRecording = false;
                _isProcessing = true;
              });
            }

            if (_oracleService != null && _oracleTranscriptFuture != null) {
              // 1. Push Detail Viewer IMMEDIATELY so user gets instant visual feedback.
              final instantTextController =
                  StreamController<String>.broadcast();

              final tempNote = NoteModel()
                ..id = 0
                ..uuid = 'temp_${DateTime.now().millisecondsSinceEpoch}'
                ..content = ''
                ..rawText = ''
                ..createdAt = DateTime.now()
                ..updatedAt = DateTime.now()
                ..status = NoteStatus.draft
                ..patientName = 'Untitled';

              final dialogFuture = showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => InboxNoteDetailView(
                  note: tempNote,
                  pendingTextStream: instantTextController.stream,
                ),
              );

              // 2. Safely stop recorder in the background
              try {
                await _recorder
                    .stopRecording()
                    .timeout(const Duration(milliseconds: 500));
              } catch (e) {
                print("AudioRecorder stop timeout/error ignored: $e");
              }

              // 3. Complete Oracle
              try {
                // Send the correct STOP message for Oracle! It should probably just close the stream, but we wait for stopSession.
                final text = await _oracleService!.stopSession();
                if (text.isNotEmpty) {
                  instantTextController.add(text);
                  final savedNote = await _inboxService.addNote(text,
                      patientName: 'Untitled', summary: null);
                  tempNote.id = savedNote.id;
                } else {
                  print("Warning: Oracle returned empty transcript");
                  instantTextController
                      .addError(Exception("No speech detected."));
                }
              } catch (e) {
                print("Oracle Streaming Error: $e");
                instantTextController.addError(e);
              } finally {
                _oracleService = null;
                _oracleTranscriptFuture = null;
                instantTextController.close();
              }

              await dialogFuture;
              if (mounted) setState(() => _isProcessing = false);
            } else {
              try {
                await _recorder.stopRecording();
              } catch (_) {}
              if (mounted) setState(() => _isProcessing = false);
            }
            return; // Skip standard WAV handling
          }

          // --- GEMINI ONE-SHOT STOP: no transcription, just open template picker ---
          if (sttEngine == 'gemini_oneshot') {
            final oneShotPath = await _recorder.stop();
            if (mounted) {
              setState(() {
                _isRecording = false;
                _isProcessing = false;
              });
            }
            if (oneShotPath != null && mounted) {
              _geminiOneShotPath = oneShotPath;
              // Save a lightweight draft note to inbox (needs some text to pass backend validation)
              final savedNote = await _inboxService.addNote(
                'لا يوجد نص اصلي عند اختيار هذا النموذج',
                patientName: 'Untitled',
                summary: null,
                audioPath: oneShotPath,
              );

              // Open detail view in One-Shot mode — user picks a template to trigger Gemini
              await showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => InboxNoteDetailView(
                  note: savedNote,
                  oneShotAudioPath: oneShotPath,
                ),
              );
            }
            return;
          }

          // --- STANDARD GROQ WAV FLOW ---
          final path = await _recorder.stop();
          if (mounted) {
            setState(() {
              _isRecording = false;
              _isProcessing = true; // Start processing spinner
            });
          }

          if (path != null) {
            print("Recording saved to: $path");
            final file = File(path);

            // Check if file exists
            if (!await file.exists()) {
              // ... error handling ...
              return;
            }

            final bytes = await file.readAsBytes();
            print("Read ${bytes.length} bytes from recording file");

            // ---------------------------------------------------------
            // INSTANT REVIEW FLOW
            // ---------------------------------------------------------
            // 1. Create a StreamController for this specific session
            final instantTextController = StreamController<String>.broadcast();

            // Use cascade operator since NoteModel has no named constructor
            final tempNote = NoteModel()
              ..id = 0 // Temporary ID
              ..uuid = 'temp_${DateTime.now().millisecondsSinceEpoch}'
              ..content = ''
              ..rawText = ''
              ..audioPath = path
              ..createdAt = DateTime.now()
              ..updatedAt = DateTime.now()
              ..status =
                  NoteStatus.draft // Use 'draft' as 'processing' does not exist
              ..patientName = 'Untitled';

            // 2. Open the View IMMEDIATELY and AWAIT it
            // We capture the future so we can await it before resetting _isProcessing completely.
            final dialogFuture = showDialog(
              context: context,
              barrierDismissible: false, // Prevent closing while loading
              builder: (context) => InboxNoteDetailView(
                note: tempNote,
                pendingTextStream: instantTextController.stream,
              ),
            );

            // 3. Start Processing in background
            // We attach a specific listener for THIS recording session
            StreamSubscription? serverSub;
            serverSub = _server.textStream.listen((text) async {
              // A. Pipe text to the open dialog
              instantTextController.add(text); // This updates the UI via Stream

              // B. Save to Database (Real Persistence)
              try {
                // Determine Patient Name logic here if needed, or keep "Untitled"
                // The Detail View handles the "final" version
                final savedNote = await _inboxService.addNote(
                  text,
                  patientName: 'Untitled',
                  summary: null,
                  audioPath: path,
                );
                tempNote.id = savedNote.id;
                print("✅ Persisted to Inbox with audio: $path");
              } catch (e) {
                print("❌ Save failed: $e");
              }

              // C. Cleanup
              serverSub?.cancel();
              instantTextController.close();
              setState(() => _isProcessing = false);
            });

            // 4. Trigger the actual heavy lifting
            try {
              await _server.transcribeWav(bytes);
              // when transcribeWav finishes, it emits to textStream, triggers above logic
            } catch (e) {
              instantTextController.addError(e);
              if (mounted) setState(() => _isProcessing = false);
              serverSub.cancel();
            }

            // Cleanup the temp audio file
            await file.delete();

            // Wait for dialog to close before finally resetting processing state
            await dialogFuture;
            if (mounted) {
              setState(() => _isProcessing = false);
            }
          } else {
            print("ERROR: Recorder returned null path");
            if (mounted) {
              setState(() {
                print("Error: No file");
                _isProcessing = false;
              });
            }
          }
        } catch (e) {
          print("Error stopping: $e");
          if (mounted) {
            setState(() {
              print("Error: $e");
              _isProcessing = false;
            });
          }
        }
      } else {
        // Start
        print("Starting recording...");
        try {
          if (!await _recorder.hasPermission()) {
            print("Permission denied");
            print("Permission Denied");
            return;
          }

          if (sttEngine == 'offline_whisper') {
            // --- OFFLINE WHISPER FLOW ---
            await _startOfflineWhisperRecording();
          } else if (sttEngine == 'oracle_live') {
            // ORACLE MULTIPLEXER
            final useWhisper =
                prefs.getBool('oracle_use_whisper_model') ?? true;
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
              language: 'ar',
              onError: (e) {
                print("Oracle Stream Error: $e");
              },
            );

            final audioStream = await _recorder.startRecording();
            _oracleTranscriptFuture = _oracleService!.startSession(audioStream);

            if (mounted) {
              setState(() {
                _isRecording = true;
              });
              _openRecordingDialog();
            }
          } else if (sttEngine == 'gemini_oneshot') {
            // --- GEMINI ONE-SHOT START: Record locally to M4A/FLAC, no streaming ---
            final dir = await getTemporaryDirectory();
            final ext = Platform.isWindows ? 'flac' : 'm4a';
            final path =
                '${dir.path}/oneshot_${DateTime.now().millisecondsSinceEpoch}.$ext';
            await _recorder.startRecordingCompressed(path);
            _geminiOneShotPath = path;
            print("Gemini One-Shot recording started at: $path");
            if (mounted) {
              setState(() {
                _isRecording = true;
              });
              _openRecordingDialog();
            }
          } else {
            // --- STANDARD GROQ WAV FLOW ---
            // Get temp path
            final dir = await getTemporaryDirectory();
            final path = '${dir.path}/temp_recording.wav';
            await _recorder.startRecordingToFile(path);
            print("Recording started successfully to $path");
            if (mounted) {
              setState(() {
                _isRecording = true;
              });
              _openRecordingDialog();
            }
          }
        } catch (e) {
          print("Error recording: $e");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Mic Error: $e"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isRecording = false);
        }
      }
    } finally {
      _isToggling = false;
    }
  }

  // Helper to open the visual recording overlay on the side
  void _openRecordingDialog() async {
    if (_isRecordingDialogOpen) return;
    _isRecordingDialogOpen = true;

    final prefs = await SharedPreferences.getInstance();
    final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
    String? compressionLabel;
    if (sttEngine == 'gemini_oneshot') {
      compressionLabel =
          Platform.isWindows ? 'FLAC / High Quality' : 'AAC / M4A';
    }

    await WindowManagerHelper.expandToSidebar(context);
    if (!mounted) {
      _isRecordingDialogOpen = false;
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false, // Must tap stop manually
      barrierColor: Colors.transparent,
      builder: (context) => InboxManagerDialog(
        isRecording: _isRecording,
        isProcessing: _isProcessing,
        onRecordTap: _toggleRecording,
        recorderService: _recorder,
        compressionLabel: compressionLabel,
      ),
    );
    _isRecordingDialogOpen = false;
    if (mounted) {
      await WindowManagerHelper.collapseToPill(context);
    }
  }

  // ============================================================
  // OFFLINE WHISPER (Local STT) Methods
  // ============================================================

  /// Start offline whisper recording: load model → start mic → stream to chunker.
  Future<void> _startOfflineWhisperRecording() async {
    try {
      // 1. Show model loading spinner (blocks UI)
      if (mounted) {
        setState(() {
          _isWhisperModelLoading = true;
          _isProcessing = true;
        });
      }

      // 2. Initialize whisper model in background Isolate
      _whisperService = WhisperIsolateService();
      final modelPath = await WhisperAssetService.getModelPath();
      await _whisperService!.initialize(modelPath);

      print('[OfflineWhisper] Model loaded, starting recording...');

      // 3. Model loaded — update UI and start recording
      if (mounted) {
        setState(() {
          _isWhisperModelLoading = false;
          _isProcessing = false;
        });
      }

      // 4. Create the audio chunker with VAD
      _audioChunker = AudioChunkerService(
        whisperService: _whisperService!,
        onChunkTranscribed: (text) {
          print('[OfflineWhisper] Chunk: $text');
        },
        onError: (error) {
          print('[OfflineWhisper] Error: $error');
        },
      );
      _audioChunker!.start();

      // 5. Start streaming PCM audio from microphone
      final audioStream = await _recorder.startRecording();
      _whisperRecordSub = audioStream.listen((data) {
        _audioChunker?.feedPcm16(data);
      });

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
        _openRecordingDialog();
      }
    } catch (e) {
      print('[OfflineWhisper] Start error: $e');
      // Clean up on error
      _whisperRecordSub?.cancel();
      _whisperRecordSub = null;
      _audioChunker?.dispose();
      _audioChunker = null;
      await _whisperService?.dispose();
      _whisperService = null;

      if (mounted) {
        setState(() {
          _isWhisperModelLoading = false;
          _isProcessing = false;
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offline Whisper Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Stop offline whisper recording and show results.
  Future<void> _stopOfflineWhisperRecording() async {
    try {
      print('[OfflineWhisper] === STOP FLOW STARTED ===');

      // 1. Immediately flip UI state: stop recording
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing =
              false; // Reset mic button — NO MORE SPINNER ON THE MIC
        });
      }

      // 2. Stop the microphone
      print('[OfflineWhisper] Step 1: Stopping microphone...');
      _whisperRecordSub?.cancel();
      _whisperRecordSub = null;
      try {
        await _recorder
            .stopRecording()
            .timeout(const Duration(milliseconds: 500));
      } catch (e) {
        print('[OfflineWhisper] Recorder stop error (ignored): $e');
      }
      print('[OfflineWhisper] Step 1: Microphone stopped.');

      // 3. Open the Detail View IMMEDIATELY with a loading stream
      //    The InboxNoteDetailView already has a built-in seconds counter +
      //    cycling status messages ("Processing Note...", "Consulting AI...", etc.)
      //    It will show this loading state until we push the transcript into the stream.
      print(
          '[OfflineWhisper] Step 2: Opening detail view immediately (loading state)...');

      final instantTextController = StreamController<String>.broadcast();
      final tempNote = NoteModel()
        ..id = 0
        ..uuid = 'temp_${DateTime.now().millisecondsSinceEpoch}'
        ..content = ''
        ..rawText = ''
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..status = NoteStatus.draft
        ..patientName = 'Untitled';

      final dialogFuture = showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => InboxNoteDetailView(
          note: tempNote,
          pendingTextStream: instantTextController.stream,
        ),
      );

      // 4. Flush the audio chunker in the background WHILE the loading screen shows
      print('[OfflineWhisper] Step 3: Flushing audio chunker in background...');
      try {
        if (_audioChunker != null) {
          await _audioChunker!.flush().timeout(const Duration(seconds: 180));
        }
      } catch (e) {
        print('[OfflineWhisper] Flush timeout/error: $e');
      }

      // 5. Get transcript and push it into the stream → makes the text appear
      final transcript = _audioChunker?.fullTranscript ?? '';
      print(
          '[OfflineWhisper] Step 4: Full transcript: ${transcript.length} chars');
      if (transcript.isNotEmpty) {
        print(
            '[OfflineWhisper] Preview: "${transcript.substring(0, transcript.length > 100 ? 100 : transcript.length)}"');
      }

      if (transcript.trim().isNotEmpty) {
        instantTextController.add(transcript);
        await _inboxService.addNote(transcript,
            patientName: 'Untitled', summary: null);
        print('[OfflineWhisper] ✅ Note saved to inbox');
      } else {
        print('[OfflineWhisper] ⚠️ No speech detected');
        instantTextController.addError(Exception('No speech detected.'));
      }
      instantTextController.close();

      // 6. Clean up whisper resources without blocking
      print('[OfflineWhisper] Step 5: Cleaning up...');
      _audioChunker?.dispose();
      _audioChunker = null;
      final serviceToDispose = _whisperService;
      _whisperService = null;
      serviceToDispose?.dispose().catchError((e) => print('Dispose error: $e'));

      await dialogFuture;
      print('[OfflineWhisper] === STOP FLOW COMPLETED ===');
    } catch (e) {
      print('[OfflineWhisper] Stop error: $e');
      _audioChunker?.dispose();
      _audioChunker = null;
      final serviceToDispose = _whisperService;
      _whisperService = null;
      serviceToDispose?.dispose().catchError((e) => print('Dispose error: $e'));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _server.stopServer();
    _whisperRecordSub?.cancel();
    _audioChunker?.dispose();
    _whisperService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
        valueListenable: ThemeService(),
        builder: (context, theme, child) {
          return GestureDetector(
            onPanStart: (details) {
              windowManager.startDragging();
            },
            child: MouseRegion(
              onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
              onExit: (_) => WindowManagerHelper.setOpacity(0.7),
              child: Scaffold(
                backgroundColor:
                    Colors.transparent, // Transparent for frameless mode
                body: Stack(
                  children: [
                    // Top bar removed for capsule mode
                    // Main floating bar
                    Center(
                      child: Padding(
                        padding: EdgeInsets.zero, // No padding needed
                        child: GestureDetector(
                          onPanStart: (details) {
                            windowManager.startDragging();
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                theme.borderRadius), // From Theme
                            child: Container(
                              width:
                                  double.infinity, // Fill the window explicitly
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4), // Spec: Dense padding
                              height: 56, // Spec: 56px
                              decoration: BoxDecoration(
                                color: theme.backgroundColor, // From Theme
                                borderRadius:
                                    BorderRadius.circular(theme.borderRadius),
                                border: Border.all(
                                    color: theme.borderColor,
                                    width: 1), // From Theme
                                boxShadow: theme.shadows, // From Theme
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  // 1. Drag Handle (Far Left — Windows 11 style dots)
                                  _DragHandleButton(
                                    dotColor: theme.dragHandleColor,
                                    hoverColor: theme.hoverColor,
                                    onDragStart: () =>
                                        windowManager.startDragging(),
                                  ),

                                  const SizedBox(width: 4),

                                  // 2. Microphone Button (Hero)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: _isProcessing
                                          ? null
                                          : _toggleRecording,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _isRecording
                                              ? theme.micRecordingBackground
                                              : theme.micIdleBackground,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: _isRecording
                                                  ? theme.micRecordingBorder
                                                  : theme.micIdleBorder,
                                              width: 1),
                                        ),
                                        child: _isProcessing
                                            ? Padding(
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: theme.micIdleIcon,
                                                ),
                                              )
                                            : Icon(
                                                _isRecording
                                                    ? Icons.stop
                                                    : Icons.mic,
                                                color: _isRecording
                                                    ? theme.micRecordingIcon
                                                    : theme.micIdleIcon,
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  // Divider
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: theme.dividerColor,
                                  ),

                                  const SizedBox(width: 4),

                                  // 3. Messages Icon (Inbox)
                                  StreamBuilder<List>(
                                    stream: _inboxService.watchPendingNotes(),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data?.length ?? 0;
                                      final hasNew = count > _lastViewedCount;

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          _buildIconButton(
                                            icon: hasNew
                                                ? Icons
                                                    .mark_chat_unread_outlined
                                                : Icons.chat_bubble_outline,
                                            onTap: () async {
                                              setState(() =>
                                                  _lastViewedCount = count);

                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              final sttEngine = prefs.getString(
                                                      'stt_engine_pref') ??
                                                  'oracle_live';
                                              String? compressionLabel;
                                              if (sttEngine ==
                                                  'gemini_oneshot') {
                                                compressionLabel =
                                                    Platform.isWindows
                                                        ? 'FLAC / High Quality'
                                                        : 'AAC / M4A';
                                              }

                                              await WindowManagerHelper
                                                  .expandToSidebar(context);
                                              if (!mounted) return;
                                              await showDialog(
                                                context: context,
                                                barrierDismissible: true,
                                                barrierColor:
                                                    Colors.transparent,
                                                builder: (context) =>
                                                    InboxManagerDialog(
                                                  isRecording: _isRecording,
                                                  isProcessing: _isProcessing,
                                                  onRecordTap: _toggleRecording,
                                                  recorderService: _recorder,
                                                  compressionLabel:
                                                      compressionLabel,
                                                ),
                                              );
                                              await WindowManagerHelper
                                                  .collapseToPill(context);

                                              final freshNotes =
                                                  await _inboxService
                                                      .getPendingNotes();
                                              if (mounted) {
                                                setState(() =>
                                                    _lastViewedCount =
                                                        freshNotes.length);
                                              }
                                            },
                                            tooltip: "Inbox",
                                            color: hasNew
                                                ? const Color(0xFF00A5FE)
                                                : theme.iconColor,
                                            theme: theme,
                                          ),
                                          if (hasNew)
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00A5FE),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(width: 4),

                                  // 4. Lightning Icon (Macros)
                                  _buildIconButton(
                                    icon: Icons.flash_on,
                                    onTap: () async {
                                      await showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierColor: Colors.transparent,
                                        builder: (context) =>
                                            const MacroManagerDialog(),
                                      );
                                    },
                                    tooltip: "Macros",
                                    color: theme.iconColor,
                                    theme: theme,
                                  ),

                                  const SizedBox(width: 4),

                                  // 5. Settings Button
                                  _buildIconButton(
                                    icon: Icons.settings,
                                    onTap: () async {
                                      await showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        barrierColor: Colors.transparent,
                                        builder: (context) =>
                                            const SettingsDialog(),
                                      );
                                    },
                                    tooltip: "Settings",
                                    color: theme.iconColor,
                                    theme: theme,
                                  ),

                                  const SizedBox(width: 4),

                                  // 6. Close Button (Far Right — RTL order)
                                  _buildIconButton(
                                    icon: Icons.close,
                                    onTap: _closeWindow,
                                    tooltip: "Close",
                                    color: theme.iconColor,
                                    theme: theme,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ), // MouseRegion
          ); // Method
        }); // ValueListenableBuilder
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String
        tooltip, // kept for backward compatibility if signature used elsewhere
    required Color color,
    required AppTheme theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: theme.hoverColor,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Windows 11-style drag handle with 2×3 dot grid ───────────────────────
class _DragHandleButton extends StatefulWidget {
  final Color dotColor;
  final Color hoverColor;
  final VoidCallback onDragStart;

  const _DragHandleButton({
    required this.dotColor,
    required this.hoverColor,
    required this.onDragStart,
  });

  @override
  State<_DragHandleButton> createState() => _DragHandleButtonState();
}

class _DragHandleButtonState extends State<_DragHandleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // grab = open hand cursor — exactly what user expects for dragging
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onPanStart: (_) => widget.onDragStart(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: 36,
          height: 32,
          decoration: BoxDecoration(
            // Always show a faint pill to hint draggability;
            // on hover it becomes clearly visible
            color: _hovered
                ? widget.hoverColor.withValues(alpha: 0.9)
                : widget.hoverColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? widget.dotColor.withValues(alpha: 0.35)
                  : widget.dotColor.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(12, 18),
            painter: _DotGridPainter(
              color: _hovered
                  ? widget.dotColor
                  : widget.dotColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a 2-column × 3-row grid of filled circles with fixed dot positions.
class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const r = 1.8; // dot radius
    // Fixed 2×3 grid: (left col x=3, right col x=9), rows y=2,9,16 (out of 18)
    const List<Offset> dots = [
      Offset(2.5, 2),
      Offset(9.5, 2),
      Offset(2.5, 9),
      Offset(9.5, 9),
      Offset(2.5, 16),
      Offset(9.5, 16),
    ];
    for (final d in dots) {
      canvas.drawCircle(d, r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
