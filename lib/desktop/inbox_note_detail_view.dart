import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inbox_note.dart';
import '../mobile_app/models/generated_output.dart';
import '../models/macro.dart';
import '../models/smart_suggestion.dart';
import '../services/inbox_service.dart';
import '../services/macro_service.dart';
import '../utils/window_manager_helper.dart';
import '../widgets/processing_overlay.dart';
import '../widgets/pattern_highlight_controller.dart';
// ✅ Core AI Brain — centralized services (Phase 1 refactor)
import '../core/ai/ai_regex_patterns.dart';
import '../core/ai/text_processing_service.dart';
import '../services/ai/ai_processing_service.dart';
import '../services/windows_injector.dart';
// ⚡ Multimodal AI — Windows Pilot (Phase 1)
import '../features/multimodal_ai/multimodal_ai_service.dart';
import '../features/multimodal_ai/ai_studio_multimodal_service.dart';
import '../features/multimodal_ai/gemini_transcription_helper.dart';
import 'dart:io' show File;
import '../core/medical_departments.dart';
import '../services/department_service.dart';
class InboxNoteDetailView extends StatefulWidget {
  final NoteModel note;
  final Macro? autoStartMacro;
  final Stream<String>? pendingTextStream; // For instant open after Groq/Oracle recording
  final int noteNumber; // 1-based, oldest = 1
  /// When provided, the view enters One-Shot mode:
  /// The template card is shown immediately, and choosing a template sends
  /// [audio file at oneShotAudioPath] + template prompt to Gemini in one request.
  final String? oneShotAudioPath;

  const InboxNoteDetailView({
    super.key,
    required this.note,
    this.autoStartMacro,
    this.pendingTextStream,
    this.noteNumber = 0,
    this.oneShotAudioPath,
  });

  @override
  State<InboxNoteDetailView> createState() => _InboxNoteDetailViewState();
}

class _InboxNoteDetailViewState extends State<InboxNoteDetailView> {
  final _inboxService = InboxService();
  final _macroService = MacroService();

  final _finalNoteController = PatternHighlightController(
    text: "",
    patternStyles: {
      // ✅ Using centralized AIRegexPatterns (Phase 1 refactor)
      AIRegexPatterns.selectPlaceholderPattern:
          const TextStyle(
              color: Colors.orange,
              backgroundColor: Color(0x33FF9800),
              fontWeight: FontWeight.bold),
      AIRegexPatterns.anyBracketPattern:
          const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800)),
      AIRegexPatterns.headerPattern: const TextStyle(
        decoration: TextDecoration.underline,
        decorationColor: Colors.white,
        decorationThickness: 2.0,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    },
  );
  Macro? _selectedMacro;
  bool _isGenerating = false;
  bool _isOneShotGenerating = false; // ⚡ One-Shot AI state
  bool _isTemplateCardExpanded = true;  // Accordion: template card expanded by default
  List<SmartSuggestion> _suggestions = [];
  List<Macro> _quickMacros = [];

  // Smart Tabs State
  int _activeTabIndex = 0; // 0 = Transcript (Source), 1+ = Generated Outputs
  List<GeneratedOutput> _generatedOutputs = [];

  // ⚡ One-Shot AI: the service instance (swap implementation here for Vertex AI)
  final MultimodalAIService _multimodalService = AIStudioMultimodalService();

  // AI Processing Ring variables
  Timer? _generationTimer;
  int _elapsedSeconds = 0;
  int _statusMessageIndex = 0;
  final List<String> _statusMessages = [
    'Processing Note...',
    'Consulting AI...',
    'Structuring Note...',
  ];

  // Dynamic Layout & Streaming
  bool _isLoadingText = false;
  bool _isOneShotMode = false;
  bool _showCleanTemplatePicker = false; // ✨ For Optimistic Clean UI
  StreamSubscription? _textStreamSubscription;
  Timer? _debounceTimer;
  Future<void>? _backgroundTranscriptionFuture;

  @override
  void initState() {
    super.initState();
    _dockWindow();
    _loadQuickMacros();

    // ⚡ ONE-SHOT MODE: entered via gemini_oneshot STT engine
    if (widget.oneShotAudioPath != null) {
      _isOneShotMode = true;
      _isTemplateCardExpanded = true;
      
      // Proactive 2-Step Transcription: If this is a new recording (placeholder text), transcribe it immediately in the background.
      if (widget.note.rawText.isEmpty || widget.note.rawText.contains('لا يوجد نص')) {
        _showCleanTemplatePicker = true; // Shows the clean UI
        _backgroundTranscriptionFuture = _proactiveTranscribe(widget.oneShotAudioPath!);
      } else {
        // If we already have text or it's an existing note opened in One-Shot mode, turn off One-Shot
        // to force subsequent macro clicks to use the text-based generator.
        _isOneShotMode = false;
      }
      return; 
    }

    // Attempt to determine if we opened an existing note while in Gemini One-Shot mode
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       if (widget.oneShotAudioPath == null && widget.note.audioPath != null && widget.note.audioPath!.isNotEmpty) {
           final prefs = await SharedPreferences.getInstance();
           final sttEngine = prefs.getString('stt_engine_desktop_pref') ?? 'oracle_live';
           if (sttEngine == 'gemini_oneshot' && mounted) {
              setState(() {
                 _isOneShotMode = true;
                 _isTemplateCardExpanded = true;
              });
           }
       }
    });

    // 1. Setup Stream (If Instant Open after Groq/Oracle recording)
    if (widget.pendingTextStream != null) {
      _isLoadingText = true;
      
      // Start the same animation timer as AI generation
      _generationTimer?.cancel();
      _generationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
            _statusMessageIndex = (_statusMessageIndex + 1) % _statusMessages.length;
          });
        }
      });

      _textStreamSubscription = widget.pendingTextStream!.listen((text) {
        if (mounted) {
            setState(() {
             _isLoadingText = false; // Stop Loading
             _generationTimer?.cancel(); // Stop animation
             
             // Update the "source" note model effectively so future operations use this text
             widget.note.rawText = text; // <-- CRITICAL FIX: Ensure UI reads from NoteModel
           });
        }
      }, onError: (e) {
         if (mounted) {
             _showError("Transcription Failed: $e");
             setState(() {
               _isLoadingText = false;
               _generationTimer?.cancel();
             });
         }
      }, onDone: () {
         if (mounted && _isLoadingText) {
            setState(() {
              _isLoadingText = false;
              _generationTimer?.cancel();
            });
         }
      });
    }

    // 2. Initial Load from passed widget (Fast) - Only if not loading stream
    if (widget.note.generatedOutputs.isNotEmpty) {
       _generatedOutputs = List.from(widget.note.generatedOutputs);
       _activeTabIndex = _generatedOutputs.length;
       _finalNoteController.text = _generatedOutputs.last.content ?? "";
       _isTemplateCardExpanded = false;
    } else if (widget.note.formattedText.isNotEmpty && !_isLoadingText) {
      // Legacy compatibility
      final legacyName = widget.note.summary ?? 'Legacy Note';
      _generatedOutputs.add(GeneratedOutput(
        title: legacyName, 
        content: widget.note.formattedText,
        macroId: widget.note.appliedMacroId,
      ));
      _activeTabIndex = 1;
      _finalNoteController.text = widget.note.formattedText;
      _isTemplateCardExpanded = false;
    } else {
      _isTemplateCardExpanded = true;
      _finalNoteController.text = widget.note.rawText;
    }
    
    // 3. Fresh Fetch from Database (Robust)
    // Fixes "Stale Data" issue where parent list has old object
    if (!_isLoadingText) {
       _refreshNoteContent();
    }

    if (widget.autoStartMacro != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyTemplate(widget.autoStartMacro!);
      });
    }
  }

  Future<void> _refreshNoteContent() async {
    try {
      final freshNote = await _inboxService.getNoteById(widget.note.id);
      if (freshNote != null) {
        if (mounted) {
           setState(() {
             // 1. Update Text if empty (or force update if needed, but usually we trust local if user is typing)
             if (_generatedOutputs.isEmpty && freshNote.generatedOutputs.isNotEmpty) {
                 _generatedOutputs = List.from(freshNote.generatedOutputs);
                 _activeTabIndex = _generatedOutputs.length;
                 _finalNoteController.text = _generatedOutputs.last.content ?? "";
                 _isTemplateCardExpanded = false;
             } else if (_generatedOutputs.isEmpty && freshNote.formattedText.isNotEmpty) {
                 final legacyName = freshNote.summary ?? 'Legacy Note';
                 _generatedOutputs.add(GeneratedOutput(
                   title: legacyName, 
                   content: freshNote.formattedText,
                   macroId: freshNote.appliedMacroId,
                 ));
                 _activeTabIndex = 1;
                 _finalNoteController.text = freshNote.formattedText;
                 _isTemplateCardExpanded = false;
             }
             
             // 2. Restore Selected Macro
             if (_selectedMacro == null && freshNote.appliedMacroId != null) {
                 // Try to find in quick macros first
                 final found = _quickMacros.firstWhere(
                     (m) => m.id == freshNote.appliedMacroId, 
                     orElse: () => Macro()..id = -1 // Dummy
                 );
                 
                 if (found.id != -1) {
                     _selectedMacro = found;
                 } else {
                     // If not in quick macros, we might need to fetch it?
                     // For now, let's just leave it or try to fetch from service if we want to be perfect.
                     // But _quickMacros usually has popular ones.
                     // Let's rely on _loadQuickMacros logic too, but this refreshes it.
                     
                     // Optimization: If we really want to show it, we should fetch it.
                     _macroService.getAllMacros().then((all) {
                         final exact = all.where((m) => m.id == freshNote.appliedMacroId).firstOrNull;
                         if (exact != null && mounted) {
                             setState(() => _selectedMacro = exact);
                         }
                     });
                 }
             }
           });
        }
      }
    } catch (e) {
      print("Error fetching fresh note content: $e");
    }
  }

  Future<void> _loadQuickMacros() async {
    await _macroService.init();

    final prefs = await SharedPreferences.getInstance();
    final deptId = DepartmentService().value ?? prefs.getString('specialty');
    final allowedCategories = (deptId != null 
        ? MedicalDepartments.getRelevantCategories(deptId)
        : ['General']).map((c) => c.toLowerCase()).toList();

    bool isAllowed(Macro m) {
      // The API might send category as "[Cardiology, General]" or "Cardiology, General"
      final cleanCat = m.category.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
      final cats = cleanCat.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
      
      if (cats.isEmpty) return true;
      if (cats.any((c) => c == 'general' || c == 'general practice')) return true;
      return cats.any((c) => allowedCategories.contains(c));
    }

    final allMacros = await _macroService.getAllMacros();
    final allowedMacros = allMacros.where(isAllowed).toList();

    allowedMacros.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.trigger.compareTo(b.trigger);
    });

    if (mounted) {
      Macro? restoredMacro;
      if (_selectedMacro == null && widget.note.appliedMacroId != null) {
          restoredMacro = allowedMacros.where((m) => m.id == widget.note.appliedMacroId).firstOrNull;
          if (restoredMacro != null) {
              allowedMacros.remove(restoredMacro);
              allowedMacros.insert(0, restoredMacro);
          }
      }

      setState(() {
         _quickMacros = allowedMacros;
         if (restoredMacro != null) _selectedMacro = restoredMacro;
      });
    }
  }

  @override
  void dispose() {
    _generationTimer?.cancel();
    _textStreamSubscription?.cancel(); // Clean up stream
    _debounceTimer?.cancel();
    
    // Sync current text field state before saving
    if (_activeTabIndex == 0) {
      widget.note.rawText = _finalNoteController.text;
    } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content = _finalNoteController.text;
    }
    
    // Attempt one final sync fire-and-forget in case user typed quickly and closed
    _inboxService.updateNote(
      widget.note.id,
      rawText: widget.note.rawText,
      formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '',
      generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
      summary: widget.note.summary,
      suggestedMacroId: widget.note.suggestedMacroId,
    );

    _finalNoteController.dispose();
    _restoreWindow();
    super.dispose();
  }

  Future<void> _dockWindow() async {
    if (mounted) {
      await WindowManagerHelper.expandToSidebar(context);
    }
  }

  Future<void> _restoreWindow() async {
    // Restore to sidebar dimensions (InboxManagerDialog is still open underneath)
    if (mounted) {
       await WindowManagerHelper.expandToSidebar(context);
    }
  }

  Future<void> _applyTemplate(Macro macro) async {
    setState(() {
      _isGenerating = true;
      _selectedMacro = macro;
      _elapsedSeconds = 0;
      _statusMessageIndex = 0;
      _isTemplateCardExpanded = false;  // Collapse template accordion
    });

    // Start timer for AI Processing Ring
    _generationTimer?.cancel();
    _generationTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _statusMessageIndex =
              (_statusMessageIndex + 1) % _statusMessages.length;
        });
      }
    });

    // Optimistic UI: If transcription is still running in background, wait for it!
    if (_backgroundTranscriptionFuture != null) {
      await _backgroundTranscriptionFuture;
      _backgroundTranscriptionFuture = null;
      if (!mounted) return;
      if (widget.note.rawText.isEmpty) {
        setState(() => _isGenerating = false);
        _generationTimer?.cancel();
        _showError("فشل في تحويل الصوت إلى نص. لا يمكن تطبيق القالب.");
        return;
      }
    }

    try {
      // ✅ Use centralized AIProcessingService (Phase 1 refactor)
      final aiService = AIProcessingService();
      final enableSuggestions = await AIProcessingService.isSmartSuggestionsEnabled();
      
      final result = await aiService.processNote(
        transcript: widget.note.rawText,
        macroContent: macro.content,
        mode: enableSuggestions ? AIProcessingMode.smart : AIProcessingMode.fast,
      );

      if (result.success) {
        if (enableSuggestions) {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(
              macroId: macro.id,
              title: macro.trigger, 
              content: result.formattedNote
            ));
            _activeTabIndex = _generatedOutputs.length;
            _finalNoteController.text = result.formattedNote;
            _suggestions = result.missingSuggestions
                .map((s) => SmartSuggestion.fromJson(s))
                .toList();
            _showCleanTemplatePicker = false; // Transition to normal editor
          });
          _autoSaveGeneratedContent(result.formattedNote, macro);
        } else {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(
              macroId: macro.id,
              title: macro.trigger, 
              content: result.formattedNote
            ));
            _activeTabIndex = _generatedOutputs.length;
            _finalNoteController.text = result.formattedNote;
            _suggestions = [];
            _showCleanTemplatePicker = false; // Transition to normal editor
          });
          _autoSaveGeneratedContent(result.formattedNote, macro);
        }
      } else {
        _showError("Failed to generate note: ${result.errorMessage}");
      }
    } catch (e) {
      print("DetailView: Error: $e");
      _showError("Generation failed: $e");
    } finally {
      _generationTimer?.cancel();
      setState(() => _isGenerating = false);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════
  // 🎙 PROACTIVE TRANSCRIPTION (2-Step Architecture Step 1)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _proactiveTranscribe(String audioPath) async {
    // OPTIMISTIC UI: We intentionally DO NOT set _isLoadingText to true
    // so the user can immediately select a template while this runs in the background.
    // Uses the unified GeminiTranscriptionHelper (single source of truth).

    final transcript = await GeminiTranscriptionHelper().transcribeFromPath(audioPath);

    if (mounted) {
      if (transcript != null) {
        setState(() => _isOneShotMode = false);

        widget.note.rawText = transcript;
        widget.note.originalText = transcript;

        await _inboxService.updateNote(
          widget.note.id,
          rawText: transcript,
        );
      } else {
        _showError('⚠️ Background transcription failed.');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ⚡ ONE-SHOT AI: Audio + Template → Gemini 2.5 Flash (Multimodal)
  // ═══════════════════════════════════════════════════════════════════════
  // *DEPRECATED* but kept for fallback or specific manual triggers.
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _applyOneShotAI(Macro macro) async {
    // Primary: oneShotAudioPath (when launched from Gemini One-Shot engine)
    // Fallback: note.audioPath (when manually triggered from an existing note)
    final audioPath = widget.oneShotAudioPath ?? widget.note.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      _showError(
        '⚡ One-Shot AI requires an audio file.\n'
        'Record using the "Gemini One-Shot AI" engine to use this feature.',
      );
      return;
    }

    // Read the audio bytes from disk
    Uint8List audioBytes;
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        _showError('Audio file not found at: $audioPath');
        return;
      }
      audioBytes = await file.readAsBytes();
    } catch (e) {
      _showError('Failed to read audio file: $e');
      return;
    }

    // Determine MIME type from file extension
    final ext = audioPath.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'm4a'  => 'audio/m4a',
      'mp4'  => 'audio/mp4',
      'webm' => 'audio/webm',
      'ogg'  => 'audio/ogg',
      _      => 'audio/wav', // Windows default
    };

    setState(() {
      _isOneShotGenerating = true;
      _selectedMacro = macro;
      _isTemplateCardExpanded = false;
      _elapsedSeconds = 0;
      _statusMessageIndex = 0;
    });

    // Animate while waiting
    _generationTimer?.cancel();
    _generationTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _statusMessageIndex = (_statusMessageIndex + 1) % _statusMessages.length;
        });
      }
    });

    try {
      // Fetch settings using the unified AIProcessingService methods
      final globalPrmt = await AIProcessingService.getEffectivePrompt();
      final specialty = await AIProcessingService.getEffectiveSpecialty();

      // Single multimodal call — transcription + formatting in one pass
      final result = await _multimodalService.processAudioNote(
        audioBytes:   audioBytes,
        mimeType:     mimeType,
        macroContent: macro.content,
        globalPrompt: globalPrmt,
        specialty:    specialty,
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(
              macroId: macro.id,
              title: macro.trigger, 
              content: result.formattedNote
            ));
            _activeTabIndex = _generatedOutputs.length;
            _finalNoteController.text = result.formattedNote;
            _suggestions = []; // One-Shot mode has no separate suggestions
          });
          await _autoSaveGeneratedContent(result.formattedNote, macro);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '⚡ One-Shot AI complete (${result.providerName})',
                    style: const TextStyle(fontSize: 13),
                  )),
                ],
              ),
              backgroundColor: const Color(0xFF1B5E20),
              duration: const Duration(seconds: 3),
            ));
          }
        }
      } else {
        _showError('⚡ One-Shot AI failed: ${result.errorMessage}');
      }
    } catch (e) {
      _showError('⚡ One-Shot AI error: $e');
    } finally {
      _generationTimer?.cancel();
      if (mounted) setState(() => _isOneShotGenerating = false);
    }
  }

  Future<void> _autoSaveGeneratedContent(String content, Macro macro) async {
      try {
        await _inboxService.updateNote(
          widget.note.id,
          rawText: widget.note.rawText.isNotEmpty ? widget.note.rawText : 'لا يوجد نص اصلي عند اختيار هذا النموذج',
          formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '',
          generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
          summary: macro.trigger, // Store template name for badge display
          suggestedMacroId: macro.id, 
        );
        
        // Update local object so dispose/'Back' saves the correct summary too
        widget.note.summary = macro.trigger;
        widget.note.suggestedMacroId = macro.id;
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("✅ Auto-saved AI Result"),
             backgroundColor: Colors.green,
             duration: Duration(seconds: 2),
           ));
        }
      } catch (e) {
        print("Auto-save failed: $e");
      }
  }

  void _onManualEdit(String newText) {
    if (_activeTabIndex == 0) {
      widget.note.rawText = newText;
    } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content = newText;
    }
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _saveDraftUpdate();
    });
  }

  Future<void> _saveDraftUpdate() async {
    try {
      if (!mounted) return;
      
      // Sync current text field state before saving
      if (_activeTabIndex == 0) {
        widget.note.rawText = _finalNoteController.text;
      } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
        _generatedOutputs[_activeTabIndex - 1].content = _finalNoteController.text;
      }
      
      await _inboxService.updateNote(
        widget.note.id,
        rawText: widget.note.rawText.isNotEmpty ? widget.note.rawText : 'لا يوجد نص اصلي عند اختيار هذا النموذج', // REQUIRED by backend to not lose transcript
        formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '',
        generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
        summary: widget.note.summary,
        suggestedMacroId: widget.note.suggestedMacroId,
      );
      print("📝 Windows Auto-saved manual edits to cloud");
    } catch (e) {
      print("❌ Windows Auto-save failed: $e");
    }
  }

  void _switchTab(int index) {
    if (_activeTabIndex == index) return;

    // Save current tab content
    if (_activeTabIndex == 0) {
      widget.note.rawText = _finalNoteController.text;
    } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content = _finalNoteController.text;
    }

    setState(() {
      _activeTabIndex = index;
      if (index == 0) {
        _finalNoteController.text = widget.note.rawText;
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
    
    // Auto save the deletion
    _inboxService.updateNote(
      widget.note.id,
      generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
      formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content ?? '' : '',
    );
  }

  void _insertSuggestion(SmartSuggestion suggestion) {
    final currentText = _finalNoteController.text;
    final cursorPos = _finalNoteController.selection.baseOffset;

    final insertPos = cursorPos >= 0 ? cursorPos : currentText.length;
    final insertedText = '\n' + suggestion.textToInsert;

    final newText = currentText.substring(0, insertPos) +
        insertedText +
        currentText.substring(insertPos);

    _finalNoteController.text = newText;

    _finalNoteController.selection = TextSelection(
      baseOffset: insertPos + 1,
      extentOffset: insertPos + insertedText.length,
    );

    setState(() {
      _suggestions.removeWhere((s) => s.label == suggestion.label);
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _getCleanText() {
    // Get text from the currently active tab
    String sourceText = '';
    if (_activeTabIndex == 0) {
      sourceText = widget.note.rawText;
    } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      sourceText = _generatedOutputs[_activeTabIndex - 1].content ?? '';
    }
    
    // ✅ Use TextProcessingService.applySmartCopy (Phase 1 refactor)
    // FIXED: Removes placeholder tokens inline, NOT entire lines
    return TextProcessingService.applySmartCopy(sourceText);
  }

  Future<void> _smartCopyAndInject() async {
    final cleanText = _getCleanText();
    if (cleanText.isEmpty) {
      _showError("No content to inject");
      return;
    }

    try {
      // Use smartInject: handles alwaysOnTop toggle + blur + Ctrl+V
      await WindowsInjector().smartInject(cleanText);
      
      // SET STATUS TO COPIED
      await _inboxService.updateStatus(widget.note.id, NoteStatus.copied);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Copied & Injected into EMR"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError("Inject failed: $e");
    }
  }

  void _handleEditorTap() {
      if (_activeTabIndex == 0) return; // Don't format placeholders in raw text
      
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

  bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\r' ||
        char == '.' ||
        char == ',' ||
        char == ':' ||
        char == ';' ||
        char == '(' ||
        char == ')' ||
        char == '[' ||
        char == ']';
  }

  void _navigateToNextWord() {
    final text = _finalNoteController.text;
    int currentPos = _finalNoteController.selection.end;

    if (currentPos >= text.length) return;

    while (currentPos < text.length && _isWordBoundary(text[currentPos])) {
      currentPos++;
    }

    if (currentPos >= text.length) return;

    int end = currentPos;
    while (end < text.length && !_isWordBoundary(text[end])) {
      end++;
    }

    setState(() {
      _finalNoteController.selection = TextSelection(
        baseOffset: currentPos,
        extentOffset: end,
      );
    });
  }

  void _navigateToPreviousWord() {
    final text = _finalNoteController.text;
    int currentPos = _finalNoteController.selection.start;

    if (currentPos <= 0) return;

    currentPos--;

    while (currentPos > 0 && _isWordBoundary(text[currentPos])) {
      currentPos--;
    }

    if (currentPos <= 0) {
      setState(() {
        _finalNoteController.selection =
            const TextSelection.collapsed(offset: 0);
      });
      return;
    }

    int start = currentPos;
    while (start > 0 && !_isWordBoundary(text[start - 1])) {
      start--;
    }

    setState(() {
      _finalNoteController.selection = TextSelection(
        baseOffset: start,
        extentOffset: currentPos + 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_showCleanTemplatePicker) {
      return _buildCleanTemplateScreen(theme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
       children: [
        MouseRegion(
        onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
        onExit: (_) => WindowManagerHelper.setOpacity(0.95), // Less transparent
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              left: BorderSide(color: colorScheme.surface, width: 1),
            ),
          ),
          child: Column(
            children: [
              _buildSmartHeader(theme),
              
              // Template Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTemplateSelectorCard(theme),
              ),

              const SizedBox(height: 8),

              // Smart Tabs Editor
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _buildSmartTabsEditorCard(theme),
                ),
              ),
              
              // 4. Action Dock
              _buildActionDock(theme),
            ],
          ),
        ),
      ),
        // Overlay for AI Generation/Transcription (New Unified Style)
        if (_isGenerating || _isLoadingText || _isOneShotGenerating)
           Positioned.fill(
             child: ProcessingOverlay(
               cyclingMessages: _isOneShotGenerating
                 ? ['⚡ Listening to audio...', '⚡ Filling template...', '⚡ Structuring note...']
                 : _isGenerating 
                   ? _statusMessages 
                   : ['Transcribing Audio...', 'Analyzing Speech...', 'Extracting Text...'],
             ),
           ),
       ],
      ),
    );
  }

  Widget _buildSmartHeader(ThemeData theme) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            // 1. Back / Close
            IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () async {
                 await _saveDraftUpdate();
                 await _restoreWindow();
                 if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 16),

            // 2. Patient Info & Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.noteNumber > 0 
                        ? 'NO-${widget.noteNumber}'
                        : (widget.note.patientName.isNotEmpty
                            ? widget.note.patientName
                            : 'Unknown Patient'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.note.createdAt.toString().substring(0, 16),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(theme),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Window Controls
            IconButton(
              icon: Icon(Icons.close_fullscreen, color: Colors.grey[400], size: 20),
              onPressed: () async {
                 await _saveDraftUpdate();
                 await _restoreWindow(); 
                 if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Return to List',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
             const SizedBox(width: 16),
             IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
              onPressed: () async {
                await _inboxService.deleteNote(widget.note.id);
                await _restoreWindow();
                if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Delete Note',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // 4. Mark Ready (Moved to Header)
             IconButton(
              icon: Icon(Icons.check_circle_outline, color: Colors.green[300], size: 20),
              onPressed: _markAsReady,
              tooltip: 'Mark as Ready',
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
      Color color;
      String label;
      
      switch(widget.note.status) {
          case NoteStatus.ready:
            color = Colors.green;
            label = "READY";
            break;
          case NoteStatus.copied:
            color = Colors.blue;
            label = "COPIED";
            break;
          case NoteStatus.archived:
            color = Colors.grey;
            label = "ARCHIVED";
            break;
          case NoteStatus.processed:
          case NoteStatus.draft:
          default:
             color = Colors.orange;
             label = "DRAFT";
             break;
      }
      
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
              label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
      );
  }

  Widget _buildSmartTabsEditorCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        // Subtle shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TAB BAR UI ---
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.2))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Source Tab (Always present)
                _buildTab(
                  index: 0,
                  icon: Icons.mic_none,
                  label: "Source",
                  theme: theme,
                ),
                
                // Generated Output Tabs
                for (int i = 0; i < _generatedOutputs.length; i++)
                  _buildTab(
                    index: i + 1,
                    icon: Icons.auto_awesome,
                    label: _generatedOutputs[i].title ?? 'Output ${i + 1}',
                    theme: theme,
                    onDelete: () => _deleteTab(i + 1),
                  ),
              ],
            ),
          ),

          // --- EDITOR AREA ---
          Expanded(child: _buildWhitePaperEditor(theme)),
          
          // --- SUGGESTIONS (Only show if on a generated tab) ---
          if (_suggestions.isNotEmpty && _activeTabIndex > 0)
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.05),
                  border: Border(top: BorderSide(color: colorScheme.primary.withOpacity(0.2))),
               ),
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text("AI Missing Suggestions", style: TextStyle(
                            color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((s) => ActionChip(
                          label: Text('+ ${s.label}', style: const TextStyle(fontSize: 11)),
                          backgroundColor: colorScheme.surface,
                          side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                          onPressed: () => _insertSuggestion(s),
                      )).toList(),
                    ),
                  ],
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
    required ThemeData theme,
    VoidCallback? onDelete,
  }) {
    final bool isActive = _activeTabIndex == index;
    final colorScheme = theme.colorScheme;
    
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
            right: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(
               icon,
               size: 14,
               color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
             ),
             const SizedBox(width: 8),
             Text(
               label,
               style: TextStyle(
                 fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                 color: isActive ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
                 fontSize: 12,
               ),
             ),
             if (onDelete != null) ...[
               const SizedBox(width: 8),
               InkWell(
                 onTap: onDelete,
                 borderRadius: BorderRadius.circular(12),
                 child: Icon(Icons.close, size: 14, color: colorScheme.onSurface.withOpacity(0.4)),
               )
             ]
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelectorCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isTemplateCardExpanded
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outline.withOpacity(0.3),
          width: _isTemplateCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isTemplateCardExpanded
            ? [BoxShadow(color: colorScheme.primary.withOpacity(0.06), blurRadius: 10)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            onTap: () => setState(() => _isTemplateCardExpanded = !_isTemplateCardExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTemplateCardExpanded ? Icons.extension : Icons.extension_outlined,
                      key: ValueKey(_isTemplateCardExpanded),
                      color: _isTemplateCardExpanded
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.5),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Choose Template",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (!_isTemplateCardExpanded && _selectedMacro != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMacro!.trigger,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(
                    _isTemplateCardExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
          // Chips — only visible when expanded
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isTemplateCardExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Template Chips (existing backend path) ────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 7.0,
                      runSpacing: 7.0,
                      children: _quickMacros.map((macro) {
                        final isSelected = _selectedMacro?.id == macro.id;
                        return FilterChip(
                          label: Text(macro.trigger),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (selected) {
                              // In One-Shot mode: send audio+template to Gemini directly
                              // In classic mode: transcribe with backend STT first
                              if (_isLoadingText) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('يرجى الانتظار حتى يكتمل التفريغ الصوتي')),
                                );
                              } else {
                                // 2-Step Process: Always apply the template to the text!
                                _applyTemplate(macro);
                              }
                            }
                          },
                          backgroundColor: colorScheme.surface,
                          selectedColor: colorScheme.primary.withOpacity(0.15),
                          checkmarkColor: colorScheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline.withOpacity(0.4),
                            ),
                          ),
                          showCheckmark: true,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  // ✨ NEW: Clean Template Selection UI
  Widget _buildCleanTemplateScreen(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.surface, width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildSmartHeader(theme), // Includes back button
                Expanded(
                  child: Center(
                    // Slide up & fade in animation
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 50.0, end: 0.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Opacity(
                            opacity: (1.0 - (value / 50.0)).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 48, color: colorScheme.primary.withOpacity(0.8)),
                            const SizedBox(height: 16),
                            Text(
                              "How would you like to format this note?",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Choose a template to get started.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildCleanTemplateChips(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isGenerating || _isLoadingText)
            Positioned.fill(
              child: ProcessingOverlay(
                cyclingMessages: _statusMessages,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCleanTemplateChips(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.center,
      children: _quickMacros.map((macro) {
        return ActionChip(
          label: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(macro.trigger),
          ),
          onPressed: () {
             _applyTemplate(macro);
          },
          backgroundColor: colorScheme.surface,
          labelStyle: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outline.withOpacity(0.3),
            ),
          ),
          elevation: 1,
        );
      }).toList(),
    );
  }

  Widget _buildWhitePaperEditor(ThemeData theme) {
    // Note: Container styling moved to parent to allow toolbar integration
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _navigateToNextWord();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _navigateToPreviousWord();
          }
        }
      },
      child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(0), bottom: Radius.circular(0)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: _finalNoteController.text.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note,
                                    size: 64, color: Colors.white10),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a template to start',
                                  style: const TextStyle(
                                      color: Colors.white24, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                              controller: _finalNoteController,
                              maxLines: null,
                              expands: true,
                              onTap: _handleEditorTap,
                              onChanged: _onManualEdit,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.6,
                                fontFamily: 'Inter',
                              ),
                              decoration: const InputDecoration(
                                filled: false, 
                                border: InputBorder.none,
                                hintText: 'Type your note here...',
                                hintStyle: TextStyle(color: Colors.white24),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
              ),
            ],
          ),
        ),
    );
  }

  Future<void> _markAsReady() async {
    try {
      if (_finalNoteController.text.isEmpty) return;

      await _inboxService.updateNote(
        widget.note.id,
        formattedText: _finalNoteController.text,
      );
      // EXPLICITLY SET STATUS TO READY
      await _inboxService.updateStatus(widget.note.id, NoteStatus.ready);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Note saved and marked as Ready'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error marking as ready: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildActionDock(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark surface
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: Row(
        children: [
            // Unified Button
            Expanded(
                child: ElevatedButton(
                  onPressed: _finalNoteController.text.isEmpty ? null : _smartCopyAndInject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.input, size: 20),
                      SizedBox(width: 8),
                      Text("SMART COPY / INJECT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
            ),
        ],
      ),
    );
  }
}
