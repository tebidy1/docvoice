import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import 'package:provider/provider.dart';
import '../../services/websocket_service.dart';
import 'dart:async';
import 'package:universal_io/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/groq_service.dart';
import '../../services/macro_service.dart';
import '../../services/gemini_service.dart';
import 'package:http/http.dart' as http; // For Web Blob fetching
import 'package:flutter/foundation.dart'; // For kIsWeb
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

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(text: widget.draftNote?.content ?? "");
    _finalController = TextEditingController(); // Initially empty until macro applied
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStandalone();
    });
  }

  Future<void> _initStandalone() async {
     final macroService = MacroService();
     final macros = await macroService.getMacros();
     
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
        
         // --- Web Logic ---
         if (kIsWeb) {
              // On Web, audio transcription not supported due to format incompatibility
              debugPrint("Web Audio Path: $path");
              if (mounted) {
                setState(() => _isLoading = false);
                _sourceController.text = "⚠️ Audio transcription is not supported on Web.\n\nPlease use Android or iOS for full transcription features.\n\nYou can still test the UI and macro generation.";
              }
              return;
         } 
         
         // --- Mobile Logic ---
         Uint8List? bytes;
         if (await File(path).exists()) {
              bytes = await File(path).readAsBytes();
         }

        // --- Processing ---
        if (bytes != null) {
            final prefs = await SharedPreferences.getInstance();
            final apiKey = prefs.getString('groq_api_key') ?? "";
            
            if (apiKey.isEmpty) {
               if (mounted) {
                 setState(() => _isLoading = false);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Set Groq API Key to Transcribe"), backgroundColor: Colors.orange));
               }
               return;
            }

             try {
                final groq = GroqService(apiKey: apiKey);
                final modelId = prefs.getString('groq_model') ?? 'whisper-large-v3';
                // NOTE: 'filename' param in transcribe might need to be "audio.wav" just for content-type inference
                final transcript = await groq.transcribe(bytes, filename: 'recording.wav', modelId: modelId);
                
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
    String apiKey = prefs.getString('gemini_api_key') ?? "";

    if (apiKey.isEmpty) {
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
      final gemini = GeminiService(apiKey: apiKey);
      final rawText = _sourceController.text;
      
      if (_useHighAccuracy) {
        // High Accuracy Mode: Detailed JSON with suggestions (Slower)
        final result = await gemini.formatTextWithSuggestions(
          rawText, 
          macroContext: macro.content,
          specialty: prefs.getString('specialty') ?? 'General Practice',
          globalPrompt: prefs.getString('global_ai_prompt') ?? ''
        );

        if (mounted) {
          if (result != null) {
            setState(() {
              _finalController.text = result['final_note'] ?? rawText;
              _suggestions = List<Map<String, dynamic>>.from(result['missing_suggestions'] ?? []);
            });
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Generation Failed. Please check API Key or Internet."), backgroundColor: Colors.red));
          }
        }
      } else {
        // Standard Mode: Text Only (Faster)
        final resultText = await gemini.formatText(
          rawText, 
          macroContext: macro.content,
          specialty: prefs.getString('specialty') ?? 'General Practice',
          globalPrompt: prefs.getString('global_ai_prompt') ?? ''
        );

        if (mounted) {
          setState(() {
            _finalController.text = resultText;
            _suggestions = []; // Clear suggestions in standard mode
          });
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
  void dispose() {
    _wsSubscription?.cancel();
    _sourceController.dispose();
    _finalController.dispose();
    super.dispose();
  }

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
                onPressed: _isProcessing ? null : () {
                  final ws = Provider.of<WebSocketService>(context, listen: false);
                  final contentToSend = _finalController.text.isNotEmpty ? _finalController.text : _sourceController.text;
                  
                  if (ws.isConnected) {
                    ws.sendMessage("SAVE_NOTE:$contentToSend");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent to Desktop Inbox 📥"), backgroundColor: AppTheme.successGreen));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Locally Only"), backgroundColor: Colors.orange));
                  }
                  Navigator.pop(context, contentToSend);
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
            bottom: (MediaQuery.of(context).size.height * 0.20) + 10, // Just above initial sheet height
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
      return Center(
        child: InkWell(
          onTap: () => setState(() => _useHighAccuracy = !_useHighAccuracy),
          borderRadius: BorderRadius.circular(20),
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
             decoration: BoxDecoration(
               color: Colors.black54, // Very subtle background for readability
               borderRadius: BorderRadius.circular(20),
             ),
             child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _useHighAccuracy ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _useHighAccuracy ? AppTheme.accent : Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  "Suggestions for missing", 
                  style: GoogleFonts.inter(
                    color: _useHighAccuracy ? Colors.white : Colors.white70, 
                    fontSize: 12,
                    fontWeight: FontWeight.w500
                  )
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildExpandableMacroPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.20, 
      minChildSize: 0.16,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF181818), 
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -5))]
          ),
          child: Column( // Use Column instead of SingleScrollView as root for sticky header behavior if needed
            children: [
               const SizedBox(height: 8),
               // Handle
               Center(
                child: Container(
                  width: 32, height: 4, 
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))
                ),
              ),
              const SizedBox(height: 8),

              // Content List
              Expanded(
                child: _isSheetExpanded
                ? SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: _macros.map((m) => _buildMacroChip(m)).toList(),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: _macros.length,
                    separatorBuilder: (_,__) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return _buildMacroChip(_macros[index]);
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C), // Uniform color
          borderRadius: BorderRadius.circular(100), 
          border: Border.all(color: Colors.white12), // Standard border
        ),
        child: Text(
          m.trigger, 
          style: GoogleFonts.inter(
            color: Colors.white70, // Uniform text color
            fontSize: 12, 
            fontWeight: FontWeight.w500
          )
        ),
      ),
    );
  }
}
