import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../../../widgets/pattern_highlight_controller.dart';
import '../../../services/api_service.dart';
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
import 'dart:math'; // For exponential backoff in retry logic

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
      // Prefer server ID if valid (> 0), otherwise fallback to UUID parsing
      _currentNoteId = (widget.draftNote!.id > 0) ? widget.draftNote!.id : int.tryParse(widget.draftNote!.uuid);
    }

    // Load Content
    // Source: Original raw text
    _sourceController = TextEditingController(text: widget.draftNote?.originalText ?? widget.draftNote?.content ?? "");
    
    // Final: Formatted text if exists
    // Use PatternHighlightController to highlight [brackets] or "Not Reported"
    _finalController = PatternHighlightController(
      text: widget.draftNote?.formattedText ?? "",
      patternStyles: {
        RegExp(r'\[(.*?)\]'): const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800)),
        RegExp(r'Not Reported', caseSensitive: false): const TextStyle(color: Colors.white24, decoration: TextDecoration.lineThrough),
      },
    ); 
    
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
        debugPrint('⏳ Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }
    }
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
     
     // 🚀 FETCH LATEST DATA: But only if we don't have fresh content
     // This prevents cache from overwriting AI-generated results
     if (_currentNoteId != null && _finalController.text.isEmpty) {
       try {
         final inboxService = InboxService();
         final freshNote = await inboxService.getNoteById(_currentNoteId!);
         if (freshNote != null && mounted) {
           // Load saved AI result from cloud
           if (freshNote.formattedText.isNotEmpty) {
             debugPrint("🔄 Loading saved AI result from cloud...");
             debugPrint("   Formatted Text Length: ${freshNote.formattedText.length}");
             _finalController.text = freshNote.formattedText;
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
              try {
                final apiService = ApiService();
                final result = await apiService.multipartPost(
                  '/audio/transcribe',
                  fileBytes: bytes,
                  filename: kIsWeb ? 'recording.webm' : 'recording.m4a',
                );

                if (result['status'] == true) {
                  final transcript = result['payload']['text'] ?? "";
                  
                  if (mounted) {
                    setState(() => _isLoading = false);
                    
                    final cleanText = transcript.trim();
                    if (cleanText.isNotEmpty) {
                        _sourceController.text = cleanText;
                        
                        // AUTO-SAVE: Create draft immediately after transcription
                        try {
                          final inboxService = InboxService();
                          final noteId = await inboxService.addNote(
                            cleanText,
                            patientName: "Draft Note",
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
                        }
                    }
                  }
                } else {
                  throw result['message'] ?? 'Transcription failed';
                }
              } catch (e) {
                debugPrint("Transcription Error: $e");
                if (mounted) {
                  setState(() => _isLoading = false);
                  _sourceController.text = "❌ Transcription error: $e";
                }
              }
         }
 else {
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
      geminiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiService = ApiService();
      
      final response = await apiService.post('/audio/process', body: {
        'transcript': _sourceController.text,
        'macro_context': macro.content,
        'specialty': prefs.getString('specialty') ?? 'General Practice',
        'global_prompt': prefs.getString('global_ai_prompt') ?? '',
        'mode': _useHighAccuracy ? 'smart' : 'fast',
      });

      if (response['status'] == true) {
        final payload = response['payload'];
        if (mounted) {
          setState(() {
            _finalController.text = payload['final_note'] ?? payload['text'] ?? '';
            if (payload.containsKey('missing_suggestions')) {
              _suggestions = (payload['missing_suggestions'] as List).cast<Map<String, dynamic>>();
            } else {
              _suggestions = [];
            }
          });

          // 5. AUTO-SAVE: Update existing note or create new one
          try {
            final inboxService = InboxService();
            if (_currentNoteId != null) {
              await inboxService.updateNote(
                _currentNoteId!,
                rawText: _sourceController.text,
                formattedText: _finalController.text,
                suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
                patientName: macro.trigger,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Note saved and verified"), backgroundColor: Colors.green),
                );
              }
            } else {
              final noteId = await inboxService.addNote(
                _sourceController.text,
                formattedText: _finalController.text,
                suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
                patientName: macro.trigger,
              );
              setState(() => _currentNoteId = noteId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ New note created (#$noteId)"), backgroundColor: Colors.green),
                );
              }
            }
          } catch (e) {
            debugPrint('❌ AUTO-SAVE FAILED: $e');
          }
        }
      } else {
        throw response['message'] ?? 'Processing failed';
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
          errorMessage = 'The Gemini API key is invalid or missing.\n\nPlease configure a valid key in Settings.';
          errorColor = Colors.orange;
        } else if (errorStr.contains('placeholder') || errorStr.contains('your_')) {
          errorTitle = 'API Key Not Configured';
          errorMessage = 'The default placeholder API key is still being used.\n\nPlease set a real Gemini API key in Settings.';
          errorColor = Colors.orange;
        } else if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('timeout')) {
          errorTitle = 'Network Error';
          errorMessage = 'Could not connect to AI service.\n\nCheck your internet connection and try again.';
        } else if (errorStr.contains('503') || errorStr.contains('overloaded')) {
          errorTitle = 'Service Temporarily Unavailable';
          errorMessage = 'Gemini AI is currently overloaded.\n\nPlease try again in a few seconds.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                    title: Text('Error Details', style: GoogleFonts.inter(color: Colors.white)),
                    content: SingleChildScrollView(
                      child: SelectableText(
                        e.toString(),
                        style: GoogleFonts.sourceCodePro(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: AppTheme.accent)),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _copyCleanText() {
    final text = _finalController.text;
    if (text.isEmpty) return;

    // 1. Split into lines
    final List<String> lines = text.split('\n');
    final List<String> cleanLines = [];

    // 2. Filter lines
    for (var line in lines) {
      // Logic: If line contains [Not Reported] or just [...], skip it.
      // We can be aggressive or specific.
      // User requested: "remove lines with [Not Reported]"
      
      bool isDirty = false;
      
      if (line.contains('[Not Reported]')) isDirty = true;
      if (line.contains('Not Reported')) isDirty = true;
      // if (line.trim() == '[]') isDirty = true; 

      if (!isDirty) {
        cleanLines.add(line);
      }
    }

    final cleanText = cleanLines.join('\n');

    // 3. Copy to Clipboard
    Clipboard.setData(ClipboardData(text: cleanText));

    // 4. Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cleaning_services, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("✅ Text Cleaned & Copied!", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Removed ${lines.length - cleanLines.length} lines with missing info.", style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        )
      );
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
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.copy_all_rounded, color: Colors.white70),
              tooltip: "Smart Copy (Clean)",
              onPressed: _copyCleanText,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () async {
                  final contentToSend = _finalController.text.isNotEmpty ? _finalController.text : _sourceController.text;
                  
                  // Note is already saved via auto-save, just notify user and close
                  if (_currentNoteId != null) {
                    // EXPLICITLY SET STATUS TO READY
                    try {
                       final inboxService = InboxService();
                       await inboxService.updateStatus(_currentNoteId!, NoteStatus.ready);
                    } catch (e) {
                       debugPrint("Error setting status to ready: $e");
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Note marked as Ready!"), backgroundColor: AppTheme.successGreen)
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "ORIGINAL MESSAGE", 
                              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                            ),
                            // Unified Feature: Use Raw Text Button
                            InkWell(
                              onTap: () {
                                if (_sourceController.text.isNotEmpty) {
                                  setState(() {
                                    _finalController.text = _sourceController.text;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("⬇️ Copied raw text to editor"),
                                      duration: Duration(milliseconds: 1000),
                                      backgroundColor: Color(0xFF2C2C2C),
                                    )
                                  );
                                  // Optional: Trigger auto-save immediately
                                  _saveDraftUpdate();
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_downward_rounded, color: AppTheme.accent, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Use Raw Text",
                                      style: GoogleFonts.inter(
                                        color: AppTheme.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
