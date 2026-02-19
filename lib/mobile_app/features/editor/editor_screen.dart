import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'dart:ui'; // For PointerDeviceKind
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
import '../../../widgets/processing_overlay.dart';

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
  MacroModel? _selectedMacro; // Track selected template 
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
        // Orange for [ Select ]
        RegExp(r'\[ Select \]'): const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800), fontWeight: FontWeight.bold),
        // Default brackets (if any remain)
        RegExp(r'\[(.*?)\]'): const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800)),
        // HEADERS: Uppercase + Colon -> White Underline
        RegExp(r'^[A-Z][A-Z0-9\s\/-]+:', multiLine: true): const TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          decorationThickness: 2.0, // Thicker line as requested
          fontWeight: FontWeight.bold,
          color: Colors.white, 
        ),
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
       
       // Restore selected macro from draft if available
       if (widget.draftNote != null && widget.draftNote!.appliedMacroId != null) {
          try {
             final restored = macros.firstWhere((m) => m.id == widget.draftNote!.appliedMacroId);
             setState(() => _selectedMacro = restored);
          } catch (e) {
             debugPrint("Could not restore selected macro: $e");
          }
       }
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
    setState(() {
      _selectedMacro = macro;
      _isProcessing = true;
    });

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

  void _handleTextFieldTap() {
    final text = _finalController.text;
    final selection = _finalController.selection;
    final cursor = selection.baseOffset;
      
    if (selection.baseOffset < 0) return;
    
    // 0. Check for [ Select ] specific phrase
    final selectRegex = RegExp(r'\[ Select \]');
    final selectMatches = selectRegex.allMatches(text);
    
    for (final match in selectMatches) {
        if (cursor >= match.start && cursor <= match.end) {
            _finalController.selection = TextSelection(
                baseOffset: match.start,
                extentOffset: match.end,
            );
            return;
        }
    }
      
    // 1. Check for [Brackets]or is inside [ ... ]
    // Use RegExp to find all placeholders
    final matches = RegExp(r'\[(.*?)\]').allMatches(text);
    
    for (final match in matches) {
      if (selection.baseOffset >= match.start && selection.baseOffset <= match.end) {
        // Select the whole match
        _finalController.selection = TextSelection(
          baseOffset: match.start, 
          extentOffset: match.end
        );
        break;
      }
    }
  }

  void _copyCleanText() async {
    final text = _finalController.text;
    if (text.isEmpty) return;

    final List<String> lines = text.split('\n');
    final List<String> cleanLines = [];
    // Robust Regex for "Missing Info" placeholders
    // Catches: [Duration not specified], [License not provided], [No medical condition...], [ Select ]
    final placeholderRegex = RegExp(r'\[.*?(not specified|not provided|no .*? identified|select|none).*?\]', caseSensitive: false);

    for (var line in lines) {
      bool isDirty = false;
      
      // Check for regex match
      if (placeholderRegex.hasMatch(line)) isDirty = true;
      
      // Keep legacy checks just in case
      if (line.contains('[ Select ]')) isDirty = true;
      if (line.contains('Not Reported')) isDirty = true; 
      
      if (!isDirty) {
           cleanLines.add(line);
      }
    }

    final cleanText = cleanLines.join('\n').trim();

    // 3. Copy to Clipboard
    await Clipboard.setData(ClipboardData(text: cleanText));

    // 4. Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cleaning_services, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("✅ Smart Copy Active", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Copied without ${lines.length - cleanLines.length} placeholder lines.", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        )
      );
    }
  }



  // ... inside _EditorScreenState



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





  void _showAllTemplates() {
      showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF181818),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) {
              return DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.3,
                  maxChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) {
                      return Column(
                          children: [
                              const SizedBox(height: 12),
                              // Handle
                              Center(
                                child: Container(
                                  width: 40, height: 4, 
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))
                                ),
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                child: Text("All Templates", style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                  child: ListView.separated(
                                      controller: scrollController,
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                                      itemCount: _macros.length,
                                      separatorBuilder: (_,__) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                          final macro = _macros[index];
                                          final isSelected = _selectedMacro?.id == macro.id;
                                          return InkWell(
                                              onTap: () {
                                                  Navigator.pop(context);
                                                  _applyMacroWithAI(macro);
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                      color: isSelected ? AppTheme.accent.withOpacity(0.1) : const Color(0xFF2C2C2C),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: isSelected ? AppTheme.accent : Colors.white10),
                                                  ),
                                                  child: Row(
                                                      children: [
                                                          Icon(
                                                              isSelected ? Icons.check_circle : (macro.isFavorite ? Icons.star : Icons.article),
                                                              size: 18,
                                                              color: isSelected ? AppTheme.accent : (macro.isFavorite ? Colors.amber : Colors.white38),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                      Text(macro.trigger, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                                                      if (macro.aiInstruction != null && macro.aiInstruction!.isNotEmpty)
                                                                      Text(macro.aiInstruction!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                                                  ],
                                                              ),
                                                          ),
                                                          Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white12),
                                                      ],
                                                  ),
                                              ),
                                          );
                                      },
                                  ),
                              ),
                          ],
                      );
                  }
              );
          }
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;

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
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                          _buildOriginalNoteCard(),
                          const SizedBox(height: 16),
                          _buildTemplateSelectorCard(),
                          const SizedBox(height: 16),
                          _buildGeneratedNoteCard(),
                          const SizedBox(height: 80), // Space for bottom dock
                       ],
                     ),
                   ),
                 ),
                 
                  // Sticky Action Dock
                 _buildStickyActionDock(),
              ],
            ),
            
            // Overlay for Initial Transcription
            if (_isLoading)
               const Positioned.fill(child: ProcessingOverlay()),

            // Overlay for AI Generation
            if (_isProcessing)
               const Positioned.fill(
                 child: ProcessingOverlay(
                   cyclingMessages: [
                      'Processing Note...',
                      'Consulting AI...',
                      'Structuring Note...',
                   ],
                 ),
               ),
          ],
        ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text("Original Note", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                     color: Colors.green.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: Colors.green.withOpacity(0.3)),
                 ),
                 child: Text("READY", style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              // Use Raw Text Button
              InkWell(
                onTap: () {
                    Clipboard.setData(ClipboardData(text: _sourceController.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied raw text"), duration: Duration(seconds: 1)));
                },
                child: Text("Use Raw Text", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Collapsible Text View
          InkWell(
            onTap: () => setState(() => _isSourceExpanded = !_isSourceExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   _sourceController.text,
                   maxLines: _isSourceExpanded ? null : 3,
                   overflow: _isSourceExpanded ? null : TextOverflow.ellipsis,
                   style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.5),
                 ),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(_isSourceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: Colors.white38),
                   ],
                 )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTemplateSelectorCard() {
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
                 Text("Choose Template", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                 const Spacer(),
                 InkWell(
                   onTap: _showAllTemplates,
                   child: Text("All Templates", style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
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
                children: _macros.take(5).map((macro) {
                   final isSelected = _selectedMacro?.id == macro.id;
                   return Padding(
                     padding: const EdgeInsets.only(right: 8),
                     child: FilterChip(
                       label: Text(macro.trigger),
                       selected: isSelected,
                       onSelected: (bool selected) {
                          if (selected) _applyMacroWithAI(macro);
                       },
                       backgroundColor: const Color(0xFF2A2A2A),
                       selectedColor: AppTheme.accent.withOpacity(0.2),
                       checkmarkColor: AppTheme.accent,
                       labelStyle: GoogleFonts.inter(
                         fontSize: 13, 
                         color: isSelected ? AppTheme.accent : Colors.white70,
                         fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
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
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
               const SizedBox(width: 8),
               Text("Generated Note", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isProcessing)
             const SizedBox(height: 100) // Placeholder while overlay is active
          else
             TextField(
               controller: _finalController,
               maxLines: null,
               style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.6),
               decoration: const InputDecoration(
                 border: InputBorder.none,
                 isDense: true,
                 contentPadding: EdgeInsets.zero,
                 hintText: "AI generated note will appear here...",
                 hintStyle: TextStyle(color: Colors.white24)
               ),
               onTap: _handleTextFieldTap,
             ),
        ],
      ),
    );
  }

  Widget _buildStickyActionDock() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: ElevatedButton.icon(
            onPressed: () {
                 _copyCleanText();
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text("SMART COPY"),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
        ),
    );
  }
}
