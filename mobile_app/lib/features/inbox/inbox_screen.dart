import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/note_model.dart';
import '../editor/editor_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final notes = [
      NoteModel()..title="Patient H.M."..content="History of amnesia..."..status=NoteStatus.processed..createdAt=DateTime.now().subtract(const Duration(minutes: 5)),
      NoteModel()..title="Follow-up: Sarah J."..content="Prescription renewal..."..status=NoteStatus.ready..createdAt=DateTime.now().subtract(const Duration(hours: 1)),
      NoteModel()..title="Dr. Notes"..content="Staff meeting at 5 PM"..status=NoteStatus.draft..createdAt=DateTime.now().subtract(const Duration(days: 1)),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Inbox", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _buildNoteCard(context, note);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, NoteModel note) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditorScreen(draftNote: note)),
          );
        },
      ),
    );
  }
}
