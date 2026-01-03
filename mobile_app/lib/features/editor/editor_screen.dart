import 'package:flutter/material.dart';
import 'package:scribe_brain/scribe_brain.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import 'package:provider/provider.dart';
import '../../services/websocket_service.dart';
import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/macro_service.dart';
import 'package:http/http.dart' as http; // For Web Blob fetching
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../../services/inbox_service.dart';
import '../../models/note_model.dart'; // Ensure NoteModel is imported
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'animated_loading_text.dart';

class EditorScreen extends StatefulWidget {
  final NoteModel? draftNote;
  
  const EditorScreen({super.key, this.draftNote});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Controllers
  late TextEditingController _sourceController; // Top: Raw Transcript
  late TextEditingController _finalController;  // Bottom: Final Note
  
  bool _isKeyboardVisible = false;
  List<MacroModel> _macros = []; 
  StreamSubscription? _wsSubscription;
  bool _isLoading = true; // For initial transcription
  bool _isProcessing = false; // For AI generation
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSourceExpanded = false; // Toggle source view
  bool _useHighAccuracy = false; // Toggle for AI Mode (Standard vs Suggestions)
  
  // Auto-Save State
  int? _currentNoteId; // Track the cloud note ID for updates
  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer; // For manual edit auto-save

  @override
  void initState() {
    super.initState();
    
    // Initialize ID if opening existing draft
    if (widget.draftNote != null) {
      _currentNoteId = int.tryParse(widget.draftNote!.uuid) ?? widget.draftNote!.id;
    }

    // Load Content
    // Source: Original raw text
    _sourceController = TextEditingController(text: widget.draftNote?.originalText ?? widget.draftNote?.content ?? "");
    
    // Final: Formatted text if exists
    _finalController = TextEditingController(text: widget.draftNote?.formattedText ?? ""); 
    
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

  Future<void> _saveDraftUpdate() async {
    if (_currentNoteId == null) return;
    
    try {
      final inboxService = InboxService();
      await inboxService.updateNote(
        _currentNoteId!,
        rawText: _sourceController.text, // REQUIRED by backend
        formattedText: _finalController.text,
        // We persist the original transcript too if needed
      );
      debugPrint("📝 Auto-saved manual edits to cloud");
    } catch (e) {
      debugPrint("❌ Auto-save failed: $e");
    }
  }

  Future<void> _initStandalone() async {
     final macroService = MacroService();
     final macros = await macroService.getMacros();
     
     // 🚀 FETCH LATEST DATA: Don't rely solely on the passed draftNote (which might be stale)
     if (_currentNoteId != null) {
       try {
         final inboxService = InboxService();
         final freshNote = await inboxService.getNoteById(_currentNoteId!);
         if (freshNote != null && mounted) {
           // Only update if fresh data exists and is different/newer
           if (freshNote.formattedText.isNotEmpty && freshNote.formattedText != _finalController.text) {
              debugPrint("🔄 Refreshing Editor with latest Cloud data...");
              _finalController.text = freshNote.formattedText;
              
              // Also update suggestions if available/persisted (future improvement)
           }
           if (freshNote.originalText.isNotEmpty && freshNote.originalText != _sourceController.text) {
             _sourceController.text = freshNote.originalText;
           }
         }
       } catch (e) {
         debugPrint("⚠️ Failed to refresh note data: $e");
       }
     }
     
     if (mounted) {
       // Sort: Favorites first, then alphabetical
       macros.sort((a, b) {
         if (a.isFavorite && !b.isFavorite) return -1;
         if (!a.isFavorite && b.isFavorite) return 1;
         return a.trigger.compareTo(b.trigger);
       });
       setState(() => _macros = macros);
     }

     final path = widget.draftNote?.audioPath;
     if (path != null) {
         
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
                     const SnackBar(content: Text("Failed to load web audio for transcription"), backgroundColor: Colors.red),
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
        if (bytes != null) {
             final prefs = await SharedPreferences.getInstance();
             final apiKey = prefs.getString('groq_api_key') ?? dotenv.env['GROQ_API_KEY'] ?? "";
             
             // Note: If empty, GroqService will use its default key

             try {
                // Initialize Engine
                final engine = ProcessingEngine(
                  groqApiKey: apiKey.isEmpty ? (dotenv.env['GROQ_API_KEY'] ?? "") : apiKey,
                  geminiApiKey: dotenv.env['GEMINI_API_KEY'] ?? "",
                );
                
                final groqPref = prefs.getString('groq_model') ?? GroqModel.precise.modelId;
                final groqModel = GroqModel.values.firstWhere(
                  (e) => e.modelId == groqPref, 
                  orElse: () => GroqModel.precise
                );

                final config = ProcessingConfig(
                  groqModel: groqModel,
                  geminiMode: GeminiMode.fast,
                  userPreferences: {}
                );

                final result = await engine.processRequest(
                  audioBytes: bytes, 
                  config: config,
                  skipAi: true, // Transcription Only
                  audioFilename: kIsWeb ? 'recording.webm' : 'recording.m4a',
                );
                
                final transcript = result.rawTranscript;
                
                if (mounted) {
                  setState(() => _isLoading = false);
                  
                  // Check if transcript is an error message
                  if (transcript.startsWith('Error:')) {
                    _sourceController.text = "❌ Transcription failed. Please check your API key and try again.";
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(transcript), backgroundColor: Colors.red)
                    );
                  } else {
                    final cleanText = transcript.trim();
                    if (!cleanText.toLowerCase().contains("thank you") && cleanText.isNotEmpty) {
                        _sourceController.text = cleanText;
                        
                        // AUTO-SAVE: Create draft immediately after transcription
                        try {
                          final inboxService = InboxService();
                          final noteId = await inboxService.addNote(
                            cleanText,
                            patientName: "Draft Note",
                            // No formatted text yet - this is a draft
                          );
                          
                          setState(() => _currentNoteId = noteId);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("📝 Draft saved to cloud"),
                                backgroundColor: Colors.blueGrey,
                                duration: Duration(seconds: 2),
                              )
                            );
                          }
                        } catch (e) {
                          debugPrint("Auto-save draft failed: $e");
                          // Don't block user on save failure
                        }
                    }
                  }
                }
             } catch (e) {
                debugPrint("Transcription Error: $e");
                if (mounted) {
                  setState(() => _isLoading = false);
                  _sourceController.text = "❌ Transcription error: Network issue or invalid audio format";
                }
             }
        } else {
             debugPrint("No audio bytes found/loaded.");
             if (mounted) setState(() => _isLoading = false);
        }
     } else {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _applyMacroWithAI(MacroModel macro) async {
    final prefs = await SharedPreferences.getInstance();
    String? geminiKey = prefs.getString('gemini_api_key');
    
    // Check if key is null or empty string, use defaults
    if (geminiKey == null || geminiKey.trim().isEmpty) {
      geminiKey = dotenv.env['GEMINI_API_KEY'] ?? "AIzaSyDCTc9DumgaXQCaxuopADnUsjV1dU4d7rI";
    }

    // Only show dialog if we still don't have a key after all fallbacks
    if (geminiKey.trim().isEmpty) {
      if (mounted) {
         showDialog(
           context: context,
           builder: (context) => AlertDialog(
             backgroundColor: const Color(0xFF1E1E1E),
             title: Text("Missing AI Key", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
             content: Text(
               "To use AI features, please set your Gemini API Key in Settings.\n\nWithout a key, the system cannot process the transcript.",
               style: GoogleFonts.inter(color: Colors.white70)
             ),
             actions: [
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text("Cancel"),
               ),
               TextButton(
                 onPressed: () {
                   Navigator.pop(context);
                 },
                 child: const Text("OK", style: TextStyle(color: AppTheme.accent)),
               )
             ],
           )
         );
      }
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('groq_api_key') ?? dotenv.env['GROQ_API_KEY'] ?? "";
      final geminiKey = prefs.getString('gemini_api_key') ?? dotenv.env['GEMINI_API_KEY'] ?? "";

      // 1. Initialize Engine
      final engine = ProcessingEngine(
        groqApiKey: apiKey,
        geminiApiKey: geminiKey,
      );

      // 2. Prepare Config
      final groqPref = prefs.getString('groq_model') ?? GroqModel.precise.modelId;
      final groqModel = GroqModel.values.firstWhere(
        (e) => e.modelId == groqPref, 
        orElse: () => GroqModel.precise
      );

      final config = ProcessingConfig(
        groqModel: groqModel,
        geminiMode: _useHighAccuracy ? GeminiMode.smart : GeminiMode.fast,
        selectedMacroId: macro.id.toString(),
        userPreferences: {
          'specialty': prefs.getString('specialty') ?? 'General Practice',
          'global_prompt': prefs.getString('global_ai_prompt') ?? '',
        }
      );

      // 3. Process Request (Passing Raw Text from Editor to preserve edits)
      final rawText = _sourceController.text;
      
      final result = await engine.processRequest(
        rawTranscript: _sourceController.text, // Use edited text
        config: config,
        macroContent: macro.content,
        // No audioFilename needed as we are passing rawTranscript
      );

      // 4. Update UI
      if (mounted) {
        setState(() {
          _finalController.text = result.formattedText;
          _suggestions = result.suggestions.map((s) => s.toJson()).toList(); // Map back to existing UI logic
        });

        // 5. AUTO-SAVE: Update existing note or create new one
        try {
          final inboxService = InboxService();
          
          if (_currentNoteId != null) {
            // Update existing draft with AI result
            await inboxService.updateNote(
              _currentNoteId!,
              rawText: _sourceController.text, // REQUIRED by backend
              formattedText: result.formattedText,
              suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
              patientName: macro.trigger,
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ AI Result saved to Cloud"), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
            );
          } else {
            // Fallback: create new note if no draft exists
            final noteId = await inboxService.addNote(
               result.rawTranscript,
               formattedText: result.formattedText,
               suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
               patientName: macro.trigger,
            );
            
            setState(() => _currentNoteId = noteId);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ AI Result saved to Cloud"), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
            );
          }
        } catch (e) {
             // Fallback or Error handling
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Cloud update failed: $e"), backgroundColor: Colors.orange),
             );
        }
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }



  // ... inside _EditorScreenState

  void _handleTextFieldTap() {
    final text = _finalController.text;
    final selection = _finalController.selection;
    
    if (selection.baseOffset < 0) return;
    
    // Logic: If tap is inside a word, select the whole word
    int start = selection.baseOffset;
    int end = selection.baseOffset;
    
    if (start >= text.length) return;

    // Expand Left
    while (start > 0 && !_isWordBoundary(text[start - 1])) {
       start--;
    }
    
    // Expand Right
    while (end < text.length && !_isWordBoundary(text[end])) {
       end++;
    }
    
    if (start < end) {
       _finalController.selection = TextSelection(baseOffset: start, extentOffset: end);
    }
  }

  bool _isWordBoundary(String char) {
    return " \n\r.,:;()[]".contains(char);
  }

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

  // ... Update build method for _finalController TextField to use onTap/GestureDetector?
  // TextField doesn't have direct onTap for cursor logic easily, but we can wrap it or use selection controls.
  // Actually, for Mobile, standard "Double Tap" selects word. 
  // User wants "Single Tap" behavior from Desktop.
  
  // To implement Single Tap Select on Mobile TextField is tricky because it fights with cursor placement.
  // A better approach for Mobile might be "Double Tap" standard, but let's try to hook into `onTap` if possible.
  // NOTE: TextField `onTap` fires, but after cursor is placed. We can refine selection there.



  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Very dark neutral background
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text("Pocket Editor", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () async {
                  final contentToSend = _finalController.text.isNotEmpty ? _finalController.text : _sourceController.text;
                  
                  // Note is already saved via auto-save, just notify user and close
                  if (_currentNoteId != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Work saved to Cloud"), backgroundColor: AppTheme.successGreen)
                    );
                  } else {
                    // Fallback: save if somehow auto-save didn't work
                    try {
                      final inboxService = InboxService();
                      await inboxService.addNote(
                        _sourceController.text,
                        formattedText: _finalController.text.isNotEmpty ? _finalController.text : null,
                        patientName: "Quick Note",
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ Saved to Cloud"), backgroundColor: AppTheme.successGreen)
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red)
                      );
                    }
                  }

                  // Notify Desktop via WebSocket (Real-time signal)
                  final ws = Provider.of<WebSocketService>(context, listen: false);
                  if (ws.isConnected) {
                    ws.sendMessage("SAVE_NOTE:$contentToSend");
                  }

                  if (mounted) Navigator.pop(context, contentToSend);
                },
                icon: const Icon(Icons.check, size: 14, color: Colors.black),
                label: const Text("Ready", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(), // Pill shape
                  elevation: 0,
                ),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                // 2️⃣ Original Message Section (Input Preview)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          "ORIGINAL MESSAGE", 
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 80), // Compact height
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E), // Slightly lighter surface
                          borderRadius: BorderRadius.circular(12),
                          // No border, minimal
                        ),
                        child: _isLoading 
                        ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                        : TextField(
                            controller: _sourceController,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              border: InputBorder.none, 
                              hintText: "Processing transcript...", 
                              hintStyle: TextStyle(color: Colors.white24),
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                      ),
                    ],
                  ),
                ),

                // 3️⃣ Main Output Section (Primary Focus Area)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            "AI RESULT", 
                            style: GoogleFonts.inter(color: AppTheme.accent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              _isProcessing
                              ? const Center(child: AnimatedLoadingText())
                              : TextField(
                                  controller: _finalController,
                                  onTap: () {
                                     // Helper for cursor/selection logic if needed
                                     // Future.delayed(const Duration(milliseconds: 50), _handleTextFieldTap);
                                  },
                                  style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFFE0E0E0), height: 1.6), // Comfortable styling
                                  maxLines: null,
                                  expands: true,
                                  decoration: InputDecoration(
                                    // Placeholder centered logic handled by alignment if empty, 
                                    // but expands:true makes it fill area.
                                    hintText: "Select a Macro to generate note...",
                                    hintStyle: GoogleFonts.inter(color: Colors.white12, fontSize: 16),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 4️⃣ AI Macros Section (Bottom Action Zone) -> Expandable Sheet
          // Toggle sits above the sheet
          Positioned(
            left: 0, 
            right: 0,
            bottom: (MediaQuery.of(context).size.height * 0.13) + 6,
            child: _buildValuesToggle(),
          ),

          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if (notification.extent > 0.3 && !_isSheetExpanded) {
                setState(() => _isSheetExpanded = true);
              } else if (notification.extent <= 0.3 && _isSheetExpanded) {
                 setState(() => _isSheetExpanded = false);
              }
              return true;
            },
            child: _buildExpandableMacroPanel(),
          ),
        ],
      ),
    );
  }

  bool _isSheetExpanded = false;

  Widget _buildValuesToggle() {
      // Minimal Checkbox Toggle
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // Align Left
          children: [
             SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _useHighAccuracy, 
                  activeColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: const BorderSide(color: Colors.white24, width: 2),
                  onChanged: (v) => setState(() => _useHighAccuracy = v ?? false)
                ),
             ),
             const SizedBox(width: 12),
             RichText(
               text: TextSpan(
                 children: [
                   TextSpan(
                     text: "مقترحات اضافيه ",
                     style: GoogleFonts.cairo( // Arabic Friendly Font
                       color: Colors.white,
                       fontSize: 14,
                       fontWeight: FontWeight.w500
                     ),
                   ),
                   TextSpan(
                     text: "(سيزيد المعالجة 30%)",
                     style: GoogleFonts.cairo(
                       color: Colors.white54, // Muted/Soft color
                       fontSize: 12,
                     ),
                   )
                 ]
               )
             )
          ],
        ),
      );
  }

  Widget _buildExpandableMacroPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.13, 
      minChildSize: 0.10,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818), 
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -5))]
          ),
          child: Column(
            children: [
               const SizedBox(height: 6),
               // Handle
               Center(
                child: Container(
                  width: 32, height: 4, 
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))
                ),
              ),
              const SizedBox(height: 4),

              // Content List
              Expanded(
                child: _isSheetExpanded
                ? SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        alignment: WrapAlignment.start,
                        children: _macros.map((m) => _buildMacroChip(m)).toList(),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: _macros.length,
                    separatorBuilder: (_,__) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      // UnconstrainedBox allows the chip to be its natural size
                      return UnconstrainedBox(child: _buildMacroChip(_macros[index]));
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroChip(MacroModel m) {
    return InkWell(
      onTap: () => _applyMacroWithAI(m),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(100), 
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          m.trigger, 
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500
          ),
        ),
      ),
    );
  }
}
