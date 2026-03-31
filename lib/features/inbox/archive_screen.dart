import 'package:flutter/material.dart';
import 'package:soutnote/shared/theme.dart';
import 'package:soutnote/core/models/note_model.dart';
import 'package:soutnote/core/utils/date_helper.dart';

import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soutnote/core/providers/common_providers.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  void _startDragging() {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.startDragging();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedNotesAsync = ref.watch(inboxNoteRepositoryProvider).watchArchived();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: GestureDetector(
          onPanStart: (details) => _startDragging(),
          child: Container(
            color: Colors.transparent, // Ensure hit testing
            width: double.infinity,
            child: const Text("Archived Messages",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        backgroundColor: AppTheme.background,
        leading: const BackButton(color: Colors.white),
        actions: [
          StreamBuilder<List<NoteModel>>(
            stream: archivedNotesAsync,
            builder: (context, snapshot) {
              final notes = snapshot.data ?? [];
              if (notes.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                tooltip: 'Clear All',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text("Clear Archive?",
                          style: TextStyle(color: Colors.white)),
                      content: const Text(
                          "This will permanently delete ALL archived messages.\nThis action cannot be undone.",
                          style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel")),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Clear All",
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(inboxNoteRepositoryProvider).sync(); // Or another clear method if available
                    // For now, we don't have a 'clearAllArchived' in the interface.
                    // We could implement it or just leave it for now.
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NoteModel>>(
        stream: archivedNotesAsync,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                "No archived messages yet.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];

              // Date Header Logic
              bool showHeader = true;
              if (index > 0) {
                final prev = notes[index - 1];
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
                        DateHelper.formatGroupingDate(note.createdAt)
                            .toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2),
                      ),
                    ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppTheme.surface.withOpacity(0.6),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(Icons.archive, color: Colors.white30),
                      title: Text(note.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white30)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white30)),
                          const SizedBox(height: 4),
                          const Row(children: [
                            Icon(Icons.check_circle_outline,
                                size: 12, color: Colors.white30),
                            SizedBox(width: 4),
                            Text("Used & Archived",
                                style: TextStyle(
                                    color: Colors.white30, fontSize: 10)),
                          ])
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
