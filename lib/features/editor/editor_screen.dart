import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutnote/core/services/ai_processing_service.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
// App Widgets & Services
import 'package:soutnote/shared/widgets/pattern_highlight_controller.dart';
import 'package:soutnote/shared/widgets/processing_overlay.dart';
import 'package:soutnote/shared/theme.dart';
import 'package:soutnote/core/providers/common_providers.dart';
import 'package:soutnote/core/models/macro.dart';
import 'package:soutnote/core/models/note_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soutnote/core/services/groq_service.dart'; // Direct Groq for faster Web transcription
import 'package:soutnote/core/ai/ai_regex_patterns.dart';
import 'package:soutnote/core/ai/text_processing_service.dart';
import 'package:soutnote/web_extension/services/extension_injection_service.dart';
import 'package:soutnote/core/services/model_download_service.dart';
import 'package:soutnote/core/services/whisper_local_stub.dart'
    if (dart.library.io) 'package:soutnote/core/services/whisper_local_service.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final NoteModel? draftNote;
  final Future<String>? oracleTranscriptFuture;
  final int noteNumber;

  const EditorScreen(
      {super.key,
      this.draftNote,
      this.oracleTranscriptFuture,
      this.noteNumber = 0});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  // Controllers
  late TextEditingController _sourceController; // Top: Raw Transcript
  late TextEditingController _finalController; // Bottom: Final Note

  bool _isKeyboardVisible = false;
  List<Macro> _macros = [];
  Macro? _selectedMacro; // Track selected template
  StreamSubscription? _wsSubscription;
  late bool _isLoading; // Set dynamically in initState
  bool _isProcessing = false; // For AI generation
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSourceExpanded = false; // Toggle source view
  bool _useHighAccuracy = false; // Toggle for AI Mode (Standard vs Suggestions)
  bool _isTemplateCardExpanded = true; // Template card: expanded by default
  bool _isGeneratedCardExpanded =
      false; // Generated note card: collapsed by default

  // Native STT
  stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  String _sttEnginePref = 'groq'; // 'groq' or 'native'

  // Auto-Save State
  int? _currentNoteId; // Track the cloud note ID for updates
  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer; // For manual edit auto-save

  @override
  void initState() {
    super.initState();

    final path = widget.draftNote?.audioPath;
    _isLoading = widget.oracleTranscriptFuture != null ||
        (path != null && path.isNotEmpty);

    // Initialize ID if opening existing draft
    if (widget.draftNote != null) {
      // Prefer server ID if valid (> 0), otherwise fallback to UUID parsing
      _currentNoteId = (widget.draftNote!.id > 0)
          ? widget.draftNote!.id
          : int.tryParse(widget.draftNote!.uuid);
    }

    // Load Content
    // Source: Original raw text
    _sourceController = TextEditingController(
        text:
            widget.draftNote?.originalText ?? widget.draftNote?.content ?? "");

    // Final: Formatted text if exists
    // Use PatternHighlightController with centralized AIRegexPatterns
    _finalController = PatternHighlightController(
      text: widget.draftNote?.formattedText ?? "",
      patternStyles: {
        // Orange for [ Select ] — highest priority
        AIRegexPatterns.selectPlaceholderPattern: const TextStyle(
            color: Colors.orange,
            backgroundColor: Color(0x33FF9800),
            fontWeight: FontWeight.bold),
        // Orange for any remaining [bracket] placeholder
        AIRegexPatterns.anyBracketPattern: const TextStyle(
            color: Colors.orange, backgroundColor: Color(0x33FF9800)),
        // Bold underlined WHITE for SECTION HEADERS (e.g. SUBJECTIVE:)
        AIRegexPatterns.headerPattern: const TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          decorationThickness: 2.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      },
    );

    if (widget.draftNote != null &&
        widget.draftNote!.formattedText.isNotEmpty) {
      _isTemplateCardExpanded = false;
      _isGeneratedCardExpanded = true;
    } else {
      _isTemplateCardExpanded = true;
      _isGeneratedCardExpanded = false;
    }

    // Auto-save on manual edits
    _finalController.addListener(_onManualEdit);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStandalone();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sourceController.dispose();
    _finalController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _onManualEdit() {
    // Only auto-save if we have a draft ID
    if (_currentNoteId == null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _saveDraftUpdate();
    });
  }

  /// Retry helper with exponential backoff
  Future<T> _retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          debugPrint('❌ Retry failed after $maxRetries attempts');
          rethrow;
        }

        final delay = initialDelay * pow(2, attempt - 1).toInt();
        debugPrint(
            '⏳ Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _saveDraftUpdate() async {
    if (_currentNoteId == null) return;

    try {
      final repository = ref.read(inboxNoteRepositoryProvider);
      final note = await repository.getById(_currentNoteId!.toString());
      if (note != null) {
        note.originalText = _sourceController.text;
        note.formattedText = _finalController.text;
        await repository.update(note);
        debugPrint("📝 Auto-saved manual edits to cloud");
      }
    } catch (e) {
      debugPrint("❌ Auto-save failed: $e");
    }
  }

  Future<void> _initStandalone() async {
    final macros = await ref.read(macroRepositoryProvider).getAll();

    // 🚀 FETCH LATEST DATA: But only if we don't have fresh content
    // This prevents cache from overwriting AI-generated results
    if (_currentNoteId != null && _finalController.text.isEmpty) {
      try {
        final repository = ref.read(inboxNoteRepositoryProvider);
        final freshNote = await repository.getById(_currentNoteId!.toString());
        if (freshNote != null && mounted) {
          // Load saved AI result from cloud
          if (freshNote.formattedText.isNotEmpty) {
            debugPrint("🔄 Loading saved AI result from cloud...");
            debugPrint(
                "   Formatted Text Length: ${freshNote.formattedText.length}");
            _finalController.text = freshNote.formattedText;
            _isTemplateCardExpanded = false;
            _isGeneratedCardExpanded = true;
          }
          if (freshNote.originalText.isNotEmpty) {
            _sourceController.text = freshNote.originalText;
          }
        }
      } catch (e) {
        debugPrint("⚠️ Failed to load note: $e");
      }
    } else if (_currentNoteId != null && _finalController.text.isNotEmpty) {
      debugPrint("⏭️ Skipping cloud refresh - editor has fresh content");
    }

    if (mounted) {
      // Sort: Favorites first, then alphabetical
      macros.sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        return a.trigger.compareTo(b.trigger);
      });

      // Restore selected macro from draft and move to front
      Macro? restoredMacro;
      if (widget.draftNote != null &&
          widget.draftNote!.appliedMacroId != null) {
        try {
          restoredMacro = macros
              .firstWhere((m) => m.id == widget.draftNote!.appliedMacroId);
          macros.remove(restoredMacro);
          macros.insert(0, restoredMacro);
        } catch (e) {
          debugPrint("Could not restore selected macro: $e");
        }
      }

      setState(() {
        _macros = macros;
        if (restoredMacro != null) _selectedMacro = restoredMacro;
      });
    }

    final path = widget.draftNote?.audioPath;
    final oracleFuture = widget.oracleTranscriptFuture;

    // ── Oracle Live Speech: transcript arrives via Future ───────────────
    if (oracleFuture != null) {
      try {
        final transcript = await oracleFuture;
        if (mounted) {
          setState(() => _isLoading = false);
          final cleanText = transcript.trim();
          if (cleanText.isNotEmpty) {
            _sourceController.text = cleanText;
            // AUTO-SAVE: Create draft immediately after transcription
            try {
              final repository = ref.read(inboxNoteRepositoryProvider);
              final note = NoteModel()
                ..originalText = cleanText
                ..title = "Draft Note"
                ..status = NoteStatus.draft;
              final savedNote = await repository.create(note);

              setState(() => _currentNoteId = savedNote.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("📝 Draft saved to cloud"),
                  backgroundColor: Colors.blueGrey,
                  duration: Duration(seconds: 2),
                ));
              }
            } catch (e) {
              debugPrint("Auto-save draft failed: $e");
            }
          } else {
            _sourceController.text = "";
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No speech detected by Oracle'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Oracle transcript error: $e");
        if (mounted) {
          setState(() => _isLoading = false);
          _sourceController.text = "❌ Oracle transcription error: $e";
        }
      }
      return;
    }

    // ── Groq / file-based STT flow ─────────────────────────────────────
    if (path != null && path.isNotEmpty) {
      Uint8List? bytes;
      // --- Web Logic ---
      if (kIsWeb) {
        debugPrint("Web Audio Path: $path");
        try {
          // Fetch Blob data via HTTP
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            debugPrint("Failed to fetch blob: ${response.statusCode}");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Failed to load web audio for transcription"),
                    backgroundColor: Colors.red),
              );
              setState(() => _isLoading = false);
              return;
            }
          }
        } catch (e) {
          debugPrint("Error fetching blob: $e");
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // --- Mobile Logic ---
        if (await File(path).exists()) {
          bytes = await File(path).readAsBytes();
        }
      }

      // --- Processing ---
      if (path != null && path.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';

          String transcript = "";

          if (sttEngine == 'whisper_local' && !kIsWeb) {
            // --- Whisper Local On-Device Transcription ---
            debugPrint("🎙️ Using Whisper Local STT");

            // Check if model is downloaded
            final downloadService = ModelDownloadService();
            if (!await downloadService.isModelReady()) {
              // Show download dialog
              if (!mounted) return;
              final shouldDownload = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => _ModelDownloadDialog(),
              );
              if (shouldDownload != true) {
                setState(() {
                  _isProcessing = false;
                });
                return;
              }
            }

            final whisperService = WhisperLocalService();
            transcript = await whisperService.transcribeAudioUrl(path);

            if (transcript.startsWith('Error')) {
              throw Exception(transcript);
            }
          } else {
            // --- Cloud Transcription (Groq) ---
            if (bytes != null) {
              // ⚡ STRATEGY: On Web, call Groq DIRECTLY for speed.
              // Backend proxy adds a full network round-trip + possible transcoding.
              // Direct call: Browser→Groq (fast)
              // Backend proxy: Browser→Backend→Groq→Backend→Browser (slow)
              bool transcribed = false;

              if (kIsWeb) {
                final prefs2 = await SharedPreferences.getInstance();
                final localGroqKey = prefs2.getString('groq_api_key') ?? '';

                if (localGroqKey.isNotEmpty) {
                  debugPrint("⚡ Web: Using Direct Groq API (fast path)");
                  final groqService = GroqService(apiKey: localGroqKey);
                  final directResult = await groqService.transcribe(bytes!,
                      filename: 'recording.webm');

                  if (!directResult.startsWith('Error')) {
                    transcript = directResult;
                    transcribed = true;
                  } else {
                    debugPrint(
                        "⚠️ Direct Groq failed: $directResult. Falling back to backend proxy.");
                  }
                }
              }

              // Fallback: Backend Proxy (for Mobile, or if Direct Groq failed)
              if (!transcribed) {
                debugPrint("☁️ Using Backend Proxy for STT");
                final apiService = ref.read(apiServiceProvider);
                final result = await apiService.multipartPost(
                  '/audio/transcribe',
                  fileBytes: bytes!,
                  filename: kIsWeb ? 'recording.webm' : 'recording.wav',
                );

                if (result['status'] == true) {
                  transcript = result['payload']['text'] ?? "";
                } else {
                  throw Exception(result['message'] ?? 'Transcription failed');
                }
              }
            } else {
              throw Exception("No audio bytes available for Cloud STT.");
            }
          }

          if (mounted) {
            setState(() => _isLoading = false);

            final cleanText = transcript.trim();
            if (cleanText.isNotEmpty) {
              _sourceController.text = cleanText;

              // AUTO-SAVE: Create draft immediately after transcription
              try {
                final repository = ref.read(inboxNoteRepositoryProvider);
                final note = NoteModel()
                  ..originalText = cleanText
                  ..title = "Draft Note"
                  ..status = NoteStatus.draft;
                final savedNote = await repository.create(note);

                setState(() => _currentNoteId = savedNote.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("📝 Draft saved to cloud"),
                    backgroundColor: Colors.blueGrey,
                    duration: Duration(seconds: 2),
                  ));
                }
              } catch (e) {
                debugPrint("Auto-save draft failed: $e");
              }
            }
          }
        } catch (e) {
          debugPrint("Transcription Error: $e");
          if (mounted) {
            setState(() => _isLoading = false);
            _sourceController.text = "❌ Transcription error: $e";
          }
        }
      } else {
        debugPrint("No audio path found to transcribe.");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyMacroWithAI(Macro macro) async {
    setState(() {
      _selectedMacro = macro;
      _isProcessing = true;
      _isTemplateCardExpanded = false; // Collapse template card
      _isGeneratedCardExpanded = true; // Expand generated note card
    });

    final prefs = await SharedPreferences.getInstance();
    String? geminiKey = prefs.getString('gemini_api_key');

    // Check if key is null or empty string, use defaults
    if (geminiKey == null || geminiKey.trim().isEmpty) {
      geminiKey = "";
    }

    // Only show dialog if we still don't have a key after all fallbacks
    if (geminiKey.trim().isEmpty) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Text("Missing AI Key",
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                      "To use AI features, please set your Gemini API Key in Settings.\n\nWithout a key, the system cannot process the transcript.",
                      style: GoogleFonts.inter(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("OK",
                          style: TextStyle(color: AppTheme.accent)),
                    )
                  ],
                ));
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // ✅ Use AIProcessingService — centralized AI call (Phase 1 refactor)
      final aiService = AIProcessingService();
      final mode = await AIProcessingService.getEffectiveMode();

      final result = await aiService.processNote(
        transcript: _sourceController.text,
        macroContent: macro.content,
        mode: mode,
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _finalController.text = result.formattedNote;
            _suggestions = result.missingSuggestions;
          });

          // 5. AUTO-SAVE: Update existing note or create new one
          try {
            final repository = ref.read(inboxNoteRepositoryProvider);
            if (_currentNoteId != null) {
              final note = await repository.getById(_currentNoteId!.toString());
              if (note != null) {
                note.originalText = _sourceController.text;
                note.formattedText = _finalController.text;
                note.appliedMacroId = int.tryParse(macro.id.toString()) ?? 0;
                note.title = macro.trigger;
                await repository.update(note);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("✅ Note saved and verified"),
                      backgroundColor: Colors.green),
                );
              }
            } else {
              final note = NoteModel()
                ..originalText = _sourceController.text
                ..formattedText = _finalController.text
                ..appliedMacroId = int.tryParse(macro.id.toString()) ?? 0
                ..title = macro.trigger
                ..status = NoteStatus.draft;
              final savedNote = await repository.create(note);
              setState(() => _currentNoteId = savedNote.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("✅ New note created (#${savedNote.id})"),
                      backgroundColor: Colors.green),
                );
              }
            }
          } catch (e) {
            debugPrint('❌ AUTO-SAVE FAILED: $e');
          }
        }
      } else {
        throw result.errorMessage ?? 'Processing failed';
      }
    } catch (e, stackTrace) {
      debugPrint('❌ FULL AI ERROR: $e');
      debugPrint('❌ STACK TRACE:\n$stackTrace');

      if (mounted) {
        String errorTitle = 'AI Processing Failed';
        String errorMessage = 'Failed to process template';
        Color errorColor = Colors.red;

        // Categorize error for better UX
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('invalid') && errorStr.contains('api key')) {
          errorTitle = 'Invalid API Key';
          errorMessage =
              'The Gemini API key is invalid or missing.\n\nPlease configure a valid key in Settings.';
          errorColor = Colors.orange;
        } else if (errorStr.contains('placeholder') ||
            errorStr.contains('your_')) {
          errorTitle = 'API Key Not Configured';
          errorMessage =
              'The default placeholder API key is still being used.\n\nPlease set a real Gemini API key in Settings.';
          errorColor = Colors.orange;
        } else if (errorStr.contains('network') ||
            errorStr.contains('connection') ||
            errorStr.contains('timeout')) {
          errorTitle = 'Network Error';
          errorMessage =
              'Could not connect to AI service.\n\nCheck your internet connection and try again.';
        } else if (errorStr.contains('503') ||
            errorStr.contains('overloaded')) {
          errorTitle = 'Service Temporarily Unavailable';
          errorMessage =
              'Gemini AI is currently overloaded.\n\nPlease try again in a few seconds.';
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorTitle,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(errorMessage, style: GoogleFonts.inter(fontSize: 12)),
            ],
          ),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Text('Error Details',
                      style: GoogleFonts.inter(color: Colors.white)),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      e.toString(),
                      style: GoogleFonts.sourceCodePro(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close',
                          style: TextStyle(color: AppTheme.accent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleTextFieldTap() {
    final text = _finalController.text;
    final selection = _finalController.selection;
    if (selection.baseOffset < 0) return;

    // ✅ Use TextProcessingService.findPlaceholderAtCursor (Phase 1 refactor)
    final placeholder = TextProcessingService.findPlaceholderAtCursor(
        text, selection.baseOffset);

    if (placeholder != null) {
      _finalController.selection = TextSelection(
        baseOffset: placeholder.start,
        extentOffset: placeholder.end,
      );
    }
  }

  void _copyCleanText() async {
    final text = _finalController.text;
    if (text.isEmpty) return;

    if (kIsWeb) {
      // Use the centralized Extension Injection Service
      final result = await ExtensionInjectionService.smartCopyAndInject(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message),
          backgroundColor: result.status == InjectionStatus.success
              ? Colors.green
              : Colors.blue,
          duration: const Duration(seconds: 2),
        ));
      }
    } else {
      // ✅ Use TextProcessingService.applySmartCopy (Phase 1 refactor)
      // FIXED: No longer deletes entire lines — removes only placeholder tokens
      final placeholderCount = TextProcessingService.countPlaceholders(text);
      final cleanText = TextProcessingService.applySmartCopy(text);

      await Clipboard.setData(ClipboardData(text: cleanText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cleaning_services,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("✅ Smart Copy Active",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        placeholderCount > 0
                            ? "Copied without $placeholderCount placeholder token(s)."
                            : "Copied — note is complete, no placeholders found.",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Auto-update status to COPIED if we have a draft ID
    if (_currentNoteId != null) {
      try {
        await ref
            .read(inboxNoteRepositoryProvider)
            .updateStatus(_currentNoteId!.toString(), NoteStatus.copied);
      } catch (e) {
        debugPrint("Failed to update status to copied: $e");
      }
    }
  }

  // ... inside _EditorScreenState

  void _insertSuggestion(Map<String, dynamic> suggestion) {
    final textToInsert = suggestion['text_to_insert'] as String;
    final currentText = _finalController.text;
    final selection = _finalController.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0) {
      start = end = currentText.length;
    }

    // Replace selection or insert at cursor
    final newText = currentText.replaceRange(start, end, " $textToInsert ");

    _finalController.text = newText;

    // Move cursor to end of insertion
    final newCursorPos = start + textToInsert.length + 2; // +2 for spaces
    _finalController.selection = TextSelection.collapsed(offset: newCursorPos);

    setState(() => _suggestions.remove(suggestion));
  }

  // _showAllTemplates() removed to show inline instead

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.noteNumber > 0 ? 'NO-${widget.noteNumber}' : 'Draft Note',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOriginalNoteCard(),
                        const SizedBox(height: 16),
                        _buildTemplateSelectorCard(),
                        const SizedBox(height: 16),
                        _buildGeneratedNoteCard(),
                        const SizedBox(height: 80), // Space for bottom dock
                      ],
                    ),
                  ),
                ),

                // Sticky Action Dock
                _buildStickyActionDock(),
              ],
            ),

            // Overlay for Initial Transcription
            if (_isLoading) const Positioned.fill(child: ProcessingOverlay()),

            // Overlay for AI Generation
            if (_isProcessing)
              const Positioned.fill(
                child: ProcessingOverlay(
                  cyclingMessages: [
                    'جاري معالجة الملاحظة...',
                    'التواصل مع الذكاء الاصطناعي...',
                    'تنسيق وهيكلة الملاحظة...',
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalNoteCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 18),
              const SizedBox(width: 8),
              Text("Original Note",
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface)),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text("READY",
                    style: GoogleFonts.inter(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: _sourceController.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Copied raw text"),
                      duration: Duration(seconds: 1)));
                },
                child: Text("Use Raw Text",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _isSourceExpanded = !_isSourceExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceController.text,
                  maxLines: _isSourceExpanded ? null : 3,
                  overflow: _isSourceExpanded ? null : TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _isSourceExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.3)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTemplateSelectorCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTemplateCardExpanded
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: _isTemplateCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isTemplateCardExpanded
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 0,
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible, tappable to toggle ──
          InkWell(
            onTap: () => setState(
                () => _isTemplateCardExpanded = !_isTemplateCardExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTemplateCardExpanded
                          ? Icons.extension
                          : Icons.extension_outlined,
                      key: ValueKey(_isTemplateCardExpanded),
                      color: _isTemplateCardExpanded
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Choose Template",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  // Show selected macro name when collapsed
                  if (!_isTemplateCardExpanded && _selectedMacro != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMacro!.trigger,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  // Just a standard arrow icon showing state
                  Icon(
                    _isTemplateCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          // ── Content — only visible when expanded ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isTemplateCardExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _macros.map((macro) {
                    final isSelected = _selectedMacro?.id == macro.id;
                    return FilterChip(
                      label: Text(macro.trigger),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) _applyMacroWithAI(macro);
                      },
                      backgroundColor: colorScheme.surface,
                      selectedColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: colorScheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                      showCheckmark: true,
                    );
                  }).toList(),
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedNoteCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = _finalController.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isGeneratedCardExpanded
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: _isGeneratedCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isGeneratedCardExpanded
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 0,
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible, tappable to toggle ──
          InkWell(
            onTap: hasContent
                ? () => setState(
                    () => _isGeneratedCardExpanded = !_isGeneratedCardExpanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isGeneratedCardExpanded
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      key: ValueKey(_isGeneratedCardExpanded),
                      color: _isGeneratedCardExpanded
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Generated Note",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (hasContent)
                    Icon(
                      _isGeneratedCardExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    )
                  else
                    Text(
                      "Select a template above",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Content — only visible when expanded ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isGeneratedCardExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _isProcessing
                  ? const SizedBox(height: 60, width: double.infinity)
                  : TextField(
                      controller: _finalController,
                      maxLines: null,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: "AI generated note will appear here...",
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                      onTap: _handleTextFieldTap,
                    ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionDock() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.4), width: 1)),
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          _copyCleanText();
        },
        icon: const Icon(Icons.content_copy_rounded, size: 18),
        label: const Text("SMART COPY / INJECT"),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Model Download Dialog (shown when Whisper model is not installed)
// ─────────────────────────────────────────────────────────────
class _ModelDownloadDialog extends StatefulWidget {
  @override
  _ModelDownloadDialogState createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _currentFile = '';
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      await ModelDownloadService().downloadModel(
        onProgress: (downloaded, total, fileName) {
          if (mounted) {
            setState(() {
              _progress = total > 0 ? downloaded / total : 0.0;
              _currentFile = fileName;
            });
          }
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Speech Model Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_downloading && _error == null)
            const Text(
              'The offline speech recognition model (~245 MB) needs to be downloaded. This is a one-time download.',
            ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}% — $_currentFile',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        if (!_downloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: Text(_error != null ? 'Retry' : 'Download'),
          ),
      ],
    );
  }
}
