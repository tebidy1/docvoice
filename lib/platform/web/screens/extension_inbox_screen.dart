import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/entities/note_model.dart';
import '../../android/services/inbox_service.dart';
import '../../android/services/macro_service.dart';
import '../../../core/entities/macro.dart';
import 'extension_editor_screen.dart';
import '../../android/core/utils/date_helper.dart';
import '../services/extension_injection_service.dart';

class ExtensionInboxScreen extends StatefulWidget {
  const ExtensionInboxScreen({super.key});

  @override
  State<ExtensionInboxScreen> createState() => ExtensionInboxScreenState();
}

class ExtensionInboxScreenState extends State<ExtensionInboxScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final _inboxService = InboxService();
  final _macroService = MacroService();
  List<Macro> _allMacros = [];
  List<NoteModel> _notes = [];
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadMacros();
    _inboxService.init().then((_) => _inboxService.goToPendingPage(1));
    _stateSub = _inboxService.watch().listen((service) {
      if (mounted) setState(() => _notes = service.pendingItems);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMacros() async {
    final all = await _macroService.getMacros();
    if (mounted) setState(() => _allMacros = all);
  }

  void addNote(NoteModel note) {
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 600));
  }

  Future<void> _copyAndMarkCopied(NoteModel note) async {
    final rawText =
        note.formattedText.isNotEmpty ? note.formattedText : note.content;

    final result = await ExtensionInjectionService.smartCopyAndInject(rawText);

    if (result.status == InjectionStatus.failed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.message), backgroundColor: Colors.red));
      }
      return;
    }

    try {
      await _inboxService.updateStatus(note.id, NoteStatus.copied);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 2),
        backgroundColor: result.status == InjectionStatus.success
            ? Colors.green
            : Colors.blue,
      ));
    }
  }

  void _openArchive() {
    // Placeholder
  }

  @override
  Widget build(BuildContext context) {
    final svc = _inboxService;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Inbox",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.inventory_2_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7)),
                tooltip: 'View Archive',
                onPressed: _openArchive,
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: svc.pendingLoading && _notes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? Center(
                        child: Text("All caught up!",
                            style: GoogleFonts.inter(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3))))
                    : ListView.builder(
                        key: _listKey,
                        itemCount: _notes.length,
                        itemBuilder: (context, index) {
                          bool showHeader = true;
                          if (index > 0) {
                            if (DateHelper.isSameDay(
                                _notes[index - 1].createdAt, _notes[index].createdAt)) {
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
                                    DateHelper.formatGroupingDate(_notes[index].createdAt).toUpperCase(),
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                                  ),
                                ),
                              _buildNoteCard(context, _notes[index],
                                  index: index, noteNumber: _notes.length - index),
                            ],
                          );
                        },
                      ),
          ),
          if (svc.pendingTotal > 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: svc.hasPreviousPage ? () => svc.previousPendingPage() : null,
                  ),
                  Text('${svc.pendingCurrentPage} / ${svc.pendingLastPage}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: svc.hasNextPage ? () => svc.nextPendingPage() : null,
                  ),
                  Text('${svc.pendingTotal} total',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, NoteModel note,
      {int? index, int noteNumber = 0}) {
    final bool isDraft = note.formattedText.isEmpty;

    String? templateName = note.summary;
    if ((templateName == null || templateName.isEmpty) &&
        _allMacros.isNotEmpty) {
      final macroId = note.appliedMacroId ?? note.suggestedMacroId;
      if (macroId != null) {
        final macro = _allMacros.where((m) => m.id == macroId).firstOrNull;
        templateName = macro?.trigger;
      }
    }

    final String badgeLabel;
    if (note.status == NoteStatus.ready) {
      badgeLabel = 'Ready';
    } else if (note.status == NoteStatus.copied) {
      badgeLabel = 'Copied';
    } else if (note.formattedText.isNotEmpty) {
      badgeLabel = (templateName != null && templateName.isNotEmpty)
          ? templateName
          : 'Processed';
    } else {
      badgeLabel = 'Draft';
    }

    Color statusColor;
    IconData statusIcon;

    switch (note.status) {
      case NoteStatus.ready:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case NoteStatus.copied:
        statusColor = Colors.blue;
        statusIcon = Icons.copy_all;
        break;
      case NoteStatus.processed:
      case NoteStatus.draft:
      default:
        statusColor = Theme.of(context).colorScheme.primary;
        statusIcon = Icons.edit_note;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDraft ? 2 : 4,
      shadowColor: Colors.black45,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ExtensionEditorScreen(
                    draftNote: note, noteNumber: noteNumber)),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              noteNumber > 0 ? 'NO-$noteNumber' : 'Draft Note',
                              style: TextStyle(
                                fontWeight:
                                    isDraft ? FontWeight.w500 : FontWeight.w600,
                                color: isDraft
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.54)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontStyle: isDraft
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (index != null)
                            IconButton(
                              icon: Icon(Icons.subdirectory_arrow_left,
                                  color: isDraft
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.3)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                  size: 20),
                              tooltip: isDraft
                                  ? 'Select a template first'
                                  : 'Copy & Inject',
                              onPressed: isDraft
                                  ? null
                                  : () => _copyAndMarkCopied(note),
                            )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.formattedText.isNotEmpty
                            ? note.formattedText
                            : note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isDraft
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.54)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                            height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12,
                              color: isDraft
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(
                                color: isDraft
                                    ? Colors.grey.withValues(alpha: 0.5)
                                    : Colors.grey,
                                fontSize: 12),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badgeLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
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
