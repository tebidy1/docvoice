import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/entities/inbox_note.dart';
import '../../core/entities/macro.dart';
import '../../core/entities/smart_suggestion.dart';
import '../../data/repositories/inbox_service.dart';
import '../../data/repositories/keyboard_service.dart';
import '../../data/repositories/macro_service.dart';
import 'macro_explorer_dialog.dart';
import '../utils/window_manager_helper.dart';
import '../../widgets/processing_overlay.dart';
import '../../widgets/pattern_highlight_controller.dart';
// ✅ Core AI Brain — centralized services (Phase 1 refactor)
import '../../core/ai/ai_regex_patterns.dart';
import '../../core/ai/text_processing_service.dart';
import '../../data/repositories/ai/ai_processing_service.dart';
import '../../data/repositories/windows_injector.dart';

class InboxNoteDetailView extends StatefulWidget {
  final NoteModel note;
  final Macro? autoStartMacro;
  final Stream<String>? pendingTextStream; // New: For instant open
  final int noteNumber; // 1-based, oldest = 1

  const InboxNoteDetailView(
      {super.key,
      required this.note,
      this.autoStartMacro,
      this.pendingTextStream,
      this.noteNumber = 0});

  @override
  State<InboxNoteDetailView> createState() => _InboxNoteDetailViewState();
}

class _InboxNoteDetailViewState extends State<InboxNoteDetailView> {
  final _keyboard = KeyboardService();
  final _inboxService = InboxService();
  final _macroService = MacroService();

  final _finalNoteController = PatternHighlightController(
    text: "",
    patternStyles: {
      // ✅ Using centralized AIRegexPatterns (Phase 1 refactor)
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
  Macro? _selectedMacro;
  bool _isGenerating = false;
  bool _isTemplateCardExpanded =
      true; // Accordion: template card expanded by default
  bool _isGeneratedCardExpanded =
      false; // Accordion: generated card collapsed by default
  List<SmartSuggestion> _suggestions = [];
  List<Macro> _quickMacros = [];

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
  bool _isRawTextExpanded = true;
  StreamSubscription? _textStreamSubscription;

  @override
  void initState() {
    super.initState();
    _dockWindow();
    _loadQuickMacros();

    // 1. Setup Stream (If Instant Open)
    if (widget.pendingTextStream != null) {
      _isLoadingText = true;

      // Start the same animation timer as AI generation
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

      _textStreamSubscription = widget.pendingTextStream!.listen((text) {
        if (mounted) {
          setState(() {
            _isLoadingText = false; // Stop Loading
            _generationTimer?.cancel(); // Stop animation

            // Update the "source" note model effectively so future operations use this text
            widget.note.rawText =
                text; // <-- CRITICAL FIX: Ensure UI reads from NoteModel
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
    if (widget.note.formattedText.isNotEmpty && !_isLoadingText) {
      _finalNoteController.text = widget.note.formattedText;
      _isTemplateCardExpanded = false;
      _isGeneratedCardExpanded = true;
    } else {
      _isTemplateCardExpanded = true;
      _isGeneratedCardExpanded = false;
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
            if (_finalNoteController.text.isEmpty &&
                freshNote.formattedText.isNotEmpty) {
              _finalNoteController.text = freshNote.formattedText;
              _isTemplateCardExpanded = false;
              _isGeneratedCardExpanded = true;
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
                  final exact = all
                      .where((m) => m.id == freshNote.appliedMacroId)
                      .firstOrNull;
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

    // Strategy: Favorites FIRST, then Most Used
    final favorites = await _macroService.getFavorites();
    var mostUsed = await _macroService.getMostUsed(limit: 30);

    // Fallback if most used is empty (e.g. fresh install)
    if (mostUsed.isEmpty && favorites.isEmpty) {
      final allMacros = await _macroService.getAllMacros();
      mostUsed = allMacros.take(30).toList();
    }

    // Deduplicate and Order
    final Map<int, Macro> combinedMap = {};

    // 1. Add Favorites (highest priority)
    for (var m in favorites) {
      combinedMap[m.id] = m;
    }

    // 2. Add Most Used (if not already added)
    for (var m in mostUsed) {
      if (!combinedMap.containsKey(m.id)) {
        combinedMap[m.id] = m;
      }
    }

    if (mounted) {
      final macroList = combinedMap.values.toList();

      // Restore selected macro and move to front
      Macro? restoredMacro;
      if (_selectedMacro == null && widget.note.appliedMacroId != null) {
        if (combinedMap.containsKey(widget.note.appliedMacroId)) {
          restoredMacro = combinedMap[widget.note.appliedMacroId];
          if (restoredMacro != null) {
            macroList.remove(restoredMacro);
            macroList.insert(0, restoredMacro);
          }
        }
      }

      setState(() {
        _quickMacros = macroList;
        if (restoredMacro != null) _selectedMacro = restoredMacro;
      });
    }
  }

  @override
  void dispose() {
    _generationTimer?.cancel();
    _textStreamSubscription?.cancel(); // Clean up stream
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
      _isRawTextExpanded = false; // COLLAPSE RAW TEXT ON MACRO START
      _isTemplateCardExpanded = false; // Collapse template accordion
      _isGeneratedCardExpanded = true; // Expand generated note accordion
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

    try {
      // ✅ Use centralized AIProcessingService (Phase 1 refactor)
      final aiService = AIProcessingService();
      final enableSuggestions =
          await AIProcessingService.isSmartSuggestionsEnabled();

      final result = await aiService.processNote(
        transcript: widget.note.rawText,
        macroContent: macro.content,
        mode:
            enableSuggestions ? AIProcessingMode.smart : AIProcessingMode.fast,
      );

      if (result.success) {
        if (enableSuggestions) {
          setState(() {
            _finalNoteController.text = result.formattedNote;
            _suggestions = result.missingSuggestions
                .map((s) => SmartSuggestion.fromJson(s))
                .toList();
          });
          _autoSaveGeneratedContent(result.formattedNote, macro);
        } else {
          setState(() {
            _finalNoteController.text = result.formattedNote;
            _suggestions = [];
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

  Future<void> _autoSaveGeneratedContent(String content, Macro macro) async {
    try {
      await _inboxService.updateNote(
        widget.note.id,
        formattedText: content,
        summary: macro.trigger, // Store template name for badge display
        suggestedMacroId: macro.id,
      );

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
    // ✅ Use TextProcessingService.applySmartCopy (Phase 1 refactor)
    // FIXED: Removes placeholder tokens inline, NOT entire lines
    return TextProcessingService.applySmartCopy(_finalNoteController.text);
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
          const SnackBar(
              content: Text("✅ Copied & Injected into EMR"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError("Inject failed: $e");
    }
  }

  void _handleEditorTap() {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          MouseRegion(
            onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
            onExit: (_) =>
                WindowManagerHelper.setOpacity(0.95), // Less transparent
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

                  // 1. Source Text Accordion
                  _buildSourceAccordion(theme),

                  const SizedBox(height: 8),

                  // 2. Template Selector Accordion Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTemplateSelectorCard(theme),
                  ),

                  const SizedBox(height: 8),

                  // 3. Generated Note Accordion Card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: _buildGeneratedNoteCard(theme),
                    ),
                  ),

                  // 4. Action Dock
                  _buildActionDock(theme),
                ],
              ),
            ),
          ),
          // Overlay for AI Generation/Transcription (New Unified Style)
          if (_isGenerating || _isLoadingText)
            Positioned.fill(
              child: ProcessingOverlay(
                cyclingMessages: _isGenerating
                    ? _statusMessages
                    : [
                        'Transcribing Audio...',
                        'Analyzing Speech...',
                        'Extracting Text...'
                      ],
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
                        '${widget.note.createdAt.toString().substring(0, 16)}',
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
              icon: Icon(Icons.close_fullscreen,
                  color: Colors.grey[400], size: 20),
              onPressed: () async {
                await _restoreWindow();
                if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Return to List',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon:
                  Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
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
              icon: Icon(Icons.check_circle_outline,
                  color: Colors.green[300], size: 20),
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

    switch (widget.note.status) {
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
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSourceAccordion(ThemeData theme) {
    // Logic: Hidden if we have formatted text, unless explicitly expanded
    // But we reuse _isRawTextExpanded state variable differently now.
    // Let's invert the variable logic or just use it as "Is Source Visible".
    // Default: If formattedText exists, _isRawTextExpanded should be FALSE.

    final lines = widget.note.rawText.split('\n');
    final preview = lines.take(1).join(' ') + (lines.length > 1 ? '...' : '');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // Header / Toggle
          InkWell(
            onTap: () =>
                setState(() => _isRawTextExpanded = !_isRawTextExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.mic_none, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text("Source Text",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: !_isRawTextExpanded
                          ? Text(
                              preview,
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            )
                          : const SizedBox.shrink()),
                  if (_isRawTextExpanded)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.note.rawText));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Raw Text Copied!"),
                                duration: Duration(seconds: 1)));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.copy,
                            size: 14, color: theme.colorScheme.primary),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                      _isRawTextExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey[600]),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isRawTextExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              constraints:
                  const BoxConstraints(maxHeight: 150), // Limited height
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.note.rawText,
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 13, height: 1.4),
                ),
              ),
            ),
        ],
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
            ? [
                BoxShadow(
                    color: colorScheme.primary.withOpacity(0.06),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            onTap: () => setState(
                () => _isTemplateCardExpanded = !_isTemplateCardExpanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                    _isTemplateCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
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
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                        if (selected) _applyTemplate(macro);
                      },
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.primary.withOpacity(0.15),
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedNoteCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final hasContent = _finalNoteController.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isGeneratedCardExpanded
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outline.withOpacity(0.2),
          width: _isGeneratedCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isGeneratedCardExpanded
            ? [
                BoxShadow(
                    color: colorScheme.primary.withOpacity(0.06),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — always visible
          InkWell(
            onTap: hasContent
                ? () => setState(
                    () => _isGeneratedCardExpanded = !_isGeneratedCardExpanded)
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                          : colorScheme.onSurface.withOpacity(0.4),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Generated Note",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!hasContent && !_isGenerating)
                    Text(
                      "Select a template above",
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (_isGenerating)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: colorScheme.primary),
                    ),
                  if (!_isGenerating)
                    Icon(
                      _isGeneratedCardExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                ],
              ),
            ),
          ),
          // Content — only visible when expanded
          if (_isGeneratedCardExpanded)
            Expanded(child: _buildWhitePaperEditor(theme)),
        ],
      ),
    );
  }

  Widget _buildWhitePaperEditor(ThemeData theme) {
    // Note: Container styling moved to parent to allow toolbar integration
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _navigateToNextWord();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _navigateToPreviousWord();
          }
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(0), bottom: Radius.circular(0)),
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
                            style:
                                TextStyle(color: Colors.white24, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _finalNoteController,
                      maxLines: null,
                      expands: true,
                      onTap: _handleEditorTap,
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
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ]),
      child: Row(
        children: [
          // Unified Button
          Expanded(
            child: ElevatedButton(
              onPressed: _finalNoteController.text.isEmpty
                  ? null
                  : _smartCopyAndInject,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.input, size: 20),
                  SizedBox(width: 8),
                  Text("SMART COPY / INJECT",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
