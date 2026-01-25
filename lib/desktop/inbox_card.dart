import 'package:flutter/material.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import '../services/windows_injector.dart'; // Desktop Injector
import 'inbox_note_detail_view.dart';

class InboxCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onArchived;
  final List<Macro> quickMacros;

  const InboxCard({
    super.key,
    required this.note,
    required this.onArchived,
    this.quickMacros = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Determine status icon/color
    final isProcessed = note.status == NoteStatus.processed ||
        note.status == NoteStatus.archived;
    final statusColor = isProcessed ? Colors.blue : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Card Content (Clickable)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => _openDetailView(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Icon (Double Check)
                    Icon(
                      Icons.done_all,
                      size: 18,
                      color: statusColor,
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                note.patientName.isNotEmpty
                                    ? note.patientName
                                    : 'Unknown Patient',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                _formatTime(note.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note.summary ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Bar (Inject + Macros)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                // Inject Button (Primary Action)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _injectNote(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Icon(Icons.input,
                              size: 14, color: Colors.blueAccent.shade100),
                          const SizedBox(width: 6),
                          Text("INJECT",
                              style: TextStyle(
                                  color: Colors.blueAccent.shade100,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Quick Macros (if any)
                if (quickMacros.isNotEmpty) ...[
                  Container(
                      width: 1,
                      height: 20,
                      color: Colors.white.withOpacity(0.1)),
                  const SizedBox(width: 12),
                  const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: quickMacros.map((macro) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _openDetailView(context,
                                  autoStartMacro: macro),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withOpacity(0.05),
                                ),
                                child: Text(
                                  macro.trigger,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _injectNote(BuildContext context) async {
    // 1. Feedback
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Injecting to EMR... (Focus target window now!)",
          style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.blueAccent,
      duration: Duration(seconds: 2),
    ));

    // 2. Inject
    // Wait small bit for user to theoretically focus, though usually they focus first then click inject?
    // Actually for desktop app -> EMR, the flow is:
    // User clicks "Inject" on our app -> We minimize -> User clicks EMR text field?
    // OR: User clicks "Inject" -> We copy to clipboard -> User pastes.
    // The "Smart Paste" in WindowsInjector does: Copy -> Wait -> Send Ctrl+V.
    // So user should have EMR open in background.

    // Let's minimize our app first to reveal EMR?
    // Or just assume user will Alt+Tab?
    // For now, simple injection.

    await WindowsInjector().injectViaPaste(note.rawText);
  }

  Future<void> _openDetailView(BuildContext context,
      {Macro? autoStartMacro}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InboxNoteDetailView(
        note: note,
        autoStartMacro: autoStartMacro,
      ),
    );
    onArchived();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
