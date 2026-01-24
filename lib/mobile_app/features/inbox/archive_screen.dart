import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import '../../core/utils/date_helper.dart';

class ArchiveScreen extends StatelessWidget {
  final List<NoteModel> archivedNotes;
  final VoidCallback onClearAll;

  const ArchiveScreen({super.key, required this.archivedNotes, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Archived Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        leading: const BackButton(color: Colors.white),
        actions: [
          if (archivedNotes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: 'Clear All',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text("Clear Archive?", style: TextStyle(color: Colors.white)),
                    content: const Text(
                      "This will permanently delete ALL archived messages.\nThis action cannot be undone.", 
                      style: TextStyle(color: Colors.white70)
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true), 
                        child: const Text("Clear All", style: TextStyle(color: Colors.red))
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                   onClearAll();
                   Navigator.pop(context); // Close screen or stay? Usually stay is fine if list empties.
                }
              },
            ),
        ],
      ),
      body: archivedNotes.isEmpty
          ? const Center(
              child: Text(
                "No archived messages yet.",
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: archivedNotes.length,
              itemBuilder: (context, index) {
                final note = archivedNotes[index];
                
                // Date Header Logic
                bool showHeader = true;
                if (index > 0) {
                   final prev = archivedNotes[index - 1];
                   if (DateHelper.isSameDay(prev.createdAt, note.createdAt)) {
                     showHeader = false;
                   }
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Text(
                          DateHelper.formatGroupingDate(note.createdAt).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.accent, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 12,
                            letterSpacing: 1.2
                          ),
                        ),
                      ),

                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.surface.withOpacity(0.6), 
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const Icon(Icons.archive, color: Colors.white30),
                        title: Text(
                          note.title, 
                          style: const TextStyle(
                            fontWeight: FontWeight.w600, 
                            color: Colors.white54,
                            decoration: TextDecoration.lineThrough, 
                            decorationColor: Colors.white30
                          )
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white30)),
                            const SizedBox(height: 4),
                            Row(
                               children: [
                                 const Icon(Icons.check_circle_outline, size: 12, color: Colors.white30),
                                 const SizedBox(width: 4),
                                 Text("Used & Archived", style: const TextStyle(color: Colors.white30, fontSize: 10)),
                               ]
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
