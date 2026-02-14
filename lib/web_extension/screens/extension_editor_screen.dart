import 'dart:async';
import 'dart:math'; // For exponential backoff
import 'dart:ui'; // For PointerDeviceKind
import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart'; // Import AppTheme
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // For Web Blob fetching
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:js_interop'; // For calling JS functions
import 'dart:js_interop_unsafe'; // For accessing global properties

// Models & Services
import '../../mobile_app/models/note_model.dart';
// Mobile Editor uses: import '../../services/macro_service.dart'; which returns List<MacroModel>.
import '../../mobile_app/services/macro_service.dart'; 
import '../../mobile_app/services/inbox_service.dart';
import '../../services/api_service.dart';

import '../../widgets/pattern_highlight_controller.dart'; 
import '../../desktop/macro_explorer_dialog.dart'; 
import '../../models/macro.dart' as DesktopMacro; // Explicit import for dialog result

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
        RegExp(r'\[(.*?)\]'): const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800)),
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
    _generationTimer?.cancel();
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
        final apiService = ApiService();
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
                   // Expand Source if it's the only thing we have
                   _isRawTextExpanded = _finalNoteController.text.isEmpty; 
               });
               
               // Auto-Save Draft
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
          _elapsedSeconds = 0;
          _statusMessageIndex = 0;
          _isRawTextExpanded = false; 
       });
       
       // Animation Timer
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
           // Save selected template ID
           await prefs.setInt('last_selected_macro_id', macro.id);
           
           final enableSuggestions = prefs.getBool('enable_smart_suggestions') ?? true;
           
           final apiService = ApiService();
           final response = await apiService.post('/audio/process', body: {
               'transcript': _rawText,
               'macro_context': macro.content,
               'specialty': prefs.getString('specialty') ?? 'General Practice',
               'global_prompt': prefs.getString('global_ai_prompt') ?? '',
               'mode': enableSuggestions ? 'smart' : 'fast',
           });

           if (response['status'] == true) {
               final payload = response['payload'];
               final finalText = payload['final_note'] ?? payload['text'] ?? '';
               
               if (mounted) {
                   setState(() {
                       _finalNoteController.text = finalText;
                   });
                   _saveDraft(); // Auto-save result
               }
           } else {
               _showError("Generation failed: ${response['message']}");
           }
       } catch (e) {
           _showError("AI Error: $e");
       } finally {
           _generationTimer?.cancel();
           if(mounted) setState(() => _isGenerating = false);
       }
  }

  String _getCleanText() {
      final text = _finalNoteController.text;
      if (text.isEmpty) return "";

      final List<String> lines = text.split('\n');
      final List<String> cleanLines = [];

      for (var line in lines) {
          bool isDirty = false;
          if (line.contains('[Not Reported]')) isDirty = true;
          if (line.contains('Not Reported')) isDirty = true; 
          // Add logic for [Name] etc? User said "text without missing info". 
          // Usually [Name] is mandatory but [Not Reported] is optional.
          // We stick to the previous Smart Copy logic: pattern is mostly Not Reported.
          
          if (!isDirty) {
               cleanLines.add(line);
          }
      }
      return cleanLines.join('\n');
  }

  Future<void> _smartCopyAndInject() async {
      final cleanText = _getCleanText();
      if (cleanText.isEmpty && _finalNoteController.text.isNotEmpty) {
           // Fallback if everything was dirty? Should rarely happen.
           // Maybe just warn? Or copy nothing? 
           // Let's assume there's always *something*.
      }
      if (cleanText.isEmpty) return;

      // 1. Copy Clean Text to Clipboard
      await Clipboard.setData(ClipboardData(text: cleanText));
      
      bool injected = false;
      
      // 2. Try Smart Inject (Web Extension Only)
      if (kIsWeb) {
          try {
             final scribeflow = globalContext['scribeflow'];
             if (scribeflow != null) {
                 final jsObj = scribeflow as JSObject;
                 final promise = jsObj.callMethod('injectTextToActiveTab'.toJS, cleanText.toJS) as JSPromise;
                 final result = await promise.toDart;
                 injected = (result as JSBoolean).toDart;
             }
          } catch (e) {
             print("Injection failed: $e");
          }
      }

      String message = injected 
          ? "✅ Injected & Clean Text Copied" 
          : "✅ Clean Text Copied";
          
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: injected ? Colors.green : Colors.blue,
          duration: const Duration(seconds: 2),
      ));
      
      // Update Status
      if (widget.draftNote.id > 0) {
          await _inboxService.updateStatus(widget.draftNote.id, NoteStatus.copied);
      }
      
      Navigator.pop(context, cleanText); 
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
      // Delay to allow the system to place the cursor first.
      // 100ms covers potential frame delays on slower devices/browsers.
      Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          
          final text = _finalNoteController.text;
          final selection = _finalNoteController.selection;
          
          // Only auto-select if the user simply tapped (collapsed selection), not if they engaged in a drag selection.
          if (!selection.isValid || !selection.isCollapsed) return;
          
          final cursor = selection.baseOffset;
          
          // 1. Check for [Brackets]
          final bracketRegex = RegExp(r'\[(.*?)\]');
          final bracketMatches = bracketRegex.allMatches(text);
          
          for (final match in bracketMatches) {
              // Check if cursor is strictly INSIDE or ON the edges
              if (cursor >= match.start && cursor <= match.end) {
                  _finalNoteController.selection = TextSelection(
                      baseOffset: match.start,
                      extentOffset: match.end,
                  );
                  return; 
              }
          }
          
          // 2. Check for "Not Reported" (Case Insensitive)
          // For bare occurrences outside brackets
          final nrRegex = RegExp(r'Not Reported', caseSensitive: false);
          final nrMatches = nrRegex.allMatches(text);
          
          for (final match in nrMatches) {
               if (cursor >= match.start && cursor <= match.end) {
                  _finalNoteController.selection = TextSelection(
                      baseOffset: match.start,
                      extentOffset: match.end,
                  );
                  return;
              }
          }
      });
  }

  void _showError(String msg) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
  }

  // --- UI BUILDERS (Adapted for Extension Dark Theme) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // Dark background
      body: Column(
        children: [
           _buildSmartHeader(),
           
           // Source Accordion
           _buildSourceAccordion(),
           
           // Editor Area
           Expanded(
               child: Container(
                   margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                   decoration: BoxDecoration(
                       color: AppTheme.surface, // Dark surface
                       border: Border.all(color: Colors.white10),
                       borderRadius: BorderRadius.circular(16),
                       boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                       ]
                   ),
                   child: Column(
                       children: [
                           _buildEditorToolbar(),
                           const Divider(height: 1, color: Colors.white10),
                           Expanded(child: _buildDarkEditor()),
                       ],
                   ),
               ),
           ),
           
           // Action Dock
           _buildActionDock(),
        ],
      ),
    );
  }

  Widget _buildSmartHeader() {
      return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppTheme.background, // Dark header
          child: Row(
              children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                  widget.draftNote.title ?? "Extension Note",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                  children: [
                                     Text("Chrome Extension", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                     const SizedBox(width: 8),
                                     _buildStatusBadge(),
                                  ],
                              )
                          ],
                      ),
                  ),
                  if (_isLoading)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                      IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppTheme.success),
                          tooltip: 'Mark as Ready',
                          onPressed: _finalNoteController.text.isEmpty ? null : _markAsReady,
                      ),
              ],
          ),
      );
  }

  Widget _buildStatusBadge() {
       return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: const Text("DRAFT", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
      );
  }

  Widget _buildSourceAccordion() {
      if (_rawText.isEmpty && !_isLoading) return const SizedBox.shrink();

      final lines = _rawText.split('\n');
      final preview = lines.take(1).join(' ') + (lines.length > 1 ? '...' : '');

      return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
             color: AppTheme.surface,
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.white10),
          ),
          child: Column(
              children: [
                  InkWell(
                      onTap: () => setState(() => _isRawTextExpanded = !_isRawTextExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                  children: [
                                      Icon(Icons.mic_none, size: 14, color: Colors.white38),
                                      const SizedBox(width: 8),
                                      const Text("Source", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      const Spacer(),
                                      // Always visible Copy Button
                                      InkWell(
                                          onTap: () {
                                              Clipboard.setData(ClipboardData(text: _rawText));
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied raw text"), duration: Duration(seconds: 1)));
                                          },
                                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 14, color: AppTheme.accent)),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(_isRawTextExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.white38),
                                  ],
                              ),
                              const SizedBox(height: 4),
                              // Always visible textual preview (First Line)
                              Text(
                                preview, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic)
                              ),
                            ],
                          ),
                      ),
                  ),
                  if (_isRawTextExpanded)
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          constraints: const BoxConstraints(maxHeight: 150),
                          child: SingleChildScrollView(
                              child: SelectableText(_rawText, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                          ),
                      )
              ],
          ),
      );
  }

  Widget _buildEditorToolbar() {
     final displayedMacros = _quickMacros.take(10).toList();
     return Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         color: AppTheme.background, // Dark toolbar
         child: ScrollConfiguration(
             behavior: ScrollConfiguration.of(context).copyWith(
               dragDevices: {
                 PointerDeviceKind.touch,
                 PointerDeviceKind.mouse,
               },
             ),
             child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 child: Row(
                     children: [
                         Text("TEMPLATES:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
                         const SizedBox(width: 8),
                         ...displayedMacros.map((macro) {
                             final isSelected = _selectedMacro?.id == macro.id;
                             return Padding(
                                 padding: const EdgeInsets.only(right: 6),
                                 child: InkWell(
                                     onTap: () => _applyTemplate(macro),
                                     borderRadius: BorderRadius.circular(20), // Rounded pill shape
                                     child: AnimatedContainer(
                                         duration: const Duration(milliseconds: 200),
                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                         decoration: BoxDecoration(
                                             color: isSelected ? AppTheme.accent.withOpacity(0.2) : AppTheme.surface,
                                             borderRadius: BorderRadius.circular(20),
                                             border: Border.all(color: isSelected ? AppTheme.accent : Colors.white24, width: isSelected ? 1.5 : 1)
                                         ),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             if (isSelected) ...[
                                               const Icon(Icons.check_circle, size: 12, color: AppTheme.accent),
                                               const SizedBox(width: 4),
                                             ],
                                             Text(
                                               macro.trigger, 
                                               style: TextStyle(
                                                 fontSize: 11, 
                                                 fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                                                 color: isSelected ? AppTheme.accent : Colors.white70
                                               )
                                             ),
                                           ],
                                         ),
                                     ),
                                 ),
                             );
                         }).toList(),
                         
                         // More Button
                         IconButton(
                            icon: const Icon(Icons.more_horiz, size: 16, color: Colors.white38),
                            onPressed: () async {
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
                            tooltip: "All Templates",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                         )
                     ],
                 ),
             ),
         ),
     );
  }

  Widget _buildDarkEditor() {
      if (_isGenerating) {
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_statusMessages[_statusMessageIndex], style: TextStyle(color: Colors.white60)),
                  ],
              ),
          );
      }
      
      return Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
              controller: _finalNoteController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white), // Dark Text
              onTap: _handleEditorTap, // Click-to-Select
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Generated note will appear here...",
                  hintStyle: TextStyle(color: Colors.white24)
              ),
          ),
      );
  }

  Widget _buildActionDock() {
      return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))]
          ),
          child: Row(
              children: [
                  // Removed Separate Smart Copy Button
                  Expanded(
                      flex: 10,
                      child: ElevatedButton(
                          onPressed: _finalNoteController.text.isEmpty ? null : _smartCopyAndInject,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.black, // Dark theme contrast
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.input, size: 18), // Changed to Input icon
                                  SizedBox(width: 8),
                                  Text("SMART COPY / INJECT", style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                          ),
                      ),
                  ),
              ],
          ),
      );
  }
}
