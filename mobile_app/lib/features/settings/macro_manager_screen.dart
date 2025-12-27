import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../services/macro_service.dart';

class MacroManagerScreen extends StatefulWidget {
  const MacroManagerScreen({super.key});

  @override
  State<MacroManagerScreen> createState() => _MacroManagerScreenState();
}

class _MacroManagerScreenState extends State<MacroManagerScreen> {
  final MacroService _service = MacroService();
  List<MacroModel> _macros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMacros();
  }

  Future<void> _loadMacros() async {
    setState(() => _isLoading = true);
    final data = await _service.getMacros();
    setState(() {
      _macros = data;
      _isLoading = false;
    });
  }

  void _showEditor({MacroModel? macro}) {
    final isEditing = macro != null;
    final triggerCtrl = TextEditingController(text: macro?.trigger ?? "");
    final contentCtrl = TextEditingController(text: macro?.content ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? "Edit Macro" : "New Macro", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            
            // Trigger Field
            TextField(
              controller: triggerCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Trigger Name (e.g., ⚡ SOAP)",
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Content Field
            TextField(
              controller: contentCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Content",
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (triggerCtrl.text.isEmpty) return;
                    
                    if (isEditing) {
                      macro!.trigger = triggerCtrl.text;
                      macro.content = contentCtrl.text;
                      await _service.updateMacro(macro);
                    } else {
                      final newMacro = MacroModel(
                        id: const Uuid().v4(),
                        trigger: triggerCtrl.text,
                        content: contentCtrl.text
                      );
                      await _service.addMacro(newMacro);
                    }
                    
                    if (mounted) Navigator.pop(ctx);
                    _loadMacros();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Save"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Macro Manager", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        backgroundColor: AppTheme.accent, // Using Blue as per design
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _macros.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = _macros[index];
              return Dismissible(
                key: Key(m.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppTheme.recordRed,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text("Delete Macro?", style: TextStyle(color: Colors.white)),
                      content: Text("Are you sure you want to delete '${m.trigger}'?",  style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                      ],
                    )
                  );
                },
                onDismissed: (_) async {
                  await _service.deleteMacro(m.id);
                  _loadMacros(); // Refresh list to be safe
                },
                child: Card(
                  color: AppTheme.surface,
                  child: ListTile(
                    title: Text(m.trigger, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      m.content.replaceAll('\n', ' '), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54)
                    ),
                    trailing: const Icon(Icons.edit, color: Colors.white30, size: 20),
                    onTap: () => _showEditor(macro: m),
                  ),
                ),
              );
            },
          ),
    );
  }
}
