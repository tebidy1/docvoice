// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// Models & Services
import '../../mobile_app/core/entities/note_model.dart';
import '../../mobile_app/data/repositories/macro_service.dart'; 
import '../../mobile_app/data/repositories/inbox_service.dart';
import '../../mobile_app/data/repositories/groq_service.dart';
import '../../data/repositories/api_service.dart';
import '../../presentation/widgets/pattern_highlight_controller.dart'; 
import '../../presentation/widgets/processing_overlay.dart';
import '../../core/ai/ai_regex_patterns.dart';
import '../../core/ai/text_processing_service.dart';
import '../../data/repositories/ai/ai_processing_service.dart';
import '../data/repositories/extension_injection_service.dart';

class ExtensionEditorScreen extends StatefulWidget {
  final NoteModel draftNote;
  final int noteNumber;

  const ExtensionEditorScreen({super.key, required this.draftNote, this.noteNumber = 0});

  @override
  State<ExtensionEditorScreen> createState() => _ExtensionEditorScreenState();
}

class _ExtensionEditorScreenState extends State<ExtensionEditorScreen> {
  // Services
  final _inboxService = InboxService();
  final _macroService = MacroService();

  // Controllers
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
  // We need a separate controller/string for Source because Desktop uses widget.note.rawText
  // but here we might update it dynamically from Audio.
  String _rawText = ""; 
  
  // State
  List<MacroModel> _quickMacros = []; // Mobile service returns MacroModel
  MacroModel? _selectedMacro;
  bool _isGenerating = false;
  bool _isRawTextExpanded = false; // Collapsed by default
  bool _isLoading = true; // For audio processing
  bool _isTemplateCardExpanded = true;  // Template card: expanded by default
  bool _isGeneratedCardExpanded = false; // Generated note card: collapsed by default

  // AI Processing Animation
  final List<String> _statusMessages = [
    'Processing Note...',
    'Consulting AI...',
    'Structuring Note...',
  ];

  @override
  void initState() {
    super.initState();
    _rawText = widget.draftNote.originalText;
    if (_rawText.isEmpty) _rawText = widget.draftNote.content;
    if (widget.draftNote.formattedText.isNotEmpty) {
      _finalNoteController.text = widget.draftNote.formattedText;
      _isTemplateCardExpanded = false;
      _isGeneratedCardExpanded = true;
    } else {
      _isTemplateCardExpanded = true;
      _isGeneratedCardExpanded = false;
    }
    
    _loadMacros();
    
    // Start Audio Processing if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processAudioIfNeeded();
    });
  }

  @override
  void dispose() {
    // _generationTimer?.cancel(); // Removed
    _finalNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadMacros() async {
    // Reuse Mobile Macro Service
    // It returns List<MacroModel>
    final macros = await _macroService.getMacros();
    // Sort: Favorites first
    macros.sort((a, b) {
       if (a.isFavorite && !b.isFavorite) return -1;
       if (!a.isFavorite && b.isFavorite) return 1;
       return a.trigger.compareTo(b.trigger);
    });
    
    if (mounted) {
      // Restore selected macro
      MacroModel? restoredMacro;
      if (_selectedMacro == null) {
          if (widget.draftNote.appliedMacroId != null) {
              try {
                  restoredMacro = macros.firstWhere((m) => m.id == widget.draftNote.appliedMacroId);
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
     if (path != null && _rawText.isEmpty) { // Only process if we don't have text yet
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
        
        bool transcribed = false;

        // 1. Try Direct Groq (if key exists AND user selected Groq)
        if (sttEngine == 'groq' && localGroqKey != null && localGroqKey.isNotEmpty) {
           print("DEBUG: Using Local Groq Key (Direct Mode)");
           final groqService = GroqService(apiKey: localGroqKey);
           final transcript = await groqService.transcribe(bytes, filename: 'recording.webm');
           
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
                       _rawText = transcript.trim();
                       _isLoading = false;
                       _isRawTextExpanded = _finalNoteController.text.isEmpty; 
                   });
                   _saveDraft();
               }
               transcribed = true;
           }
        }

        // 2. Use Backend Proxy (for Oracle, Native, or if Direct Groq failed/unselected)
        if (!transcribed) {
            final apiService = ApiService();
            await apiService.init(); 
            print("DEBUG: Transcribing via Backend ($sttEngine)... Token present: ${apiService.hasToken}"); 
            
            final result = await apiService.multipartPost(
              '/audio/transcribe',
              fileBytes: bytes,
              filename: 'recording.webm',
            );

            if (result['status'] == true) {
               final transcript = result['payload']['text'] ?? "";
               if (mounted) {
                   setState(() {
                       _rawText = transcript.trim();
                       _isLoading = false;
                       _isRawTextExpanded = _finalNoteController.text.isEmpty; 
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
                  _rawText = "Transcription Failed";
                  _isLoading = false;
              });
          }
      }
  }

  Future<void> _saveDraft() async {
      try {
          if (widget.draftNote.id > 0) {
              await _inboxService.updateNote(
                  widget.draftNote.id,
                  rawText: _rawText,
                  formattedText: _finalNoteController.text,
                  summary: _selectedMacro?.trigger,
                  suggestedMacroId: _selectedMacro?.id is int ? _selectedMacro?.id as int : null,
              );
          } else {
              // Create new if generic ID
              // Note: ExtensionHomeScreen passing a 'draft' with generic UUID.
              // We should probably rely on backend ID if possible.
              // For now, let's use addNote if we don't have a real ID.
              final newId = await _inboxService.addNote(
                  _rawText,
                  formattedText: _finalNoteController.text,
                  patientName: widget.draftNote.title,
                  summary: _selectedMacro?.trigger,
                  suggestedMacroId: _selectedMacro?.id is int ? _selectedMacro?.id as int : null,
              );
              // Update local model
               widget.draftNote.id = newId;
          }
      } catch (e) {
          print("Auto-save failed: $e");
      }
  }

  Future<void> _applyTemplate(MacroModel macro) async {
       setState(() {
          _isGenerating = true;
          _selectedMacro = macro;
          _isRawTextExpanded = false;
          // Set state for AI loading and card expansion
          _isTemplateCardExpanded = false; // Collapse template
          _isGeneratedCardExpanded = true; // Expand final note
       });
       
       
       // Animation Timer - Removed, handled by ProcessingOverlay.dart

       try {
           final prefs = await SharedPreferences.getInstance();
           // Save selected template ID for UI restoration
           await prefs.setInt('last_selected_macro_id', macro.id);
           
           // ✅ Use centralized AIProcessingService (Phase 1 refactor)
           final globalPrompt = await AIProcessingService.getEffectivePrompt();
           final specialty = await AIProcessingService.getEffectiveSpecialty();
           final enableSuggestions = await AIProcessingService.isSmartSuggestionsEnabled();
           
           final aiService = AIProcessingService();
           final result = await aiService.processNote(
               transcript: _rawText,
               macroContent: macro.content,
               mode: enableSuggestions ? AIProcessingMode.smart : AIProcessingMode.fast,
               specialty: specialty,
               globalPromptOverride: globalPrompt,
           );

           if (result.success) {
               final finalText = result.formattedNote;
               if (finalText.isEmpty) {
                   _showError("AI returned empty result. Please check API Key or try again.");
               }
               if (mounted) {
                   setState(() { _finalNoteController.text = finalText; });
                   _saveDraft();
               }
           } else {
               _showError("Generation failed: ${result.errorMessage}");
           }
       } catch (e) {
           _showError("AI Error: $e");
       } finally {
            // _generationTimer?.cancel(); // Removed
            if(mounted) setState(() => _isGenerating = false);
        }
  }


  Future<void> _smartCopyAndInject() async {
      final rawText = _finalNoteController.text;
      
      final result = await ExtensionInjectionService.smartCopyAndInject(rawText);

      if (result.status == InjectionStatus.failed) {
          _showError(result.message);
          return;
      }

      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.message),
              backgroundColor: result.status == InjectionStatus.success ? Colors.green : Colors.blue,
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
  }

  // --- UI BUILDERS (Adapted for Extension Dark Theme) ---

  // --- UI BUILDERS (New Card Layout) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark gray background
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                 // Scrollable Content
                 Expanded(
                   child: SingleChildScrollView(
                     padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Add bottom padding for FAB
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                          // Header / Title Row
                          Row(
                            children: [
                                 IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                                Text(widget.noteNumber > 0 ? "NO-${widget.noteNumber}" : "Draft Note", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                _buildStatusBadge(),
                                const Spacer(),
                                // Use Raw Text Button moved to Header
                                InkWell(
                                    onTap: () {
                                        Clipboard.setData(ClipboardData(text: _rawText));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied raw text"), duration: Duration(seconds: 1)));
                                    },
                                    child: const Text("Use Raw Text", style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          _buildOriginalNoteCard(),
                          const SizedBox(height: 16),
                          _buildTemplateSelectorCard(),
                          const SizedBox(height: 16),
                          _buildGeneratedNoteCard(),
                       ],
                     ),
                   ),
                 ),
              ],
            ),
            
            // Overlay for Initial Transcription
            if (_isLoading)
               const Positioned.fill(child: ProcessingOverlay()),

            // Overlay for AI Generation
            if (_isGenerating)
               Positioned.fill(
                 child: ProcessingOverlay(
                   cyclingMessages: _statusMessages,
                 ),
               ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _smartCopyAndInject,
        icon: const Icon(Icons.input),
        label: const Text("SMART COPY / INJECT"),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
  
  Widget _buildStatusBadge() {
       // Check if "Ready"
       bool isReady = _finalNoteController.text.isNotEmpty;
       String text = isReady ? "READY" : "DRAFT";
       Color color = isReady ? AppTheme.success : Colors.orange;

       return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
  }

  Widget _buildOriginalNoteCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => setState(() => _isRawTextExpanded = !_isRawTextExpanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
               _rawText.isEmpty ? "No source text available." : _rawText,
               maxLines: _isRawTextExpanded ? null : 2, // Changed to 2 lines
               overflow: _isRawTextExpanded ? null : TextOverflow.ellipsis,
               style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
             ),
             if (_rawText.isNotEmpty) ...[
                 const SizedBox(height: 4), // Reduced spacing
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(_isRawTextExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.white38),
                   ],
                 )
             ]
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelectorCard() {

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTemplateCardExpanded
              ? AppTheme.accent.withValues(alpha: 0.5)
              : const Color(0xFF2A2A2A),
          width: _isTemplateCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isTemplateCardExpanded ? [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible, tappable to toggle ──
          InkWell(
            onTap: () => setState(() => _isTemplateCardExpanded = !_isTemplateCardExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isTemplateCardExpanded ? Icons.extension : Icons.extension_outlined,
                      key: ValueKey(_isTemplateCardExpanded),
                      color: _isTemplateCardExpanded
                          ? AppTheme.accent
                          : Colors.white54,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Choose Template",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  if (!_isTemplateCardExpanded && _selectedMacro != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMacro!.trigger,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else const Spacer(),
                  Icon(
                    _isTemplateCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white38,
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
                        if (selected) _applyTemplate(macro);
                      },
                      backgroundColor: const Color(0xFF2A2A2A),
                      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? AppTheme.accent : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontFamily: 'Inter',
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.accent : Colors.transparent,
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
    final hasContent = _finalNoteController.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isGeneratedCardExpanded
              ? AppTheme.accent.withValues(alpha: 0.5)
              : const Color(0xFF2A2A2A),
          width: _isGeneratedCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isGeneratedCardExpanded ? [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          )
        ] : [],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible, tappable to toggle ──
          InkWell(
            onTap: hasContent
                ? () => setState(() => _isGeneratedCardExpanded = !_isGeneratedCardExpanded)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _isGeneratedCardExpanded ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                      key: ValueKey(_isGeneratedCardExpanded),
                      color: _isGeneratedCardExpanded ? AppTheme.accent : Colors.white38,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Generated Note",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const Spacer(),
                  if (hasContent)
                    Icon(
                      _isGeneratedCardExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.white38,
                    )
                  else
                    const Text(
                      "Select a template above",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white24,
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
            firstChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _isGenerating
                  ? const SizedBox(height: 60)
                  : TextField(
                      controller: _finalNoteController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.6),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(bottom: 16),
                        hintText: "AI generated note will appear here...",
                        hintStyle: TextStyle(color: Colors.white24),
                        fillColor: Colors.transparent,
                        filled: true,
                      ),
                      onTap: _handleEditorTap,
                    ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }


}


