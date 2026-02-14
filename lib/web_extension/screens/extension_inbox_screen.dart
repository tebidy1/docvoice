import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../mobile_app/core/theme.dart';
import 'package:flutter/services.dart';
import '../../mobile_app/models/note_model.dart';
import '../../mobile_app/services/inbox_service.dart';
import 'extension_editor_screen.dart'; // Correct Import
import '../../mobile_app/features/inbox/archive_screen.dart'; // Reuse Mobile Archive
import '../../mobile_app/core/utils/date_helper.dart';

class ExtensionInboxScreen extends StatefulWidget {
  const ExtensionInboxScreen({super.key});

  @override
  State<ExtensionInboxScreen> createState() => ExtensionInboxScreenState();
}

class ExtensionInboxScreenState extends State<ExtensionInboxScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<NoteModel> _notes = []; // Active Notes
  final List<NoteModel> _archivedNotes = []; // Archived Notes

  @override
  void initState() {
    super.initState();
    // Initial Mock Data (Same as before)
    _notes.addAll([
      NoteModel()..title="Patient H.M."..content="History of amnesia..."..status=NoteStatus.processed..createdAt=DateTime.now().subtract(const Duration(minutes: 5)),
      NoteModel()..title="Follow-up: Sarah J."..content="Prescription renewal..."..status=NoteStatus.ready..createdAt=DateTime.now().subtract(const Duration(hours: 1)),
      NoteModel()..title="Dr. Notes"..content="Staff meeting at 5 PM"..status=NoteStatus.draft..createdAt=DateTime.now().subtract(const Duration(days: 1)),
    ]);
  }

  void addNote(NoteModel note) {
    _notes.insert(0, note);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 600));
  }

  Future<void> _copyAndMarkCopied(NoteModel note) async {
    // 1. Copy to Clipboard
    await Clipboard.setData(ClipboardData(text: note.content));

    // 2. Update Status to COPIED (Not Archived)
    try {
      await InboxService().updateStatus(note.id, NoteStatus.copied);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }

    // 3. Feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Copied to Clipboard! ✓"), 
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
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
                        _buildNoteCard(context, notes[index], index: index), 
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

  Widget _buildNoteCard(BuildContext context, NoteModel note, {int? index}) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (note.status) {
      case NoteStatus.ready:
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        statusText = "Ready";
        break;
      case NoteStatus.copied:
        statusColor = Colors.blue;
        statusIcon = Icons.copy_all; 
        statusText = "Copied";
        break;
      case NoteStatus.processed:
      case NoteStatus.draft:
      default:
        statusColor = AppTheme.draft;
        statusIcon = Icons.edit_note;
        statusText = "Draft";
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surface,
      elevation: 4, 
      shadowColor: Colors.black45,
      child: InkWell(
        onTap: () {
          // NAVIGATE TO EXTENSION EDITOR
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExtensionEditorScreen(draftNote: note)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   CircleAvatar(
                    radius: 16,
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(statusIcon, color: statusColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16)),
                  ),
                  if (index != null) 
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      tooltip: 'Copy & Archive',
                      onPressed: () => _copyAndMarkCopied(note),
                    )
                ],
              ),
              const SizedBox(height: 8),
              Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
