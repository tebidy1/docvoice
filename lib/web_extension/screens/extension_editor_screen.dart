import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
// Models & Services
import '../../mobile_app/models/note_model.dart';
import '../../mobile_app/services/macro_service.dart'; 
import '../../mobile_app/services/inbox_service.dart';
import '../../mobile_app/services/groq_service.dart';
import '../../services/api_service.dart';
import '../../widgets/pattern_highlight_controller.dart'; 
import '../../widgets/processing_overlay.dart';
import '../../desktop/macro_explorer_dialog.dart'; 
import '../../models/macro.dart' as DesktopMacro;
// ✅ Core AI Brain — centralized services (Phase 1 refactor)
import '../../core/ai/ai_regex_patterns.dart';
import '../../core/ai/text_processing_service.dart';
import '../../services/ai/ai_processing_service.dart';

class ExtensionEditorScreen extends StatefulWidget {
  final NoteModel draftNote;

  const ExtensionEditorScreen({super.key, required this.draftNote});

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

  // AI Processing Animation
  final List<String> _statusMessages = [
    'Processing Note...',
    'Consulting AI...',
    'Structuring Note...',
  ];

  @override
  void initState() {
    super.initState();
    _rawText = widget.draftNote.originalText ?? widget.draftNote.content ?? "";
    if (widget.draftNote.formattedText.isNotEmpty) {
      _finalNoteController.text = widget.draftNote.formattedText;
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
      setState(() => _quickMacros = macros);
      
      // Restore last selected macro if none selected
      if (_selectedMacro == null) {
          final prefs = await SharedPreferences.getInstance();
          final lastId = prefs.getInt('last_selected_macro_id');
          if (lastId != null) {
              try {
                  final lastMacro = macros.firstWhere((m) => m.id == lastId);
                  setState(() => _selectedMacro = lastMacro);
              } catch (_) {
                  // Macro might have been deleted or not found
              }
          }
      }
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
        
        // 1. Try Direct Groq (if key exists locally)
        if (localGroqKey != null && localGroqKey.isNotEmpty) {
           print("DEBUG: Using Local Groq Key (Direct Mode)");
           final groqService = GroqService(apiKey: localGroqKey);
           final transcript = await groqService.transcribe(bytes, filename: 'recording.webm');
           
           if (transcript.startsWith("Error:")) {
               // Fallback if direct fails? Or just throw?
               // Let's log it and try backend as backup or throw.
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
               return; // Exit, handled by Groq
           }
        }

        // 2. Fallback to Backend Proxy
        final apiService = ApiService();
        await apiService.init(); 
        print("DEBUG: Transcribing via Backend... Token present: ${apiService.hasToken}"); 
        
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
      } catch (e) {
          _showError("Transcription failed: $e");
          setState(() {
              _rawText = "Transcription Failed";
              _isLoading = false;
          });
      }
  }

  Future<void> _saveDraft() async {
      try {
          if (widget.draftNote.id > 0) {
              await _inboxService.updateNote(
                  widget.draftNote.id,
                  rawText: _rawText,
                  formattedText: _finalNoteController.text,
              );
          } else {
              // Create new if generic ID
              // Note: ExtensionHomeScreen passing a 'draft' with generic UUID.
              // We should probably rely on backend ID if possible.
              // For now, let's use addNote if we don't have a real ID.
              final newId = await _inboxService.addNote(
                  _rawText,
                  formattedText: _finalNoteController.text,
                  patientName: widget.draftNote.title ?? "Extension Note",
              );
              // Update local model
               if (newId != null) widget.draftNote.id = newId;
          }
      } catch (e) {
          print("Auto-save failed: $e");
      }
  }

  Future<void> _applyTemplate(MacroModel macro) async {
       setState(() {
          _isGenerating = true;
          _selectedMacro = macro;
          // _elapsedSeconds = 0; // Removed
          // _statusMessageIndex = 0; // Removed
          _isRawTextExpanded = false; 
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

  String _getCleanText() {
    // ✅ Use TextProcessingService.applySmartCopy (Phase 1 refactor)
    // FIXED: Removes placeholder tokens inline, NOT entire lines
    return TextProcessingService.applySmartCopy(_finalNoteController.text);
  }

  Future<void> _smartCopyAndInject() async {
      // 1. Get Clean Text (Filter placeholders)
      final cleanText = _getCleanText();
      
      if (cleanText.isEmpty && _finalNoteController.text.isNotEmpty) {
           _showError("No clean text to copy. All lines appear to be placeholders.");
           return;
      }
      if (cleanText.isEmpty) return;

      // 2. Copy Clean Text to Clipboard
      await Clipboard.setData(ClipboardData(text: cleanText));
      
      bool injected = false;
      
      // 3. Try Smart Inject (Web Extension Only)
      if (kIsWeb) {
          try {
             // Access the global window.scribeflow object defined in extension_interop.js
             final scribeflow = globalContext['scribeflow'];
             if (scribeflow != null) {
                 final jsObj = scribeflow as JSObject;
                 // Call injectTextToActiveTab(cleanText)
                 final promise = jsObj.callMethod('injectTextToActiveTab'.toJS, cleanText.toJS) as JSPromise;
                 final result = await promise.toDart;
                 injected = (result as JSBoolean).toDart;
             }
          } catch (e) {
             print("Injection failed: $e");
          }
      }

      String message = injected 
          ? "✅ Injected & Clean Copied" 
          : "✅ Clean Text Copied";
          
      if (!injected && kIsWeb) {
          message += " (Injection failed)";
      }
          
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: injected ? Colors.green : Colors.blue,
          duration: const Duration(seconds: 2),
      ));
      
      // Update Status
      if (widget.draftNote.id > 0) {
          await _inboxService.updateStatus(widget.draftNote.id, NoteStatus.copied);
      }
      
      // We do NOT pop here, allowing user to keep working or press Back manually
      // Navigator.pop(context, cleanText); 
  }

  Future<void> _markAsReady() async {
      if (_finalNoteController.text.isEmpty) return;
      
      // Save content first
      await _saveDraft();
      
      // Update Status
      if (widget.draftNote.id > 0) {
           await _inboxService.updateStatus(widget.draftNote.id, NoteStatus.ready);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Marked as Ready"),
          backgroundColor: Colors.green,
      ));
      
      
      Navigator.pop(context);
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
                                const Text("Original Note", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
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
    // Ensure we don't crash if macros list is empty or null
    final displayedMacros = _quickMacros.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16), // Vertical padding only
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Row(
               children: [
                 const Icon(Icons.extension_outlined, color: Colors.white70, size: 18),
                 const SizedBox(width: 8),
                 const Text("Choose Template", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                 const Spacer(),
                 // Show All Button
                 InkWell(
                   onTap: () async {
                         final result = await showDialog<DesktopMacro.Macro>(
                           context: context,
                           builder: (context) => const MacroExplorerDialog(),
                         );
                         
                         if (result != null) {
                             // Convert to Mobile MacroModel
                             final macroModel = MacroModel(
                                 id: result.id,
                                 trigger: result.trigger,
                                 content: result.content,
                                 isFavorite: result.isFavorite,
                                 category: result.category,
                                 isAiMacro: result.isAiMacro,
                                 aiInstruction: result.aiInstruction,
                             );
                             _applyTemplate(macroModel);
                         }
                   },
                   child: const Text("All Templates", style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                 )
               ],
             ),
           ),
           const SizedBox(height: 12),
           
           // Horizontal Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: displayedMacros.map((macro) {
                   final isSelected = _selectedMacro?.id == macro.id;
                   return Padding(
                     padding: const EdgeInsets.only(right: 8),
                     child: FilterChip(
                       label: Text(macro.trigger),
                       selected: isSelected,
                       onSelected: (bool selected) {
                          if (selected) _applyTemplate(macro);
                       },
                       backgroundColor: const Color(0xFF2A2A2A),
                       selectedColor: AppTheme.accent.withOpacity(0.2),
                       checkmarkColor: AppTheme.accent,
                       labelStyle: TextStyle(
                         fontSize: 13, 
                         color: isSelected ? AppTheme.accent : Colors.white70,
                         fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                         fontFamily: 'Inter' // Assuming Inter is available or fallback
                        ),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(20),
                         side: BorderSide(color: isSelected ? AppTheme.accent : Colors.transparent),
                       ),
                       showCheckmark: true,
                     ),
                   );
                }).toList(),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildGeneratedNoteCard() {
    return Container(
      width: double.infinity, // Ensure full width
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C), // Unified background color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: EdgeInsets.zero, // Remove inner padding from main container
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                 const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
                 const SizedBox(width: 8),
                 const Text("Generated Note", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
          
          if (_isGenerating)
             const SizedBox(height: 100) 
          else
             Container(
               width: double.infinity,
               // REMOVED color property to let it be transparent/inherit from parent
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), 
               child: TextField(
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
                   contentPadding: EdgeInsets.only(bottom: 16), // Add bottom padding for text
                   hintText: "AI generated note will appear here...",
                   hintStyle: TextStyle(color: Colors.white24),
                   fillColor: Colors.transparent,
                   filled: true,
                 ),
                 onTap: _handleEditorTap,
               ),
             ),
        ],
      ),
    );
  }


}
