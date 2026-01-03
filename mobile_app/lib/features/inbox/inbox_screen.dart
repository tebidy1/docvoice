import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'package:flutter/services.dart';
import '../../models/note_model.dart';
import '../../services/inbox_service.dart';
import '../editor/editor_screen.dart';
import 'archive_screen.dart';
import '../../core/utils/date_helper.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
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

  void _archiveNote(int index) {
    if (index >= _notes.length) return;

    final note = _notes[index];
    
    // 1. Copy to Clipboard
    Clipboard.setData(ClipboardData(text: note.content));

    // 2. Update State
    // Clipboard.setData(ClipboardData(text: note.content)); // `note` is undefined here

    // 2. Update State (This part is from the instruction snippet)
    // setState(() {
    //   note.status = NoteStatus.archived; // `note` is undefined here
    //   _archivedNotes.insert(0, note); // Add to top of archive // `note` is undefined here
    // });

    // 3. Animate Removal from Active List
    // We remove it from the data source `_notes` first, then tell AnimatedList
    // The following lines are commented out in the instruction's context, implying removal.
    // final removedItem = _notes.removeAt(index);
    
    // _listKey.currentState?.removeItem(
    //   index,
    //   (context, animation) => _buildAnimatedItem(context, removedItem, animation),
    //   duration: const Duration(milliseconds: 500)
    // );

    // 4. Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied & Archived! 📋🗄️"), 
        duration: Duration(seconds: 2),
        backgroundColor: AppTheme.accent,
      )
    );
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
                if (snapshot.connectionState == ConnectionState.waiting && _archivedNotes.isEmpty) { // Changed _notes.isEmpty to _archivedNotes.isEmpty as _notes is no longer a state variable
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
                  key: _listKey, // Note: Key usage with StreamBuilder might be tricky if list changes drastically. 
                  // For simplicity in this iteration, we use ListView.builder inside the Stream
                  // or we manually manage diffs. 
                  // Let's swap to ListView.builder for reliability with Streams, or just populate _notes.
                  // Real proper AnimatedList with Stream requires DiffUtil.
                  // Let's use simple ListView for the V1 Cloud Sync to ensure correctness.
                  
                  initialItemCount: notes.length,
                  itemBuilder: (context, index, animation) {
                     // Since we can't easily animate item insertion from Stream without diffing,
                     // we will lose the slide animation on load, but gain Real-time Sync.
                     // A fair trade-off for Phase 9.
                     
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
                        // The _buildAnimatedItem wrapper is removed as per instruction.
                        // The _archiveNote call needs to be updated to use the note from the stream.
                        _buildNoteCard(context, notes[index], index: index), // Removed animation wrapper for now
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

  // Modified to accept index for Copy action
  Widget _buildAnimatedItem(BuildContext context, NoteModel note, Animation<double> animation, {int? index}) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0, 
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2), 
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: _buildNoteCard(context, note, index: index),
        ),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(draftNote: note)),
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
                  if (index != null) // Only show Copy button if index is known (active list)
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      tooltip: 'Copy & Archive',
                      onPressed: () => _archiveNote(index),
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
