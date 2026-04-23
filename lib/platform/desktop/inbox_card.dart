import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/entities/inbox_note.dart';
import '../../core/entities/macro.dart';
import '../../data/repositories/windows_injector.dart'; // Desktop Injector
import '../../data/repositories/inbox_service.dart';
import 'inbox_note_detail_view.dart';
import '../mobile_app/core/theme.dart'; // Import AppTheme
import '../../core/ai/text_processing_service.dart';

class InboxCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onArchived;
  final List<Macro> quickMacros;
  final int noteNumber; // 1-based, oldest = 1

  const InboxCard({
    super.key,
    required this.note,
    required this.onArchived,
    this.quickMacros = const [],
    this.noteNumber = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDraft = note.formattedText.isEmpty;

    // Find applied template name
    // Primary: stored in note.title / patientName during processing
    // Secondary: stored in note.summary during auto-save
    // Fallback: lookup by macroId in quickMacros
    String? templateName = note.title;
    if (templateName.isEmpty ||
        ['Draft Note', 'Unknown Patient', 'Untitled'].contains(templateName)) {
      templateName = note.summary;
    }

    if ((templateName == null || templateName.isEmpty) &&
        quickMacros.isNotEmpty) {
      final macroId = note.appliedMacroId ?? note.suggestedMacroId;
      if (macroId != null) {
        final macro = quickMacros.where((m) => m.id == macroId).firstOrNull;
        templateName = macro?.trigger;
      }
    }

    // Badge label: template name if valid, else "Draft"
    final String badgeLabel;
    if (note.status == NoteStatus.ready) {
      badgeLabel = 'Ready';
    } else if (note.status == NoteStatus.copied) {
      badgeLabel = 'Copied';
    } else if (templateName != null &&
        templateName.isNotEmpty &&
        !['Draft Note', 'Unknown Patient', 'Untitled'].contains(templateName)) {
      // Show template name instead of "Processed"
      badgeLabel = templateName;
    } else {
      badgeLabel = 'Draft';
    }

    // Determine status icon/color
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
        statusColor = isDraft ? Colors.orange : AppTheme.draft;
        statusIcon = Icons.edit_note;
        statusText = "Draft";
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      color: theme.colorScheme.surface,
      elevation: isDraft ? 2 : 4,
      shadowColor:
          theme.brightness == Brightness.dark ? Colors.black45 : Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetailView(context),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: statusColor,
              ),
              // Card content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: statusColor.withValues(alpha: 0.2),
                            child:
                                Icon(statusIcon, color: statusColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getNoteTitle(),
                              style: TextStyle(
                                fontWeight:
                                    isDraft ? FontWeight.w500 : FontWeight.w600,
                                color: isDraft
                                    ? theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)
                                    : theme.colorScheme.onSurface,
                                fontSize: 16,
                                fontStyle: isDraft
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          // Inject button — disabled for drafts
                          IconButton(
                            icon: Icon(
                              Icons.subdirectory_arrow_left,
                              color: isDraft
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.2)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                              size: 20,
                            ),
                            tooltip: isDraft
                                ? 'Select a template first'
                                : 'Smart Copy & Inject',
                            onPressed:
                                isDraft ? null : () => _injectNote(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (note.patientName.isNotEmpty &&
                                !['Unknown Patient', 'Untitled', 'Draft Note']
                                    .contains(note.patientName))
                            ? (note.formattedText.isNotEmpty
                                ? note.formattedText
                                    .replaceAll('\n', ' ')
                                    .trim()
                                : (note.summary ??
                                    note.content.replaceAll('\n', ' ').trim()))
                            : (note.formattedText.isNotEmpty
                                ? note.formattedText
                                    .replaceAll('\n', ' ')
                                    .trim()
                                : note.content.replaceAll('\n', ' ').trim()),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDraft
                              ? theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(note.createdAt),
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 12),
                          ),
                          const Spacer(),
                          // Status badge pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
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

  String _getNoteTitle() {
    return 'NO-$noteNumber';
  }

  Future<void> _injectNote(BuildContext context) async {
    final availableText =
        note.formattedText.isNotEmpty ? note.formattedText : note.rawText;
    final textToInject = TextProcessingService.applySmartCopy(availableText);

    if (textToInject.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No content to inject. Select a template first."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    // Use smartInject: handles alwaysOnTop toggle + blur + Ctrl+V
    await WindowsInjector().smartInject(textToInject);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("✅ Injected into EMR", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }

    // Mark as Copied
    try {
      await InboxService().updateStatus(note.id, NoteStatus.copied);
    } catch (e) {
      print("Error updating status to copied: $e");
    }
  }

  Future<void> _openDetailView(BuildContext context,
      {Macro? autoStartMacro}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InboxNoteDetailView(
        note: note,
        noteNumber: noteNumber,
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
