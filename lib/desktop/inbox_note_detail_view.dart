import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import '../models/smart_suggestion.dart';
import '../services/inbox_service.dart';
import '../services/api_service.dart';
import '../services/keyboard_service.dart';
import '../services/macro_service.dart';
import 'macro_explorer_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/window_manager_helper.dart';

import 'widgets/markdown_controller.dart';

class InboxNoteDetailView extends StatefulWidget {
  final NoteModel note;
  final Macro? autoStartMacro;
  final Stream<String>? pendingTextStream; // New: For instant open

  const InboxNoteDetailView(
      {super.key, required this.note, this.autoStartMacro, this.pendingTextStream});

  @override
  State<InboxNoteDetailView> createState() => _InboxNoteDetailViewState();
}

class _InboxNoteDetailViewState extends State<InboxNoteDetailView> {
  final _keyboard = KeyboardService();
  final _inboxService = InboxService();
  final _macroService = MacroService();

  final _finalNoteController = MarkdownSyntaxTextEditingController();
  Macro? _selectedMacro;
  bool _isGenerating = false;
  bool _isArchiveExpanded = false;
  bool _isTemplatesExpanded = false; // Controls macro list expansion
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
      _textStreamSubscription = widget.pendingTextStream!.listen((text) {
        if (mounted) {
            setState(() {
             _finalNoteController.text = text; // Update Field
             _isLoadingText = false; // Stop Loading
             
             // Update the "source" note model effectively so future operations use this text
             widget.note.rawText = text; // <-- CRITICAL FIX: Ensure UI reads from NoteModel
           });
        }
      }, onError: (e) {
         _showError("Transcription Failed: $e");
         setState(() => _isLoadingText = false);
      });
    }

    // 2. Initial Load from passed widget (Fast) - Only if not loading stream
    if (widget.note.formattedText.isNotEmpty && !_isLoadingText) {
      _finalNoteController.text = widget.note.formattedText;
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
      if (freshNote != null && freshNote.formattedText.isNotEmpty) {
        if (mounted && _finalNoteController.text.isEmpty) {
           setState(() {
             _finalNoteController.text = freshNote.formattedText;
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
      setState(() => _quickMacros = combinedMap.values.toList());
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
    // Restore to Mini-Bar / Pill dimensions (Floating Bar)
    if (mounted) {
       await WindowManagerHelper.collapseToPill(context);
    }
  }

  Future<void> _applyTemplate(Macro macro) async {
    setState(() {
      _isGenerating = true;
      _selectedMacro = macro;
      _elapsedSeconds = 0;
      _statusMessageIndex = 0;
      _isRawTextExpanded = false; // COLLAPSE RAW TEXT ON MACRO START
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
      final prefs = await SharedPreferences.getInstance();
      final specialty = prefs.getString('specialty') ?? 'General Practice';
      final globalPrompt = prefs.getString('global_ai_prompt') ?? '';
      final enableSuggestions =
          prefs.getBool('enable_smart_suggestions') ?? true;

      final apiService = ApiService();
      
      final response = await apiService.post('/audio/process', body: {
        'transcript': widget.note.rawText,
        'macro_context': macro.content,
        'specialty': specialty,
        'global_prompt': globalPrompt,
        'mode': enableSuggestions ? 'smart' : 'fast',
      });

      if (response['status'] == true) {
        final payload = response['payload'];
        if (enableSuggestions) {
          setState(() {
            _finalNoteController.text = payload['final_note'] ?? '';
            _suggestions = (payload['missing_suggestions'] as List?)
                    ?.map((s) =>
                        SmartSuggestion.fromJson(s as Map<String, dynamic>))
                    .toList() ??
                [];
          });
          _autoSaveGeneratedContent(payload['final_note'] ?? '', macro);
        } else {
          final formattedText = payload['text'] ?? '';
          setState(() {
            _finalNoteController.text = formattedText;
            _suggestions = [];
          });
          _autoSaveGeneratedContent(formattedText, macro);
        }
      } else {
        _showError("Failed to generate note: ${response['message']}");
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
          // We don't overwrite rawText here as it's the source
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

  Future<void> _injectToEMR() async {
    final text = _finalNoteController.text;
    if (text.isEmpty) {
      _showError("No content to inject");
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      await windowManager.hide();
      await Future.delayed(const Duration(milliseconds: 200));
      await _keyboard.pasteText(text);
      await Future.delayed(const Duration(milliseconds: 100));
      await _inboxService.archiveNote(widget.note.id);

      if (mounted) {
        Navigator.of(context).pop();
      }

      await windowManager.show();
    } catch (e) {
      _showError("Inject failed: $e");
      await windowManager.show();
    }
  }

  void _handleTextFieldTap() {
    final textPosition = _finalNoteController.selection.baseOffset;
    if (textPosition < 0) return;

    final text = _finalNoteController.text;
    if (text.isEmpty) return;

    int start = textPosition;
    int end = textPosition;

    while (start > 0 && !_isWordBoundary(text[start - 1])) {
      start--;
    }

    while (end < text.length && !_isWordBoundary(text[end])) {
      end++;
    }

    if (start < end && !text.substring(start, end).trim().isEmpty) {
      _finalNoteController.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );
    }
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
      body: MouseRegion(
        onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
        onExit: (_) => WindowManagerHelper.setOpacity(0.7),
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
              _buildHeader(theme),
              // 1. Raw Text / Safety Archive
              // Behavior:
              // - Initial: Takes 3/4 of space (Flex 3 vs 1 below)
              // - Processing: Takes fixed small height (~2 lines)
              if (_isRawTextExpanded)
                Expanded(
                  flex: 3,
                  child: _buildSafetyArchive(theme),
                )
              else
                 SizedBox(
                   height: 140, // Fixed height for "2 lines" look + padding
                   child: _buildSafetyArchive(theme),
                 ),

              // 2. Templates / Macros
              // Always visible in the middle
              _buildContextStrip(theme),

              // 3. AI Editor (White Paper)
              // Behavior:
              // - Initial: Takes 1/4 of space (Flex 1)
              // - Processing: Takes ALL remaining space (Expanded)
              Expanded(
                flex: _isRawTextExpanded ? 1 : 1,
                child: _buildWhitePaperEditor(theme),
              ),
              
              // 4. Footer Controls
              _buildBottomControlBar(theme),
              _buildInjectButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
              onPressed: () async {
                 await _restoreWindow();
                 if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Close',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.patientName.isNotEmpty
                        ? widget.note.patientName
                        : 'Unknown Patient',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${widget.note.createdAt.toString().substring(0, 16)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // Minimize / Return to Bar
            IconButton(
              icon: Icon(Icons.close_fullscreen, color: Colors.grey[400]),
              onPressed: () async {
                 // await windowManager.hide(); // REMOVED: Don't hide, just return to mini mode
                 await _restoreWindow(); // Reset size and position
                 if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Return to List',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () async {
                await _inboxService.deleteNote(widget.note.id);
                // We also restore window on delete
                await _restoreWindow();
                if (mounted) Navigator.of(context).pop();
              },
              tooltip: 'Delete Note',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyArchive(ThemeData theme) {
    final lines = widget.note.rawText.split('\n');
    final previewLines = lines.take(4).join('\n');
    final hasMore = lines.length > 4;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasMore
                ? () => setState(() => _isArchiveExpanded = !_isArchiveExpanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speaker_notes,
                          color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.note.patientName.isNotEmpty
                            ? widget.note.patientName
                            : 'Unknown Patient',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Direct Inject / Copy Raw Action
                      InkWell(
                        onTap: () {
                          setState(() {
                            _finalNoteController.text = widget.note.rawText;
                            _selectedMacro = null;
                            _suggestions = [];
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy_all,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "Use Raw Text",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (hasMore)
                        Icon(
                          _isArchiveExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // LOADING STATE for Instant Review
                  if (_isLoadingText) 
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          CircularProgressIndicator(color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text("Consulting Groq...", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    )
                  else 
                    // NORMAL TEXT CONTENT
                     SelectableText(
                      _isRawTextExpanded ? widget.note.rawText : previewLines,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                ],
              ),
            ),
          ),
          
            // Archive Expanion (Only show if NOT in expanded mode, effectively)
            if (_isArchiveExpanded && hasMore && !_isRawTextExpanded) // Logic tweaking
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 250),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SingleChildScrollView(
                  child: SelectableText(
                    lines.skip(4).join('\n'),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildContextStrip(ThemeData theme) {
    // Smart Count Strategy:
    // Collapsed: Show top 8 macros.
    // Expanded: Show top 30 macros (scrollable).

    final int collapsedCount = 8;
    final bool showMoreButton =
        !_isTemplatesExpanded && _quickMacros.length > collapsedCount;
    final List<Macro> displayedMacros = _isTemplatesExpanded
        ? _quickMacros
        : _quickMacros.take(collapsedCount).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      // Constraints:
      // Collapsed: ~86px (enough for 2 lines)
      // Expanded: ~250px (approx 6 lines, scrollable)
      constraints: BoxConstraints(
        maxHeight: _isTemplatesExpanded ? 250.0 : 86.0,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                  Flexible(
                    child: Text(
                      'TEMPLATES',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...displayedMacros.map((macro) {
                  final isSelected = _selectedMacro?.id == macro.id;
                  return InkWell(
                    onTap: () => _applyTemplate(macro),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.15)
                            : theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        macro.trigger,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),

                // "MORE" Button (Expands List)
                if (showMoreButton)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isTemplatesExpanded = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "More",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down,
                              size: 14, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),

                // "ALL MANAGERS" Button (Opens Manager - Only visible when expanded)
                if (_isTemplatesExpanded)
                  InkWell(
                    onTap: () async {
                      await WindowManagerHelper.centerDialog();
                      final macro = await showDialog<Macro>(
                        context: context,
                        builder: (context) => const MacroExplorerDialog(),
                      );
                      if (mounted) await WindowManagerHelper.expandToSidebar(context);
                      if (macro != null) _applyTemplate(macro);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "All Managers",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward,
                              size: 10, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: FutureBuilder<bool>(
        future: SharedPreferences.getInstance()
            .then((prefs) => prefs.getBool('enable_smart_suggestions') ?? true),
        builder: (context, snapshot) {
          final enableSuggestions = snapshot.data ?? true;
          return Row(
            children: [
              SizedBox(
                height: 24,
                child: Switch(
                  value: enableSuggestions,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('enable_smart_suggestions', value);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                enableSuggestions ? 'Smart Mode' : 'Fast Mode',
                style: TextStyle(
                  color: enableSuggestions
                      ? theme.colorScheme.primary
                      : Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: enableSuggestions
                    ? (_suggestions.isNotEmpty
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _suggestions.map((suggestion) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () => _insertSuggestion(suggestion),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add,
                                              size: 12,
                                              color: theme.colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            suggestion.label,
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        : Text(
                            'AI Suggestions...',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic),
                          ))
                    : Container(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWhitePaperEditor(ThemeData theme) {
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: _isGenerating
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // AI Processing Ring with continuous rotation
                            TweenAnimationBuilder<double>(
                              key: ValueKey(_isGenerating),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(seconds: 2),
                              onEnd: () {
                                // Restart animation when complete
                                if (_isGenerating && mounted) {
                                  setState(() {});
                                }
                              },
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: value * 2 * 3.14159,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.secondary,
                                          theme.colorScheme.primary,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          // Pulse effect for timer
                                          child: TweenAnimationBuilder<double>(
                                            key: ValueKey(_elapsedSeconds),
                                            tween: Tween(begin: 1.0, end: 1.2),
                                            duration: const Duration(
                                                milliseconds: 300),
                                            curve: Curves.easeOut,
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  '${_elapsedSeconds}s',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            // Rotating status message
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _statusMessages[_statusMessageIndex],
                                key: ValueKey(_statusMessageIndex),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _finalNoteController.text.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note,
                                    size: 64, color: Colors.grey[200]),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a template to start',
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _finalNoteController,
                            maxLines: null,
                            expands: true,
                            onTap: _handleTextFieldTap,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 16, // Increased from 14 to match Mobile standard
                              height: 1.6,   // Increased from 1.5 to 1.6 for better spacing
                              fontFamily: 'Inter',
                            ),
                            decoration: const InputDecoration(
                              filled: false, // Ensure transparent background
                              border: InputBorder.none,
                              hintText: 'Type your note here...',
                              hintStyle: TextStyle(color: Colors.black26),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
              ),
            ],
          ),
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
        // Status implicitly set to 'processed' by backend logic when formattedText is present
      );

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

  Widget _buildInjectButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          // 1. Mark Ready Button (Flexible)
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _finalNoteController.text.isEmpty ? null : _markAsReady,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                side: BorderSide(color: theme.colorScheme.secondary),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8), // Reduce padding
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Shrink to fit
                children: [
                  Icon(Icons.save_outlined, size: 18),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Mark Ready',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. Inject Button (Flexible)
          Expanded(
            child: ElevatedButton(
              onPressed:
                  _finalNoteController.text.isEmpty ? null : _injectToEMR,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                elevation: 4,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8), // Reduce padding
                shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Shrink to fit
                children: [
                  Icon(Icons.check_circle_outline, size: 18),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Inject & Archive',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
