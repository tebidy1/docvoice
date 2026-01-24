import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../services/macro_service.dart';

class MacroEditorScreen extends StatefulWidget {
  final MacroModel? macro; // If null, we are creating a new one

  const MacroEditorScreen({super.key, this.macro});

  @override
  State<MacroEditorScreen> createState() => _MacroEditorScreenState();
}

class _MacroEditorScreenState extends State<MacroEditorScreen> {
  final _triggerCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: "General");
  bool _isFavorite = false;
  
  final _macroService = MacroService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.macro != null) {
      _triggerCtrl.text = widget.macro!.trigger;
      _contentCtrl.text = widget.macro!.content;
      _categoryCtrl.text = widget.macro!.category;
      _isFavorite = widget.macro!.isFavorite;
    }
  }

  Future<void> _save() async {
    if (_triggerCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a trigger name")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.macro != null) {
        // Edit Mode
        widget.macro!.trigger = _triggerCtrl.text;
        widget.macro!.content = _contentCtrl.text;
        widget.macro!.category = _categoryCtrl.text;
        widget.macro!.isFavorite = _isFavorite;
        await _macroService.updateMacro(widget.macro!);
      } else {
        // Create Mode
        final newMacro = MacroModel(
          id: const Uuid().v4(),
          trigger: _triggerCtrl.text,
          content: _contentCtrl.text,
          category: _categoryCtrl.text,
          isFavorite: _isFavorite,
        );
        await _macroService.addMacro(newMacro);
      }
      
      if (mounted) Navigator.pop(context, true); // Return true to indicate refresh needed
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.macro == null ? "New Macro" : "Edit Macro", 
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.white24,
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
            tooltip: 'Favorite',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
              : TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                  ),
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trigger Name + Category Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TRIGGER NAME", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _triggerCtrl,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "e.g., ⚡ SOAP",
                          hintStyle: TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: const Icon(Icons.flash_on, color: AppTheme.accent, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("CATEGORY", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _categoryCtrl,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "General",
                          hintStyle: TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Text("CONTENT / PROMPT", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4), // Padding around the scrollbar
                child: TextField(
                  controller: _contentCtrl,
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 14, height: 1.5), // Monospace best for prompts
                  maxLines: null,
                  expands: true, // Fills the remaining space!
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: "Enter the macro text or AI prompt here...",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
