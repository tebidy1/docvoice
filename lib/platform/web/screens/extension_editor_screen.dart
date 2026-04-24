// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// Models & Services
import '../../../core/entities/note_model.dart';
import '../../android/services/macro_service.dart';
import '../../../core/entities/macro.dart';
import '../../android/services/inbox_service.dart';
import '../../android/services/groq_service.dart';
import '../../../core/network/api_client.dart';
import '../../../presentation/widgets/pattern_highlight_controller.dart';
import '../../../presentation/widgets/processing_overlay.dart';
import 'package:soutnote/core/ai/ai_regex_patterns.dart';
import 'package:soutnote/core/ai/text_processing_service.dart';
import '../../../core/services/ai/ai_processing_service.dart';
import '../services/extension_injection_service.dart';
import '../../../core/entities/generated_output.dart'; // import GeneratedOutput
// ⚡ Gemini One-Shot AI
import '../../../core/services/multimodal_ai/multimodal_ai_service.dart';
import '../../../core/services/multimodal_ai/ai_studio_multimodal_service.dart';
import '../../../core/services/multimodal_ai/gemini_transcription_helper.dart';
import 'package:soutnote/core/ai/ai_prompt_constants.dart';
import 'package:soutnote/core/medical_departments.dart';
import '../../../core/services/department_service.dart';

class ExtensionEditorScreen extends StatefulWidget {
  final NoteModel draftNote;
  final int noteNumber;

  const ExtensionEditorScreen(
      {super.key, required this.draftNote, this.noteNumber = 0});

  @override
  State<ExtensionEditorScreen> createState() => _ExtensionEditorScreenState();
}

class _ExtensionEditorScreenState extends State<ExtensionEditorScreen> {
  // Services
  final _inboxService = InboxService();
  final _macroService = MacroService();

  // Controllers
  final _sourceController = TextEditingController();
  final _finalNoteController = PatternHighlightController(
    text: "",
    patternStyles: {
      AIRegexPatterns.selectPlaceholderPattern: const TextStyle(
          color: Colors.orange,
          backgroundColor: Color(0x33FF9800),
          fontWeight: FontWeight.bold),
      AIRegexPatterns.anyBracketPattern: const TextStyle(
          color: Colors.orange, backgroundColor: Color(0x33FF9800)),
      AIRegexPatterns.headerPattern: const TextStyle(
        decoration: TextDecoration.underline,
        decorationColor: Colors.white,
        decorationThickness: 2.0,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    },
  );
  // Smart Tabs State
  int _activeTabIndex = 0; // 0 = original, 1+ = generated outputs
  List<GeneratedOutput> _generatedOutputs = [];

  // State
  List<Macro> _quickMacros = [];
  Macro? _selectedMacro;
  bool _isGenerating = false;
  bool _isOneShotGenerating = false; // ⚡ One-Shot AI state
  bool _isOneShotMode = false; // ⚡ True when gemini_oneshot engine is selected
  bool _isLoading = false; // Optimistic UI: For audio processing
  bool _isTemplateCardExpanded = true; // Template card: expanded by default
  Future<void>?
      _backgroundTranscriptionFuture; // Optimistic UI: track background STT
  bool _showCleanTemplatePicker = false; // ✨ For Optimistic Clean UI

  // ⚡ One-Shot AI service (same as desktop)
  final MultimodalAIService _multimodalService = AIStudioMultimodalService();

  // AI Processing Animation
  final List<String> _statusMessages = [
    'Processing Note...',
    'Consulting AI...',
    'Structuring Note...',
  ];
  final List<String> _oneShotMessages = [
    '⚡ Sending to Gemini...',
    '⚡ Transcribing Audio...',
    '⚡ Applying Template...',
  ];

  @override
  void initState() {
    super.initState();
    String initialRaw = widget.draftNote.originalText;
    if (initialRaw.isEmpty) initialRaw = widget.draftNote.content;
    _sourceController.text = initialRaw;

    // Load existing generated outputs
    _generatedOutputs = widget.draftNote.generatedOutputs;

    if (_generatedOutputs.isNotEmpty) {
      _activeTabIndex = _generatedOutputs.length; // Focus latest tab
      _finalNoteController.text = _generatedOutputs.last.content ?? '';
      _isTemplateCardExpanded = false;
    } else if (widget.draftNote.formattedText.isNotEmpty) {
      // Legacy migration
      _generatedOutputs.add(GeneratedOutput(
          title: widget.draftNote.summary ?? 'AI Note',
          content: widget.draftNote.formattedText,
          macroId: widget.draftNote.appliedMacroId));
      _activeTabIndex = 1;
      _finalNoteController.text = widget.draftNote.formattedText;
      _isTemplateCardExpanded = false;
    } else {
      _isTemplateCardExpanded = true;
    }

    _loadMacros();

    // Check if One-Shot mode is active — if so skip transcription
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final sttEngine = prefs.getString('stt_engine_pref') ?? 'groq';
      // ALSO set _showCleanTemplatePicker = true if we have empty text AND audio!
      if (widget.draftNote.audioPath != null &&
          widget.draftNote.audioPath!.isNotEmpty &&
          _sourceController.text.trim().isEmpty) {
        if (mounted) setState(() => _showCleanTemplatePicker = true);
      }

      if (sttEngine == 'gemini_oneshot') {
        // One-Shot mode: skip transcription, show template card directly
        if (mounted) {
          setState(() {
            _isOneShotMode = true;
            _isTemplateCardExpanded = true;
          });
        }
      }
      _backgroundTranscriptionFuture = _processAudioIfNeeded();
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _finalNoteController.dispose();
    super.dispose();
  }

  List<String> _getCategories(Macro m) {
    if (m.category.isEmpty) return [];
    return m.category
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _loadMacros() async {
    // Reuse Mobile Macro Service
    final allMacros = await _macroService.getMacros();

    final prefs = await SharedPreferences.getInstance();
    final deptId = DepartmentService().value ?? prefs.getString('specialty');
    final deptNameEn = deptId != null
        ? MedicalDepartments.getById(deptId)?.nameEn
        : 'General Practice';

    final macros = allMacros.where((m) {
      final cats = _getCategories(m);
      if (cats.isEmpty) return true; // uncategorized are general?
      if (cats.contains('General') || cats.contains('General Practice'))
        return true;
      if (deptId != null && cats.contains(deptId)) return true;
      if (deptNameEn != null && cats.contains(deptNameEn))
        return true; // legacy support
      return false;
    }).toList();

    // Sort: Favorites first
    macros.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.trigger.compareTo(b.trigger);
    });

    if (mounted) {
      // Restore selected macro
      Macro? restoredMacro;
      if (_selectedMacro == null) {
        if (widget.draftNote.appliedMacroId != null) {
          try {
            restoredMacro = macros
                .firstWhere((m) => m.id == widget.draftNote.appliedMacroId);
          } catch (_) {}
        } else {
          final prefs = await SharedPreferences.getInstance();
          final lastId = prefs.getInt('last_selected_macro_id');
          if (lastId != null) {
            try {
              restoredMacro = macros.firstWhere((m) => m.id == lastId);
            } catch (_) {}
          }
        }
      }

      // Move the applied/restored macro to the front of the list
      if (restoredMacro != null) {
        macros.remove(restoredMacro);
        macros.insert(0, restoredMacro);
      }

      setState(() {
        _quickMacros = macros;
        if (restoredMacro != null) _selectedMacro = restoredMacro;
      });
    }
  }

  Future<void> _processAudioIfNeeded() async {
    final path = widget.draftNote.audioPath;
    if (path != null && _sourceController.text.isEmpty) {
      // Only process if we don't have text yet
      // ... Web Audio Fetching Logic from Mobile Editor ...
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            await _transcribeAudio(response.bodyBytes);
          } else {
            _showError("Failed to load audio: ${response.statusCode}");
            setState(() => _isLoading = false);
          }
        } catch (e) {
          _showError("Error fetching audio: $e");
          setState(() => _isLoading = false);
        }
      } else {
        // Should not happen in extension, but fallback
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false); // No audio to process
    }
  }

  Future<void> _transcribeAudio(Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localGroqKey = prefs.getString('groq_api_key');
      final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';

      // Gemini One-Shot: Transcribe via unified GeminiTranscriptionHelper
      if (sttEngine == 'gemini_oneshot') {
        final transcript = await GeminiTranscriptionHelper()
            .transcribeFromBytes(bytes, mimeType: 'audio/webm');
        if (transcript != null && mounted) {
          setState(() {
            _sourceController.text = transcript;
            _isOneShotMode = false;
          });
          _saveDraft();
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      bool transcribed = false;

      // 1. Try Direct Groq (if key exists AND user selected Groq)
      if (sttEngine == 'groq' &&
          localGroqKey != null &&
          localGroqKey.isNotEmpty) {
        print("DEBUG: Using Local Groq Key (Direct Mode)");
        final groqService = GroqService(apiKey: localGroqKey);
        final transcript =
            await groqService.transcribe(bytes, filename: 'recording.webm');

        if (transcript.startsWith("Error:")) {
          // Fallback if direct fails
          print("Direct Groq Failed: $transcript");
          if (transcript.contains("401")) {
            throw "Invalid Groq API Key";
          }
        } else {
          // Success
          if (mounted) {
            setState(() {
              _sourceController.text = transcript.trim();
              _isLoading = false;
            });
            _saveDraft();
          }
          transcribed = true;
        }
      }

      // 2. Use Backend Proxy (for Oracle, Native, or if Direct Groq failed/unselected)
      if (!transcribed) {
        final apiClient = ApiClient();
        await apiClient.init();
        print(
            "DEBUG: Transcribing via Backend ($sttEngine)... Token present: ${apiClient.hasToken}");

        final result = await apiClient.multipartPost(
          '/audio/transcribe',
          fileBytes: bytes,
          filename: 'recording.webm',
        );

        if (result['status'] == true) {
          final transcript = result['payload']['text'] ?? "";
          if (mounted) {
            setState(() {
              _sourceController.text = transcript.trim();
              _isLoading = false;
            });
            _saveDraft();
          }
        } else {
          throw result['message'] ?? 'Transcription failed';
        }
      }
    } catch (e) {
      _showError("Transcription failed: $e");
      if (mounted) {
        setState(() {
          _sourceController.text = "Transcription Failed";
          _isLoading = false;
        });
      }
    }
  }

  /// ⚡ ONE-SHOT AI: Send audio blob + template to Gemini in a single request
  Future<void> _applyOneShotAI(Macro macro) async {
    final audioPath = widget.draftNote.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      _showError(
          '⚡ No audio file found. Please re-record with Gemini One-Shot engine.');
      return;
    }

    // Fetch audio bytes from blob URL
    Uint8List audioBytes;
    try {
      final response = await http.get(Uri.parse(audioPath));
      if (response.statusCode != 200) {
        _showError('⚡ Failed to load audio (HTTP ${response.statusCode})');
        return;
      }
      audioBytes = response.bodyBytes;
    } catch (e) {
      _showError('⚡ Failed to read audio: $e');
      return;
    }

    setState(() {
      _isOneShotGenerating = true;
      _selectedMacro = macro;
      _isTemplateCardExpanded = false;
      _showCleanTemplatePicker = false; // ✨ Instant feedback
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // Get real specialty from DepartmentService via AIProcessingService
      final specialty = await AIProcessingService.getEffectiveSpecialty();
      final globalPrompt = prefs.getString('global_ai_prompt') ??
          AIPromptConstants.globalMasterPrompt;

      // Detect MIME type from blob (webm is the default for Chrome recording)
      const mimeType = 'audio/webm';

      final result = await _multimodalService.processAudioNote(
        audioBytes: audioBytes,
        mimeType: mimeType,
        macroContent: macro.content,
        globalPrompt: globalPrompt,
        specialty: specialty,
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(
              macroId: macro.id,
              title: macro.trigger,
              content: result.formattedNote,
            ));
            _activeTabIndex = _generatedOutputs.length;
            _finalNoteController.text = result.formattedNote;
            _showCleanTemplatePicker = false; // ✨ Transition to normal editor
          });
          _saveDraft();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('⚡ One-Shot complete (${result.providerName})',
                      style: const TextStyle(fontSize: 13))),
            ]),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
          ));
        }
      } else {
        _showError('⚡ One-Shot AI failed: ${result.errorMessage}');
      }
    } catch (e) {
      _showError('⚡ One-Shot AI error: $e');
    } finally {
      if (mounted) setState(() => _isOneShotGenerating = false);
    }
  }

  Future<void> _saveDraft() async {
    try {
      if (widget.draftNote.id > 0) {
        await _inboxService.updateNote(
          widget.draftNote.id,
          rawText: _sourceController.text,
          formattedText: _generatedOutputs.isNotEmpty
              ? _generatedOutputs.last.content ?? ''
              : '',
          generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
          summary: _selectedMacro?.trigger,
          suggestedMacroId: _selectedMacro?.id,
        );
      } else {
        final newNote = await _inboxService.addNote(
          _sourceController.text,
          formattedText: _generatedOutputs.isNotEmpty
              ? _generatedOutputs.last.content ?? ''
              : '',
          generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
          patientName: widget.draftNote.title,
          summary: _selectedMacro?.trigger,
          suggestedMacroId: _selectedMacro?.id,
        );
        // Update local model
        widget.draftNote.id = newNote.id;
      }
    } catch (e) {
      print("Auto-save failed: $e");
    }
  }

  Future<void> _applyTemplate(Macro macro) async {
    setState(() {
      _isGenerating = true;
      _selectedMacro = macro;
      // Set state for AI loading and card expansion
      _isTemplateCardExpanded = false; // Collapse template
    });

    if (_backgroundTranscriptionFuture != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('⏳ Waiting for background transcription to finish...'),
              duration: Duration(seconds: 1)),
        );
      }
      await _backgroundTranscriptionFuture;
      _backgroundTranscriptionFuture = null;
      if (!mounted) return;
      if (_sourceController.text.isEmpty ||
          _sourceController.text.startsWith('Transcription Failed') ||
          _sourceController.text.startsWith('Error')) {
        setState(() => _isGenerating = false);
        _showError(
            '⚠️ Cannot apply template: Background transcription failed or returned empty.');
        return;
      }
    }

    // Animation Timer - Removed, handled by ProcessingOverlay.dart

    try {
      final prefs = await SharedPreferences.getInstance();
      // Save selected template ID for UI restoration
      await prefs.setInt('last_selected_macro_id', macro.id);

      // ✅ Use centralized AIProcessingService (Phase 1 refactor)
      final globalPrompt = await AIProcessingService.getEffectivePrompt();
      final specialty = await AIProcessingService.getEffectiveSpecialty();
      final enableSuggestions =
          await AIProcessingService.isSmartSuggestionsEnabled();

      final aiService = AIProcessingService();
      final result = await aiService.processNote(
        transcript: _sourceController.text,
        macroContent: macro.content,
        mode:
            enableSuggestions ? AIProcessingMode.smart : AIProcessingMode.fast,
        specialty: specialty,
        globalPromptOverride: globalPrompt,
      );

      if (result.success) {
        final finalText = result.formattedNote;
        if (finalText.isEmpty) {
          _showError(
              "AI returned empty result. Please check API Key or try again.");
        }
        if (mounted) {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(
              title: macro.trigger,
              content: finalText,
            ));
            _activeTabIndex = _generatedOutputs.length;
            _finalNoteController.text = finalText;
            _showCleanTemplatePicker = false; // ✨ Transition to normal editor
          });
          _saveDraft();
        }
      } else {
        _showError("Generation failed: ${result.errorMessage}");
      }
    } catch (e) {
      _showError("AI Error: $e");
    } finally {
      // _generationTimer?.cancel(); // Removed
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _onManualEdit(String newText) {
    if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content = newText;
    }
    // Auto-save disabled manually for manual edits here, saved via FAB usually
  }

  void _switchTab(int index) {
    if (_activeTabIndex == index) return;

    // Save current tab content
    if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content =
          _finalNoteController.text;
    }

    setState(() {
      _activeTabIndex = index;
      if (index == 0) {
        _isTemplateCardExpanded = true;
      } else {
        _finalNoteController.text = _generatedOutputs[index - 1].content ?? '';
        _isTemplateCardExpanded = false;
      }
    });
  }

  void _deleteTab(int index) {
    if (index == 0) return; // Cannot delete raw transcript

    setState(() {
      _generatedOutputs.removeAt(index - 1);

      // Select the preceding tab
      if (_activeTabIndex == index) {
        _switchTab(index - 1);
      } else if (_activeTabIndex > index) {
        // Tab shifted left
        _activeTabIndex--;
      }
    });

    _saveDraft();
  }

  Future<void> _smartCopyAndInject() async {
    String sourceText = '';
    if (_activeTabIndex == 0) {
      sourceText = _sourceController.text;
    } else if (_activeTabIndex > 0 &&
        _activeTabIndex <= _generatedOutputs.length) {
      sourceText = _generatedOutputs[_activeTabIndex - 1].content ?? '';
    }

    // Removed placeholders formatting here, handled by ExtensionInjectionService internally

    final result =
        await ExtensionInjectionService.smartCopyAndInject(sourceText);

    if (result.status == InjectionStatus.failed) {
      _showError(result.message);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: result.status == InjectionStatus.success
            ? Colors.green
            : Colors.blue,
        duration: const Duration(seconds: 2),
      ));
    }

    // Update Status
    if (widget.draftNote.id > 0) {
      await _inboxService.updateStatus(widget.draftNote.id, NoteStatus.copied);
    }
  }

  // Removed _copyCleanText as it is merged into _smartCopyAndInject

  void _handleEditorTap() {
    if (_activeTabIndex == 0)
      return; // Don't highlight placeholders in raw text

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      final selection = _finalNoteController.selection;
      if (!selection.isValid || !selection.isCollapsed) return;

      // ✅ Use TextProcessingService.findPlaceholderAtCursor (Phase 1 refactor)
      final placeholder = TextProcessingService.findPlaceholderAtCursor(
          _finalNoteController.text, selection.baseOffset);
      if (placeholder != null) {
        _finalNoteController.selection = TextSelection(
          baseOffset: placeholder.start,
          extentOffset: placeholder.end,
        );
      }
    });
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  // --- UI BUILDERS (Adapted for Extension Dark Theme) ---

  // --- UI BUILDERS (New Card Layout) ---

  @override
  Widget build(BuildContext context) {
    if (_showCleanTemplatePicker) {
      return _buildCleanTemplateScreen(context);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 80), // Add bottom padding for FAB
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header / Title Row
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  // Fallback for root? unlikely in extension stack but safe
                                }
                              },
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                widget.noteNumber > 0
                                    ? "NO-${widget.noteNumber}"
                                    : "Draft Note",
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            _buildStatusBadge(),
                            const Spacer(),
                            // Use Raw Text button - hidden in One-Shot mode
                            if (!_isOneShotMode)
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text: _sourceController.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Copied raw text"),
                                          duration: Duration(seconds: 1)));
                                },
                                child: Text("Use Raw Text",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Smart Tabs logic instead of separate accordions
                        const SizedBox(height: 16),
                        if (_isOneShotMode)
                          _buildTemplateSelectorCard()
                        else
                          _buildTemplateSelectorCard(),
                        const SizedBox(height: 16),
                        _buildSmartTabsEditorCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Overlay for Initial Transcription
            if (_isLoading) const Positioned.fill(child: ProcessingOverlay()),

            // Overlay for AI Generation (classic mode)
            if (_isGenerating)
              Positioned.fill(
                child: ProcessingOverlay(
                  cyclingMessages: _statusMessages,
                ),
              ),

            // ⚡ Overlay for One-Shot AI generation
            if (_isOneShotGenerating)
              Positioned.fill(
                child: ProcessingOverlay(
                  cyclingMessages: _oneShotMessages,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _smartCopyAndInject,
        icon: const Icon(Icons.input),
        label: const Text("SMART COPY / INJECT"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusBadge() {
    // Check if "Ready"
    bool isReady = _finalNoteController.text.isNotEmpty;
    String text = isReady ? "READY" : "DRAFT";
    Color color = isReady ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // _buildOriginalNoteCard removed for Smart Tabs

  Widget _buildTemplateSelectorCard() {
    // In One-Shot mode the header shows an amber bolt indicator
    final headerColor =
        _isOneShotMode ? Colors.amber : Theme.of(context).colorScheme.primary;
    final headerIcon = _isOneShotMode ? Icons.bolt : Icons.extension;
    final headerTitle =
        _isOneShotMode ? '⚡ Choose Template (One-Shot)' : 'Choose Template';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTemplateCardExpanded
              ? headerColor.withOpacity(0.5)
              : Theme.of(context).dividerColor,
          width: _isTemplateCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isTemplateCardExpanded
            ? [
                BoxShadow(
                  color: headerColor.withOpacity(0.08),
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
                          ? headerIcon
                          : Icons.extension_outlined,
                      key: ValueKey(_isTemplateCardExpanded),
                      color: _isTemplateCardExpanded
                          ? headerColor
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.54),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    headerTitle,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  if (!_isTemplateCardExpanded && _selectedMacro != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMacro!.trigger,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: headerColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    _isTemplateCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.38),
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
                  children: _quickMacros.map((macro) {
                    final isSelected = _selectedMacro?.id == macro.id;
                    return FilterChip(
                      label: Text(macro.trigger),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) {
                          _applyTemplate(macro);
                        }
                      },
                      backgroundColor: Theme.of(context).dividerColor,
                      selectedColor: headerColor.withOpacity(0.2),
                      checkmarkColor: headerColor,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? headerColor
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontFamily: 'Inter',
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? headerColor : Colors.transparent,
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

  Widget _buildSmartTabsEditorCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TAB BAR UI ---
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black12
                  : Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Source Tab (Always present)
                _buildTab(
                  index: 0,
                  icon: Icons.mic_none,
                  label: "Source",
                ),

                // Generated Output Tabs
                for (int i = 0; i < _generatedOutputs.length; i++)
                  _buildTab(
                    index: i + 1,
                    icon: Icons.auto_awesome,
                    label: _generatedOutputs[i].title ?? 'AI Note',
                    onDelete: () => _deleteTab(i + 1),
                  ),
              ],
            ),
          ),

          // --- EDITOR AREA ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: _isGenerating
                ? const SizedBox(height: 60)
                : _activeTabIndex == 0
                    ? TextField(
                        controller: _sourceController,
                        maxLines: null,
                        minLines: 15,
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(bottom: 16),
                          hintText: "Original transcript will appear here...",
                          hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.24)),
                          fillColor: Colors.transparent,
                          filled: true,
                        ),
                      )
                    : TextField(
                        controller: _finalNoteController,
                        maxLines: null,
                        minLines: 15,
                        onChanged: _onManualEdit,
                        onTap: _handleEditorTap,
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(bottom: 16),
                          hintText: "AI generated note will appear here...",
                          hintStyle: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.24)),
                          fillColor: Colors.transparent,
                          filled: true,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    VoidCallback? onDelete,
  }) {
    final bool isActive = _activeTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _switchTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.surface : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            right: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(12),
                child: Icon(Icons.close,
                    size: 14, color: colorScheme.onSurface.withOpacity(0.4)),
              )
            ]
          ],
        ),
      ),
    );
  }

  // ✨ NEW: Clean Template Selection UI for Extension
  Widget _buildCleanTemplateScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headerColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF4AC2E2)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Note',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    // Slide up & fade in animation, updated for dramatic impact
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 300.0, end: 0.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Opacity(
                            opacity: (1.0 - (value / 300.0)).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 48, color: headerColor.withOpacity(0.8)),
                            const SizedBox(height: 16),
                            Text(
                              "How would you like to format this note?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Choose a template to get started.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 32),
                            _buildCleanTemplateChips(theme, headerColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Overlays
            if (_isGenerating || _isLoading)
              Positioned.fill(
                child: ProcessingOverlay(
                  cyclingMessages: _statusMessages,
                ),
              ),

            if (_isOneShotGenerating)
              Positioned.fill(
                child: ProcessingOverlay(
                  cyclingMessages: _oneShotMessages,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanTemplateChips(ThemeData theme, Color headerColor) {
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      child: Wrap(
        spacing: 12.0,
        runSpacing: 12.0,
        alignment: WrapAlignment.center,
        children: _quickMacros.map((macro) {
          return ActionChip(
            label: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(macro.trigger),
            ),
            onPressed: () {
              setState(() =>
                  _showCleanTemplatePicker = false); // ✨ Immediate dismiss
              _applyTemplate(macro);
            },
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
            labelStyle: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
            elevation: 1,
          );
        }).toList(),
      ),
    );
  }
}
