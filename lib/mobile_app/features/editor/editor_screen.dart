import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
// App Widgets & Services
import '../../../widgets/pattern_highlight_controller.dart';
import '../../../widgets/processing_overlay.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import '../../models/generated_output.dart';
import '../../services/inbox_service.dart';
import '../../services/macro_service.dart';
import '../../services/whisper_local_stub.dart'
    if (dart.library.io) '../../services/whisper_local_service.dart';
import '../../services/model_download_service.dart';
import '../../../services/api_service.dart';
import '../../services/groq_service.dart'; // Direct Groq for faster Web transcription
import '../../../core/ai/ai_regex_patterns.dart';
import '../../../core/ai/text_processing_service.dart';
import '../../../services/ai/ai_processing_service.dart';
import '../../../../core/medical_departments.dart';
import '../../../../services/department_service.dart';
import '../../../../web_extension/services/extension_injection_service.dart';
import '../../../../features/multimodal_ai/multimodal_ai_service.dart';
import '../../../../features/multimodal_ai/ai_studio_multimodal_service.dart';
import '../../../core/ai/ai_prompt_constants.dart';


class EditorScreen extends StatefulWidget {
  final NoteModel? draftNote;
  final Future<String>? oracleTranscriptFuture;
  final int noteNumber;
  final String? oneShotAudioPath; // ⚡ Non-null = Gemini One-Shot mode
  
  const EditorScreen({super.key, this.draftNote, this.oracleTranscriptFuture, this.noteNumber = 0, this.oneShotAudioPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Controllers
  late TextEditingController _sourceController; // Top: Raw Transcript
  late TextEditingController _finalController;  // Bottom: Final Note
  
  List<MacroModel> _macros = []; 
  MacroModel? _selectedMacro; // Track selected template 
  StreamSubscription? _wsSubscription;
  late bool _isLoading; // Set dynamically in initState
  bool _isProcessing = false; // For AI generation
  List<Map<String, dynamic>> _suggestions = [];
  bool _isTemplateCardExpanded = true;  // Template card: expanded by default
  
  // Smart Tabs State
  int _activeTabIndex = 0; // 0 = Transcript, 1+ = Generated Outputs
  List<GeneratedOutput> _generatedOutputs = [];
  
  // ⚡ Gemini One-Shot mode
  bool _isOneShotMode = false;
  bool _isOneShotGenerating = false;
  final MultimodalAIService _multimodalService = AIStudioMultimodalService();

  // Auto-Save State
  int? _currentNoteId; // Track the cloud note ID for updates
  Timer? _debounceTimer; // For manual edit auto-save

  @override
  void initState() {
    super.initState();
    
    // ⚡ Detect Gemini One-Shot mode
    if (widget.oneShotAudioPath != null) {
      _isOneShotMode = true;
      _isLoading = false;         // No transcription needed
      _isTemplateCardExpanded = true;  // Open template picker directly

      if (widget.draftNote != null) {
        _currentNoteId = (widget.draftNote!.id > 0) ? widget.draftNote!.id : int.tryParse(widget.draftNote!.uuid);
        _generatedOutputs = List<GeneratedOutput>.from(widget.draftNote!.generatedOutputs);
      }

      // Initialize controllers (required by build())
      _sourceController = TextEditingController(text: "");
      _finalController = PatternHighlightController(
        text: "",
        patternStyles: {
          AIRegexPatterns.selectPlaceholderPattern:
              const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800), fontWeight: FontWeight.bold),
          AIRegexPatterns.anyBracketPattern:
              const TextStyle(color: Colors.orange, backgroundColor: Color(0x33FF9800)),
          AIRegexPatterns.headerPattern: const TextStyle(
            decoration: TextDecoration.underline, decorationColor: Colors.white,
            decorationThickness: 2.0, fontWeight: FontWeight.bold, color: Colors.white,
          ),
        },
      );
      _finalController.addListener(_onManualEdit);

      // Initialize note ID if available
      if (widget.draftNote != null) {
        _currentNoteId = (widget.draftNote!.id > 0) ? widget.draftNote!.id : int.tryParse(widget.draftNote!.uuid);
      }

      // Load macros then wait for user to pick a template
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final allMacros = await MacroService().getMacros();
        final prefs = await SharedPreferences.getInstance();
        final deptId = DepartmentService().value ?? prefs.getString('specialty');
        final allowedCategories = (deptId != null 
            ? MedicalDepartments.getRelevantCategories(deptId)
            : ['General']).map((c) => c.toLowerCase()).toList();

        final filteredMacros = allMacros.where((m) {
          final cleanCat = m.category.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
          final cats = cleanCat.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
          
          if (cats.isEmpty) return true;
          if (cats.any((c) => c == 'general' || c == 'general practice')) return true;
          return cats.any((c) => allowedCategories.contains(c));
        }).toList();

        if (mounted) setState(() => _macros = filteredMacros);
      });
      return;
    }

    final path = widget.draftNote?.audioPath;
    _isLoading = widget.oracleTranscriptFuture != null || (path != null && path.isNotEmpty);
    
    // Initialize ID if opening existing draft
    if (widget.draftNote != null) {
      // Prefer server ID if valid (> 0), otherwise fallback to UUID parsing
      _currentNoteId = (widget.draftNote!.id > 0) ? widget.draftNote!.id : int.tryParse(widget.draftNote!.uuid);
      _generatedOutputs = List<GeneratedOutput>.from(widget.draftNote!.generatedOutputs);
    }

    // Load Content
    // Source: Original raw text
    _sourceController = TextEditingController(text: widget.draftNote?.originalText ?? widget.draftNote?.content ?? "");
    
    // Final: Formatted text if exists
    // Use PatternHighlightController with centralized AIRegexPatterns
    _finalController = PatternHighlightController(
      text: widget.draftNote?.formattedText ?? "",
      patternStyles: {
        // Orange for [ Select ] — highest priority
        AIRegexPatterns.selectPlaceholderPattern:
            const TextStyle(
                color: Colors.orange,
                backgroundColor: Color(0x33FF9800),
                fontWeight: FontWeight.bold),
        // Orange for any remaining [bracket] placeholder
        AIRegexPatterns.anyBracketPattern:
            const TextStyle(
                color: Colors.orange,
                backgroundColor: Color(0x33FF9800)),
        // Bold underlined WHITE for SECTION HEADERS (e.g. SUBJECTIVE:)
        AIRegexPatterns.headerPattern: const TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          decorationThickness: 2.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      },
    );

    if (_generatedOutputs.isNotEmpty) {
      _isTemplateCardExpanded = false;
      _activeTabIndex = _generatedOutputs.length; // Select the latest generated map
      _finalController.text = _generatedOutputs.last.content ?? "";
    } else if (widget.draftNote != null && widget.draftNote!.formattedText.isNotEmpty) {
      // Legacy compatibility: migrate formattedText to a generated output
      final legacyTemplateName = widget.draftNote!.summary ?? 'Legacy Note';
      _generatedOutputs.add(GeneratedOutput(title: legacyTemplateName, content: widget.draftNote!.formattedText));
      _activeTabIndex = 1;
      _finalController.text = widget.draftNote!.formattedText;
      _isTemplateCardExpanded = false;
    } else {
      _isTemplateCardExpanded = true;
      _finalController.text = _sourceController.text; // Default to transcript if nothing generated
    }
    
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

  /// ⚡ Gemini One-Shot: read audio file bytes → processAudioNote → display result
  Future<void> _applyOneShotAI(MacroModel macro) async {
    final audioPath = widget.oneShotAudioPath ?? widget.draftNote?.audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚡ No audio file available for One-Shot AI.'), backgroundColor: Colors.red));
        setState(() => _isOneShotGenerating = false);
      }
      return;
    }
    setState(() => _isOneShotGenerating = true);

    try {
      // ── Load audio bytes: Web → fetch blob URL, Native → read local file ──
      Uint8List audioBytes;
      String mimeType;

      if (kIsWeb) {
        // PWA: stopRecording() returns a blob:// URL — fetch it via HTTP
        final response = await http.get(Uri.parse(audioPath));
        if (response.statusCode != 200) {
          throw Exception('Failed to fetch audio blob (${response.statusCode})');
        }
        audioBytes = response.bodyBytes;
        mimeType = 'audio/webm'; // Chrome/Chromium records as WebM/Opus
      } else {
        // Android: audioPath is a local file path
        final audioFile = File(audioPath);
        if (!audioFile.existsSync()) throw Exception('Audio file not found: $audioPath');
        audioBytes = await audioFile.readAsBytes();
        final ext = audioPath.toLowerCase();
        mimeType = ext.endsWith('.mp3') ? 'audio/mp3'
            : ext.endsWith('.m4a') ? 'audio/m4a'
            : ext.endsWith('.ogg') ? 'audio/ogg'
            : 'audio/wav';
      }

      // Load AI context from SharedPreferences (same as extension)
      final prefs = await SharedPreferences.getInstance();
      final result = await _multimodalService.processAudioNote(
        audioBytes: audioBytes,
        mimeType: mimeType,
        macroContent: macro.content,
        specialty: await AIProcessingService.getEffectiveSpecialty(),
        globalPrompt: prefs.getString('global_ai_prompt') ?? AIPromptConstants.globalMasterPrompt,
      );

      if (mounted) {
        if (result.success) {
          setState(() {
            _selectedMacro = macro;
            _generatedOutputs.add(GeneratedOutput(title: macro.trigger, content: result.formattedNote));
            _activeTabIndex = _generatedOutputs.length;
            _finalController.text = result.formattedNote;
            _isTemplateCardExpanded = false;
            _isOneShotGenerating = false;
          });
          
          if (_currentNoteId == null) {
            try {
              final inboxService = InboxService();
              final noteId = await inboxService.addNote(
                'لا يوجد نص اصلي عند اختيار هذا النموذج',
                patientName: macro.trigger,
                audioPath: widget.oneShotAudioPath,
              );
              setState(() => _currentNoteId = noteId);
              
              await inboxService.updateNote(
                noteId,
                rawText: 'لا يوجد نص اصلي عند اختيار هذا النموذج',
                formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content ?? '' : '',
                generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
                suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
                summary: macro.trigger,
                patientName: macro.trigger,
              );
            } catch (e) {
              debugPrint('❌ Auto-save new note failed: $e');
            }
          } else {
            await _saveDraftUpdate();
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('⚡ One-Shot complete (${result.providerName})', style: const TextStyle(fontSize: 13))),
            ]),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
          ));
        } else {
          setState(() => _isOneShotGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('⚡ One-Shot failed: ${result.errorMessage}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOneShotGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Gemini One-Shot error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onManualEdit() {
    // Only auto-save if we have a draft ID
    if (_currentNoteId == null) return;

    // Save content to active tab
    if (_activeTabIndex == 0) {
      _sourceController.text = _finalController.text;
    } else if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
      _generatedOutputs[_activeTabIndex - 1].content = _finalController.text;
    }

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
        rawText: _sourceController.text.isNotEmpty ? _sourceController.text : 'لا يوجد نص اصلي عند اختيار هذا النموذج', // REQUIRED by backend
        formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '', // Legacy fallback
        generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
        // We persist the original transcript too if needed
      );
      debugPrint("📝 Auto-saved manual edits to cloud");
    } catch (e) {
      debugPrint("❌ Auto-save failed: $e");
    }
  }

  Future<void> _initStandalone() async {
     final macroService = MacroService();
     final allMacros = await macroService.getMacros();
     
     final prefs = await SharedPreferences.getInstance();
     final deptId = DepartmentService().value ?? prefs.getString('specialty');
     final allowedCategories = (deptId != null 
         ? MedicalDepartments.getRelevantCategories(deptId)
         : ['General']).map((c) => c.toLowerCase()).toList();

     final macros = allMacros.where((m) {
       final cleanCat = m.category.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "");
       final cats = cleanCat.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
       if (cats.isEmpty) return true;
       if (cats.any((c) => c == 'general' || c == 'general practice')) return true;
       return cats.any((c) => allowedCategories.contains(c));
     }).toList();
     
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
              _isTemplateCardExpanded = false;
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

       // Restore selected macro from draft and move to front
       MacroModel? restoredMacro;
       if (widget.draftNote != null && widget.draftNote!.appliedMacroId != null) {
          try {
             restoredMacro = macros.firstWhere((m) => m.id == widget.draftNote!.appliedMacroId);
             macros.remove(restoredMacro);
             macros.insert(0, restoredMacro);
          } catch (e) {
             debugPrint("Could not restore selected macro: $e");
          }
       }

       setState(() {
         _macros = macros;
         if (restoredMacro != null) _selectedMacro = restoredMacro;
       });
     }

     final path = widget.draftNote?.audioPath;
     final oracleFuture = widget.oracleTranscriptFuture;

     // ── Oracle Live Speech: transcript arrives via Future ───────────────
     if (oracleFuture != null) {
       try {
         final transcript = await oracleFuture;
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
           } else {
             _sourceController.text = "";
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text('No speech detected by Oracle'),
                   backgroundColor: Colors.orange,
                 ),
               );
             }
           }
         }
       } catch (e) {
         debugPrint("Oracle transcript error: $e");
         if (mounted) {
           setState(() => _isLoading = false);
           _sourceController.text = "❌ Oracle transcription error: $e";
         }
       }
       return;
     }

     // ── Groq / file-based STT flow ─────────────────────────────────────
     if (path != null && path.isNotEmpty) {
         
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
         if (path.isNotEmpty) {
              try {
                final prefs = await SharedPreferences.getInstance();
                final sttEngine = prefs.getString('stt_engine_pref') ?? 'oracle_live';
                
                // ⚡ Skip STT transcription entirely if in Gemini One-Shot mode
                if (sttEngine == 'gemini_oneshot') {
                  if (mounted) {
                    setState(() {
                       _isOneShotMode = true;
                       _isLoading = false;
                       _isTemplateCardExpanded = true;
                    });
                  }
                  return;
                }
                
                String transcript = "";
                
                if (sttEngine == 'whisper_local' && !kIsWeb) {
                    // --- Whisper Local On-Device Transcription ---
                    debugPrint("🎙️ Using Whisper Local STT");
                    
                    // Check if model is downloaded
                    final downloadService = ModelDownloadService();
                    if (!await downloadService.isModelReady()) {
                      // Show download dialog
                      if (!mounted) return;
                      final shouldDownload = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => _ModelDownloadDialog(),
                      );
                      if (shouldDownload != true) {
                        setState(() { _isProcessing = false; });
                        return;
                      }
                    }
                    
                    final whisperService = WhisperLocalService();
                    transcript = await whisperService.transcribeAudioUrl(path);
                    
                    if (transcript.startsWith('Error')) {
                        throw Exception(transcript);
                    }
                } else {
                    // --- Cloud Transcription (Groq) ---
                    if (bytes != null) {
                        // ⚡ STRATEGY: On Web, call Groq DIRECTLY for speed.
                        // Backend proxy adds a full network round-trip + possible transcoding.
                        // Direct call: Browser→Groq (fast)
                        // Backend proxy: Browser→Backend→Groq→Backend→Browser (slow)
                        bool transcribed = false;
                        
                        if (kIsWeb) {
                          final prefs2 = await SharedPreferences.getInstance();
                          final localGroqKey = prefs2.getString('groq_api_key') ?? 
                              (dotenv.isInitialized ? dotenv.env['GROQ_API_KEY'] ?? '' : '');
                          
                          if (localGroqKey.isNotEmpty) {
                            debugPrint("⚡ Web: Using Direct Groq API (fast path)");
                            final groqService = GroqService(apiKey: localGroqKey);
                            final directResult = await groqService.transcribe(bytes, filename: 'recording.webm');
                            
                            if (!directResult.startsWith('Error')) {
                              transcript = directResult;
                              transcribed = true;
                            } else {
                              debugPrint("⚠️ Direct Groq failed: $directResult. Falling back to backend proxy.");
                            }
                          }
                        }
                        
                        // Fallback: Backend Proxy (for Mobile, or if Direct Groq failed)
                        if (!transcribed) {
                          debugPrint("☁️ Using Backend Proxy for STT");
                          final apiService = ApiService();
                          final result = await apiService.multipartPost(
                            '/audio/transcribe',
                            fileBytes: bytes,
                            filename: kIsWeb ? 'recording.webm' : 'recording.wav',
                          );

                          if (result['status'] == true) {
                            transcript = result['payload']['text'] ?? "";
                          } else {
                            throw Exception(result['message'] ?? 'Transcription failed');
                          }
                        }
                    } else {
                        throw Exception("No audio bytes available for Cloud STT.");
                    }
                }

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
              } catch (e) {
                debugPrint("Transcription Error: $e");
                if (mounted) {
                  setState(() => _isLoading = false);
                  _sourceController.text = "❌ Transcription error: $e";
                }
              }
         } else {
             debugPrint("No audio path found to transcribe.");
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
      _isTemplateCardExpanded = false;   // Collapse template card
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
      // ✅ Use AIProcessingService — centralized AI call (Phase 1 refactor)
      final aiService = AIProcessingService();
      final mode = await AIProcessingService.getEffectiveMode();
      
      final result = await aiService.processNote(
        transcript: _sourceController.text,
        macroContent: macro.content,
        mode: mode,
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _generatedOutputs.add(GeneratedOutput(title: macro.trigger, content: result.formattedNote));
            _activeTabIndex = _generatedOutputs.length;
            _finalController.text = result.formattedNote;
            _suggestions = result.missingSuggestions;
          });

          // 5. AUTO-SAVE: Update existing note or create new one
          try {
            final inboxService = InboxService();
            if (_currentNoteId != null) {
              await inboxService.updateNote(
                _currentNoteId!,
                rawText: _sourceController.text,
                formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '',
                generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
                suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
                summary: macro.trigger, // Changed to summary for template name badge
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
                formattedText: _generatedOutputs.isNotEmpty ? _generatedOutputs.last.content : '',
                generatedOutputs: _generatedOutputs.map((e) => e.toJson()).toList(),
                suggestedMacroId: int.tryParse(macro.id.toString()) ?? 0,
                summary: macro.trigger, // Changed to summary for template name badge
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
        throw result.errorMessage ?? 'Processing failed';
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
    if (selection.baseOffset < 0) return;

    // ✅ Use TextProcessingService.findPlaceholderAtCursor (Phase 1 refactor)
    final placeholder = TextProcessingService.findPlaceholderAtCursor(
        text, selection.baseOffset);

    if (placeholder != null) {
      _finalController.selection = TextSelection(
        baseOffset: placeholder.start,
        extentOffset: placeholder.end,
      );
    }
  }

  void _copyCleanText() async {
    final text = _activeTabIndex == 0 ? _sourceController.text : _finalController.text;
    if (text.isEmpty) return;

    if (kIsWeb) {
        // Use the centralized Extension Injection Service
        final result = await ExtensionInjectionService.smartCopyAndInject(text);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.message),
              backgroundColor: result.status == InjectionStatus.success ? Colors.green : Colors.blue,
              duration: const Duration(seconds: 2),
           ));
        }
    } else {
        // ✅ Use TextProcessingService.applySmartCopy (Phase 1 refactor)
        // FIXED: No longer deletes entire lines — removes only placeholder tokens
        final placeholderCount = TextProcessingService.countPlaceholders(text);
        final cleanText = TextProcessingService.applySmartCopy(text);

        await Clipboard.setData(ClipboardData(text: cleanText));

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
                        const Text("✅ Smart Copy Active",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          placeholderCount > 0
                              ? "Copied without $placeholderCount placeholder token(s)."
                              : "Copied — note is complete, no placeholders found.",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
    }
    
    // Auto-update status to COPIED if we have a draft ID
    if (_currentNoteId != null) {
        try {
            await InboxService().updateStatus(_currentNoteId!, NoteStatus.copied);
        } catch(e) {
            debugPrint("Failed to update status to copied: $e");
        }
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





  // _showAllTemplates() removed to show inline instead

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.noteNumber > 0 ? 'NO-${widget.noteNumber}' : 'Draft Note',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                           _buildTemplateSelectorCard(),
                           const SizedBox(height: 16),
                           _buildSmartTabsEditorCard(),
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
                      'جاري معالجة الملاحظة...',
                      'التواصل مع الذكاء الاصطناعي...',
                      'تنسيق وهيكلة الملاحظة...',
                   ],
                 ),
               ),

            // ⚡ One-Shot Overlay
            if (_isOneShotGenerating)
               const Positioned.fill(
                 child: ProcessingOverlay(
                   cyclingMessages: [
                      '⚡ إرسال الصوت إلى Gemini...',
                      '⚡ تحليل الصوت والقالب...',
                      '⚡ توليد الملاحظة الطبية...',
                      '⚡ تنسيق النتيجة النهائية...',
                   ],
                 ),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartTabsEditorCard() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _activeTabIndex > 0
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: _activeTabIndex > 0 ? 1.5 : 1.0,
        ),
        boxShadow: _activeTabIndex > 0 ? [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tab Bar Header ──
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 1 + _generatedOutputs.length,
              itemBuilder: (context, index) {
                final isSelected = index == _activeTabIndex;
                final title = index == 0 ? "Transcript" : (_generatedOutputs[index - 1].title ?? "Note $index");
                final icon = index == 0 ? Icons.description_outlined : Icons.bolt;
                
                return InkWell(
                  onTap: () {
                    if (isSelected) return;
                    _switchTab(index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      color: isSelected ? colorScheme.primary.withValues(alpha: 0.05) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        if (index > 0) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _deleteTab(index),
                            child: Icon(Icons.close, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ── Editor Area ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isProcessing
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : TextField(
                    controller: _activeTabIndex == 0 ? _sourceController : _finalController,
                    maxLines: null,
                    minLines: 5,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: _activeTabIndex == 0 ? "Transcript empty..." : "AI generated note will appear here...",
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                    onTap: _activeTabIndex == 0 ? null : _handleTextFieldTap,
                  ),
          ),
          
          if (_activeTabIndex > 0 && _suggestions.isNotEmpty)
             _buildSuggestionsArea(),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    setState(() {
      // Save current selection text back to the array before switching
      if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
         _generatedOutputs[_activeTabIndex - 1].content = _finalController.text;
      }

      _activeTabIndex = index;
      
      // Load new text
      if (_activeTabIndex > 0 && _activeTabIndex <= _generatedOutputs.length) {
         _finalController.text = _generatedOutputs[_activeTabIndex - 1].content ?? "";
      }
    });
  }

  void _deleteTab(int index) {
    if (index > 0 && index <= _generatedOutputs.length) {
      setState(() {
        _generatedOutputs.removeAt(index - 1);
        if (_activeTabIndex >= index) {
           _switchTab(_activeTabIndex - 1);
        }
      });
      _onManualEdit(); // Trigger auto-save
    }
  }

  Widget _buildTemplateSelectorCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTemplateCardExpanded
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: _isTemplateCardExpanded ? 1.5 : 1.0,
        ),
        boxShadow: _isTemplateCardExpanded ? [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
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
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                   Text(
                      _isOneShotMode ? "⚡ Choose Template (One-Shot)" : "Choose Template",
                      style: GoogleFonts.inter(
                       fontSize: 16,
                       fontWeight: FontWeight.w600,
                       color: _isOneShotMode ? Colors.amber : colorScheme.onSurface,
                     ),
                   ),
                  // Show selected macro name when collapsed
                  if (!_isTemplateCardExpanded && _selectedMacro != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedMacro!.trigger,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else const Spacer(),
                  // Just a standard arrow icon showing state
                  Icon(
                    _isTemplateCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
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
                  children: _macros.map((macro) {
                    final isSelected = _selectedMacro?.id == macro.id;
                       return FilterChip(
                        label: Text(macro.trigger),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) {
                            if (_isOneShotMode) {
                              _applyOneShotAI(macro);
                            } else {
                              _applyMacroWithAI(macro);
                            }
                          }
                        },
                        backgroundColor: colorScheme.surface,
                        selectedColor: _isOneShotMode
                            ? Colors.amber.withValues(alpha: 0.15)
                            : colorScheme.primary.withValues(alpha: 0.15),
                        checkmarkColor: _isOneShotMode ? Colors.amber : colorScheme.primary,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected
                              ? (_isOneShotMode ? Colors.amber : colorScheme.primary)
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? (_isOneShotMode ? Colors.amber : colorScheme.primary)
                                : colorScheme.outline.withValues(alpha: 0.4),
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
  Widget _buildSuggestionsArea() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2))),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "AI Suggestions (${_suggestions.length})",
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return ActionChip(
                label: Text(
                  suggestion['field_name'] ?? 'Suggestion',
                  style: GoogleFonts.inter(fontSize: 11, color: colorScheme.primary),
                ),
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
                onPressed: () => _insertSuggestion(suggestion),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionDock() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4), width: 1)),
        ),
        child: ElevatedButton.icon(
            onPressed: () {
                 _copyCleanText();
            },
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text("SMART COPY / INJECT"),
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Model Download Dialog (shown when Whisper model is not installed)
// ─────────────────────────────────────────────────────────────
class _ModelDownloadDialog extends StatefulWidget {
  @override
  _ModelDownloadDialogState createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _currentFile = '';
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      await ModelDownloadService().downloadModel(
        onProgress: (downloaded, total, fileName) {
          if (mounted) {
            setState(() {
              _progress = total > 0 ? downloaded / total : 0.0;
              _currentFile = fileName;
            });
          }
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Speech Model Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_downloading && _error == null)
            const Text(
              'The offline speech recognition model (~245 MB) needs to be downloaded. This is a one-time download.',
            ),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}% — $_currentFile',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        if (!_downloading)
          ElevatedButton(
            onPressed: _startDownload,
            child: Text(_error != null ? 'Retry' : 'Download'),
          ),
      ],
    );
  }
}
