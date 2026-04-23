import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../mobile_app/core/theme.dart';
import '../../mobile_app/core/entities/note_model.dart';
import '../../mobile_app/data/repositories/inbox_service.dart';
import '../../mobile_app/data/repositories/macro_service.dart';
import 'extension_editor_screen.dart'; // Correct Import
import '../../mobile_app/features/inbox/archive_screen.dart'; // Reuse Mobile Archive
import '../../mobile_app/core/utils/date_helper.dart';
import '../data/repositories/extension_injection_service.dart';

class ExtensionInboxScreen extends StatefulWidget {
  const ExtensionInboxScreen({super.key});

  @override
  State<ExtensionInboxScreen> createState() => ExtensionInboxScreenState();
}

class ExtensionInboxScreenState extends State<ExtensionInboxScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<NoteModel> _notes = []; // Active Notes
  final List<NoteModel> _archivedNotes = []; // Archived Notes
  final _macroService = MacroService();
  List<MacroModel> _allMacros = [];

  @override
  void initState() {
    super.initState();
    _loadMacros();
    // Initial Mock Data (Same as before)
    _notes.addAll([
      NoteModel()..title="Patient H.M."..content="History of amnesia..."..status=NoteStatus.processed..createdAt=DateTime.now().subtract(const Duration(minutes: 5)),
      NoteModel()..title="Follow-up: Sarah J."..content="Prescription renewal..."..status=NoteStatus.ready..createdAt=DateTime.now().subtract(const Duration(hours: 1)),
      NoteModel()..title="Dr. Notes"..content="Staff meeting at 5 PM"..status=NoteStatus.draft..createdAt=DateTime.now().subtract(const Duration(days: 1)),
    ]);
  }
  Future<void> _loadMacros() async {
    final all = await _macroService.getMacros();
    if (mounted) setState(() => _allMacros = all);
  }

  void addNote(NoteModel note) {
    _notes.insert(0, note);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 600));
  }

  Future<void> _copyAndMarkCopied(NoteModel note) async {
    final rawText = note.formattedText.isNotEmpty ? note.formattedText : note.content;
    
    final result = await ExtensionInjectionService.smartCopyAndInject(rawText);

    if (result.status == InjectionStatus.failed) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.message), backgroundColor: Colors.red)
           );
        }
        return;
    }

    // Update Status to COPIED
    try {
      await InboxService().updateStatus(note.id, NoteStatus.copied);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }

    // Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message), 
          duration: const Duration(seconds: 2),
          backgroundColor: result.status == InjectionStatus.success ? Colors.green : Colors.blue,
        )
      );
    }
  }

  void _clearArchive() {
    setState(() {
      _archivedNotes.clear();
    });
  }

  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          archivedNotes: _archivedNotes, 
          onClearAll: _clearArchive
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Inbox", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined, color: Colors.white70),
                tooltip: 'View Archive',
                onPressed: _openArchive,
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<NoteModel>>(
              stream: InboxService().watchPendingNotes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _archivedNotes.isEmpty) { 
                   return const Center(child: CircularProgressIndicator()); 
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error fetching notes: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                final notes = snapshot.data ?? [];
                
                if (notes.isEmpty) {
                   return Center(child: Text("All caught up! 🎉", style: GoogleFonts.inter(color: Colors.white30)));
                }

                return AnimatedList(
                  key: _listKey,
                  initialItemCount: notes.length,
                  itemBuilder: (context, index, animation) {
                     // Simple list builder logic from mobile
                     
                    bool showHeader = true;
                    if (index > 0) {
                       final current = notes[index];
                       final prev = notes[index - 1];
                       if (DateHelper.isSameDay(prev.createdAt, current.createdAt)) {
                         showHeader = false;
                       }
                    }

                    final header = showHeader 
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(
                            DateHelper.formatGroupingDate(notes[index].createdAt).toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.accent, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12,
                              letterSpacing: 1.2
                            ),
                          ),
                        )
                      : const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        _buildNoteCard(context, notes[index], index: index, noteNumber: notes.length - index), 
                      ],
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, NoteModel note, {int? index, int noteNumber = 0}) {
    final bool isDraft = note.formattedText.isEmpty;

    // Find applied template name
    String? templateName = note.summary;
    if ((templateName == null || templateName.isEmpty) && _allMacros.isNotEmpty) {
      final macroId = note.appliedMacroId ?? note.suggestedMacroId;
      if (macroId != null) {
        final macro = _allMacros.where((m) => m.id == macroId).firstOrNull;
        templateName = macro?.trigger;
      }
    }

    // Badge label: template name if processed, else "Draft"
    final String badgeLabel;
    if (note.status == NoteStatus.ready) {
      badgeLabel = 'Ready';
    } else if (note.status == NoteStatus.copied) {
      badgeLabel = 'Copied';
    } else if (note.formattedText.isNotEmpty) {
      badgeLabel = (templateName != null && templateName.isNotEmpty) ? templateName : 'Processed';
    } else {
      badgeLabel = 'Draft';
    }

    Color statusColor;
    IconData statusIcon;

    switch (note.status) {
      case NoteStatus.ready:
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case NoteStatus.copied:
        statusColor = Colors.blue;
        statusIcon = Icons.copy_all; 
        break;
      case NoteStatus.processed:
      case NoteStatus.draft:
      default:
        statusColor = isDraft ? Colors.orange : AppTheme.draft;
        statusIcon = Icons.edit_note;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surface,
      elevation: isDraft ? 2 : 4, 
      shadowColor: Colors.black45,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // NAVIGATE TO EXTENSION EDITOR
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExtensionEditorScreen(draftNote: note, noteNumber: noteNumber)),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                           CircleAvatar(
                            radius: 16,
                            backgroundColor: statusColor.withValues(alpha: 0.2),
                            child: Icon(statusIcon, color: statusColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              // Show Note Number or Patient Name
                              noteNumber > 0 ? 'NO-$noteNumber' : 'Draft Note',
                              style: TextStyle(
                                fontWeight: isDraft ? FontWeight.w500 : FontWeight.w600, 
                                color: isDraft ? Colors.white54 : Colors.white, 
                                fontSize: 16,
                                fontStyle: isDraft ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (index != null) 
                            IconButton(
                              icon: Icon(Icons.subdirectory_arrow_left, 
                                color: isDraft ? Colors.white30 : Colors.white70, 
                                size: 20),
                              tooltip: isDraft ? 'Select a template first' : 'Copy & Inject',
                              onPressed: isDraft ? null : () => _copyAndMarkCopied(note),
                            )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.formattedText.isNotEmpty ? note.formattedText : note.content,
                        maxLines: 2, overflow: TextOverflow.ellipsis, 
                        style: TextStyle(color: isDraft ? Colors.white54 : Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: isDraft ? Colors.grey.withValues(alpha: 0.5) : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(color: isDraft ? Colors.grey.withValues(alpha: 0.5) : Colors.grey, fontSize: 12),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badgeLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


