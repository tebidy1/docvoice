import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import '../models/smart_suggestion.dart';
import '../services/inbox_service.dart';
import '../services/gemini_service.dart';
import '../services/keyboard_service.dart';
import '../services/macro_service.dart';
import 'macro_explorer_dialog.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/window_manager_helper.dart';

class InboxNoteDetailView extends StatefulWidget {
  final InboxNote note;
  final Macro? autoStartMacro;

  const InboxNoteDetailView({super.key, required this.note, this.autoStartMacro});

  @override
  State<InboxNoteDetailView> createState() => _InboxNoteDetailViewState();
}

class _InboxNoteDetailViewState extends State<InboxNoteDetailView> {
  final _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
  final _keyboard = KeyboardService();
  final _inboxService = InboxService();
  final _macroService = MacroService();
  
  final _finalNoteController = TextEditingController();
  Macro? _selectedMacro;
  bool _isGenerating = false;
  bool _isArchiveExpanded = false;
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

  @override
  void initState() {
    super.initState();
    _dockWindow();
    _loadQuickMacros();
    
    if (widget.autoStartMacro != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyTemplate(widget.autoStartMacro!);
      });
    }
  }

  Future<void> _loadQuickMacros() async {
    await _macroService.init();
    var macros = await _macroService.getMostUsed(limit: 12);
    
    if (macros.isEmpty) {
      final allMacros = await _macroService.getAllMacros();
      macros = allMacros.take(12).toList();
    }
    
    if (mounted) {
      setState(() => _quickMacros = macros);
    }
  }

  @override
  void dispose() {
    _generationTimer?.cancel();
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
    // Optional: restore to some default state if needed
  }

  Future<void> _applyTemplate(Macro macro) async {
    setState(() {
      _isGenerating = true;
      _selectedMacro = macro;
      _elapsedSeconds = 0;
      _statusMessageIndex = 0;
    });
    
    // Start timer for AI Processing Ring
    _generationTimer?.cancel();
    _generationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
          _statusMessageIndex = (_statusMessageIndex + 1) % _statusMessages.length;
        });
      }
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final specialty = prefs.getString('specialty') ?? 'General Practice';
      final globalPrompt = prefs.getString('global_ai_prompt') ?? '';
      final enableSuggestions = prefs.getBool('enable_smart_suggestions') ?? true;
      
      print("DetailView: Generating... (Suggestions: $enableSuggestions)");
      
      if (enableSuggestions) {
        final response = await _geminiService.formatTextWithSuggestions(
          widget.note.rawText,
          macroContext: macro.content,
          specialty: specialty,
          globalPrompt: globalPrompt,
        );
        
        if (response != null) {
          setState(() {
            _finalNoteController.text = response['final_note'] ?? '';
            _suggestions = (response['missing_suggestions'] as List?)
                ?.map((s) => SmartSuggestion.fromJson(s as Map<String, dynamic>))
                .toList() ?? [];
          });
          print("DetailView: Loaded ${_suggestions.length} suggestions");
        } else {
          _showError("Failed to generate note");
        }
      } else {
        final formattedText = await _geminiService.formatText(
          widget.note.rawText,
          macroContext: macro.content,
          specialty: specialty,
          globalPrompt: globalPrompt,
        );
        
        setState(() {
          _finalNoteController.text = formattedText;
          _suggestions = [];
        });
        print("DetailView: Fast generation complete");
      }
    } catch (e) {
      print("DetailView: Error: $e");
      _showError("Generation failed: $e");
    } finally {
      _generationTimer?.cancel();
      setState(() => _isGenerating = false);
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
        _finalNoteController.selection = const TextSelection.collapsed(offset: 0);
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
              _buildSafetyArchive(theme),
              _buildContextStrip(theme),
              Expanded(child: _buildWhitePaperEditor(theme)),
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
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.patientName ?? 'Unknown Patient',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${widget.note.createdAt?.toString().substring(0, 16) ?? ""}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () async {
                await _inboxService.deleteNote(widget.note.id);
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
            onTap: hasMore ? () => setState(() => _isArchiveExpanded = !_isArchiveExpanded) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speaker_notes, color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Reference Transcript',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (hasMore)
                        Icon(
                          _isArchiveExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    previewLines,
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
          if (_isArchiveExpanded && hasMore)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                lines.skip(4).join('\n'),
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContextStrip(ThemeData theme) {
    // ديناميكية الارتفاع: 3 أسطر (120px) بدون اختيار، سطر واحد (40px) بعد الاختيار
    final stripHeight = _selectedMacro == null ? 120.0 : 40.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: stripHeight,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedMacro != null) ...[
                Icon(Icons.flash_on, color: theme.colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _selectedMacro!.trigger,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else
                Text(
                  'TEMPLATES',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  // Expand window for the dialog
                  await WindowManagerHelper.centerDialog();
                  
                  final macro = await showDialog<Macro>(
                    context: context,
                    builder: (context) => const MacroExplorerDialog(),
                  );
                  
                  // Restore sidebar layout
                  if (mounted) {
                    await WindowManagerHelper.expandToSidebar(context);
                  }

                  if (macro != null) {
                    _applyTemplate(macro);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'MORE',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedMacro == null
                ? SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickMacros.map((macro) {
                        return InkWell(
                          onTap: () => _applyTemplate(macro),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              macro.trigger,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickMacros.map((macro) {
                        final isSelected = _selectedMacro?.id == macro.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => _applyTemplate(macro),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? theme.colorScheme.primary.withOpacity(0.15) 
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? theme.colorScheme.primary.withOpacity(0.5) 
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                macro.trigger,
                                style: TextStyle(
                                  color: isSelected ? theme.colorScheme.primary : Colors.grey[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: FutureBuilder<bool>(
        future: SharedPreferences.getInstance().then((prefs) => 
          prefs.getBool('enable_smart_suggestions') ?? true
        ),
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
                  color: enableSuggestions ? theme.colorScheme.primary : Colors.grey[500],
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.add, size: 12, color: theme.colorScheme.primary),
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
                            style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic),
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
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: Text(
                                                  '${_elapsedSeconds}s',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.primary,
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
                                Icon(Icons.edit_note, size: 64, color: Colors.grey[200]),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a template to start',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                              fontSize: 14,
                              height: 1.5,
                              fontFamily: 'Inter',
                            ),
                            decoration: const InputDecoration(
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

  Widget _buildInjectButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: ElevatedButton(
        onPressed: _finalNoteController.text.isEmpty ? null : _injectToEMR,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 20),
            SizedBox(width: 8),
            Text('Inject & Archive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
