import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import 'package:provider/provider.dart';
import '../../services/websocket_service.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/groq_service.dart';
import '../../services/macro_service.dart';
import '../../services/gemini_service.dart';

class EditorScreen extends StatefulWidget {
  final NoteModel? draftNote;
  
  const EditorScreen({super.key, this.draftNote});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _controller;
  bool _isKeyboardVisible = false;
  List<MacroModel> _macros = []; // Real macros from Service
  StreamSubscription? _wsSubscription;
  bool _isLoading = true; // For initial transcription
  bool _isProcessing = false; // For AI generation
  List<Map<String, dynamic>> _suggestions = [];
  
  // Settings State
  bool _smartMode = true; 

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draftNote?.content ?? "");
    
    // Start Standalone Process
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStandalone();
    });
  }

  Future<void> _initStandalone() async {
     // 1. Load Local Macros (Standalone)
     final macroService = MacroService();
     final macros = await macroService.getMacros();
     
     // 2. Load Settings
     final prefs = await SharedPreferences.getInstance();
     final startInSmartMode = prefs.getBool('smart_mode_enabled') ?? true;

     if (mounted) {
       setState(() {
         _macros = macros;
         _smartMode = startInSmartMode;
       });
     }

     // 3. Transcribe Audio Locally (if audio exists)
     final path = widget.draftNote?.audioPath;
     if (path != null && File(path).existsSync()) {
        final apiKey = prefs.getString('groq_api_key') ?? "";
        
        if (apiKey.isEmpty) {
           if (mounted) {
             setState(() => _isLoading = false);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Set Groq API Key in Settings to Transcribe"), backgroundColor: Colors.orange));
           }
           return;
        }

        try {
           final file = File(path);
           final bytes = await file.readAsBytes();
           
           final groq = GroqService(apiKey: apiKey);
           final transcript = await groq.transcribe(bytes, filename: 'recording.wav');
           
           if (mounted) {
             setState(() => _isLoading = false);
             if (transcript.startsWith("Error:")) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(transcript), backgroundColor: AppTheme.recordRed));
             } else {
                // Filter Hallucinations
                final cleanText = transcript.trim();
                if (cleanText.toLowerCase() == "thank you." || cleanText.isEmpty || cleanText.toLowerCase() == "mbc news") {
                   _controller.text = ""; // Empty implies wait for user input
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No speech detected"), backgroundColor: Colors.orange));
                } else {
                   _controller.text = cleanText;
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transcribed!"), backgroundColor: AppTheme.successGreen));
                }
             }
           }

        } catch (e) {
           debugPrint("Transcription Error: $e");
           if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.recordRed));
           }
        }
     } else {
       // No audio to process
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _applyMacroWithAI(MacroModel macro) async {
    if (!_smartMode) {
      // FAST MODE: Just append/replace text
      final content = macro.content;
      final text = _controller.text;
      _controller.text = "$text\n$content";
      return;
    }

    // SMART MODE: Call Gemini
    setState(() {
      _isProcessing = true;
      _suggestions = []; // Clear old suggestions
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      // NOTE: Using a hardcoded fallback or user setting for Gemini Key
      // Ideally this comes from settings_screen.dart
      String apiKey = prefs.getString('gemini_api_key') ?? "";
      
      // Fallback for demo if user hasn't set it (DANGEROUS but allowed for now if user provided it elsewhere)
      // If empty, service handles it by returning raw text
      
      final gemini = GeminiService(apiKey: apiKey);
      final rawText = _controller.text;
      
      final result = await gemini.formatTextWithSuggestions(
        rawText, 
        macroContext: macro.content,
        specialty: prefs.getString('specialty') ?? 'General Practice',
        globalPrompt: prefs.getString('global_ai_prompt') ?? ''
      );

      if (mounted && result != null) {
        setState(() {
          _controller.text = result['final_note'] ?? rawText;
          _suggestions = List<Map<String, dynamic>>.from(result['missing_suggestions'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _insertSuggestion(Map<String, dynamic> suggestion) {
    final textToInsert = suggestion['text_to_insert'] as String;
    final currentText = _controller.text;
    _controller.text = "$currentText\n$textToInsert";
    
    // Remove from list
    setState(() {
      _suggestions.remove(suggestion);
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = bottomInset > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        title: Row(
          children: [
            Text("Pocket Editor", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            if (_isProcessing) ...[
              const SizedBox(width: 10),
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              )
            ]
          ],
        ),
        actions: [
          // Smart Mode Toggle
          Switch(
            value: _smartMode, 
            activeColor: AppTheme.accent,
            onChanged: (val) {
              setState(() => _smartMode = val);
              SharedPreferences.getInstance().then((p) => p.setBool('smart_mode_enabled', val));
            }
          ),
          // Ready Button
          Container(
            margin: const EdgeInsets.only(right: 16, left: 8),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () {
                final ws = Provider.of<WebSocketService>(context, listen: false);
                if (ws.isConnected) {
                  ws.sendMessage("SAVE_NOTE:${_controller.text}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sent to Desktop Inbox 📥"), backgroundColor: AppTheme.successGreen),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Offline: Saved Locally Only"), backgroundColor: Colors.orange),
                  );
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check, size: 16, color: Colors.black),
              label: const Text("Ready", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          _isLoading 
            ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for bars
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.merriweather(fontSize: 16, color: Colors.white, height: 1.6),
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: "Start typing or select a macro...",
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
          
          // Suggestions Bar (Floating above Accessory Bar)
          if (_suggestions.isNotEmpty)
            Positioned(
              left: 0, right: 0,
              bottom: (_isKeyboardVisible ? 0 : 0) + 50, // Height of accessory bar
              child: Container(
                height: 40,
                color: Colors.black54,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return ActionChip(
                      label: Text(s['label'], style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _insertSuggestion(s),
                    );
                  },
                ),
              ),
            ),

          // Accessory Bar
          Positioned(
             left: 0, right: 0,
             bottom: _isKeyboardVisible ? 0 : 0, 
             child: _buildAccessoryBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoryBar() {
    if (_macros.isEmpty) {
       return Container(
        height: 50, 
        color: const Color(0xFF1E1E1E),
        alignment: Alignment.center,
        child: const Text("No Macros Found", style: TextStyle(color: Colors.grey)),
       );
    }

    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _macros.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final m = _macros[index];
          return ActionChip(
            avatar: const Icon(Icons.flash_on, size: 14, color: AppTheme.accent),
            label: Text(m.trigger),
            labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _applyMacroWithAI(m), // Call AI Logic
          );
        },
      ),
    );
  }
}
