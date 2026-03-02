import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import 'package:flutter/services.dart';
import '../../models/note_model.dart';
import '../../services/inbox_service.dart';
import '../../services/macro_service.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Branded Logo Area
              Row(
                textDirection: TextDirection.ltr,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logo_icon.svg',
                      height: 28,
                      width: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Sout',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: 'Note',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.9),
                            height: 1.0,
                          ),
                          children: [
                            const TextSpan(text: 'صوت '),
                            TextSpan(
                              text: 'ن',
                              style: TextStyle(color: colorScheme.primary),
                            ),
                            const TextSpan(text: 'وت'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.inventory_2_outlined, color: colorScheme.onSurface.withOpacity(0.7)),
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
                            style: TextStyle(
                              color: colorScheme.primary, 
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
                        _buildNoteCard(context, notes[index], index: index, noteNumber: notes.length - index), // Removed animation wrapper for now
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

  Widget _buildNoteCard(BuildContext context, NoteModel note, {int? index, int noteNumber = 0}) {
    final colorScheme = Theme.of(context).colorScheme;
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
      color: colorScheme.surface,
      elevation: isDraft ? 2 : 4,
      shadowColor: Colors.black45,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(draftNote: note, noteNumber: noteNumber)),
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
                            backgroundColor: statusColor.withOpacity(0.2),
                            child: Icon(statusIcon, color: statusColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              noteNumber > 0 ? 'NO-$noteNumber' : 'Draft Note',
                              style: TextStyle(
                                fontWeight: isDraft ? FontWeight.w500 : FontWeight.w600,
                                color: isDraft
                                    ? colorScheme.onSurface.withOpacity(0.5)
                                    : colorScheme.onSurface,
                                fontSize: 16,
                                fontStyle: isDraft ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (index != null)
                            IconButton(
                              icon: Icon(Icons.subdirectory_arrow_left, 
                                color: isDraft 
                                  ? colorScheme.onSurface.withOpacity(0.2)
                                  : colorScheme.onSurface.withOpacity(0.6), 
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
                        style: TextStyle(color: isDraft ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.onSurface.withOpacity(0.7), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Text(
                            "${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12),
                          ),
                          const Spacer(),
                          // Status badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
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
