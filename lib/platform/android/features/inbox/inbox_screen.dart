import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import 'package:flutter/services.dart';
import 'package:soutnote/core/entities/note_model.dart';
import '../../services/inbox_service.dart';
import '../../services/macro_service.dart';
import '../../../../core/entities/macro.dart';
import '../editor/editor_screen.dart';
import 'archive_screen.dart';
import '../../../../presentation/widgets/listening_mode_view.dart';

class InboxScreen extends StatefulWidget {
  final void Function()? onRecordingStateChanged;
  final Future<double> Function()? getAmplitude;

  const InboxScreen({super.key, this.onRecordingStateChanged, this.getAmplitude});

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<NoteModel> _archivedNotes = [];
  final _macroService = MacroService();
  final _inboxService = InboxService();
  List<Macro> _allMacros = [];

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  void setRecordingState(bool value) {
    if (_isRecording == value) return;
    setState(() => _isRecording = value);
  }

  @override
  void initState() {
    super.initState();
    _loadMacros();
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
    await Clipboard.setData(ClipboardData(text: note.content));

    try {
      await _inboxService.updateStatus(note.id, NoteStatus.copied);
    } catch (e) {
      debugPrint("Error updating status: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Copied to Clipboard! ✓"),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ));
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
              archivedNotes: _archivedNotes, onClearAll: _clearArchive)),
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
          _buildHeader(colorScheme),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: _isRecording
                  ? _buildListeningView(key: const ValueKey('listening'))
                  : _buildNotesList(colorScheme, key: const ValueKey('list')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
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
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
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
          icon: Icon(Icons.inventory_2_outlined,
              color: colorScheme.onSurface.withValues(alpha: 0.7)),
          tooltip: 'View Archive',
          onPressed: _openArchive,
        )
      ],
    );
  }

  Widget _buildListeningView({Key? key}) {
    return Stack(
      key: key,
      children: [
        ListeningModeView(
          getAmplitude: widget.getAmplitude ?? () async => -160.0,
        ),
      ],
    );
  }

  Widget _buildNotesList(ColorScheme colorScheme, {Key? key}) {
    return StreamBuilder<List<NoteModel>>(
      key: key,
      stream: _inboxService.watchPendingNotes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _archivedNotes.isEmpty) {
          return Center(
              child: CircularProgressIndicator(color: colorScheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
              child: Text("Error fetching notes: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)));
        }

        final notes = snapshot.data ?? [];

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none_rounded,
                    color: Colors.grey[700], size: 64),
                const SizedBox(height: 16),
                Text(
                  'No notes yet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the mic to start recording',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        final groupedNotes = <String, List<NoteModel>>{};
        for (var note in notes) {
          final date = note.createdAt;
          final now = DateTime.now();
          String groupKey;
          if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day) {
            groupKey = 'Today';
          } else if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day - 1) {
            groupKey = 'Yesterday';
          } else {
            groupKey = DateFormat('MMMM d, y').format(date);
          }
          groupedNotes.putIfAbsent(groupKey, () => []).add(note);
        }

        return ListView.builder(
          key: _listKey,
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: groupedNotes.length,
          itemBuilder: (context, index) {
            final dateKey = groupedNotes.keys.elementAt(index);
            final groupNotes = groupedNotes[dateKey]!;

            int notesAfterThisGroup = 0;
            for (int i = index + 1; i < groupedNotes.length; i++) {
              notesAfterThisGroup += groupedNotes.values.elementAt(i).length;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
                  child: Text(
                    dateKey.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                ...groupNotes.asMap().entries.map((entry) {
                  final noteNumber =
                      notesAfterThisGroup + (groupNotes.length - entry.key);
                  return _buildNoteCard(context, entry.value,
                      index: entry.key, noteNumber: noteNumber);
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNoteCard(BuildContext context, NoteModel note,
      {int? index, int noteNumber = 0}) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDraft = note.formattedText.isEmpty;

    const Color primaryBlue = Color(0xFF00A5FE);

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
        statusColor = MobileAppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case NoteStatus.copied:
        statusColor = primaryBlue;
        statusIcon = Icons.copy_all;
        break;
      case NoteStatus.processed:
      case NoteStatus.draft:
      default:
        statusColor = primaryBlue;
        statusIcon = Icons.edit_note;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDraft ? 0.04 : 0.08),
            blurRadius: isDraft ? 6 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      EditorScreen(draftNote: note, noteNumber: noteNumber)),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(statusIcon,
                                  color: statusColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                noteNumber > 0
                                    ? 'NO-$noteNumber'
                                    : 'Draft Note',
                                style: TextStyle(
                                  fontWeight: isDraft
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: isDraft
                                      ? colorScheme.onSurface
                                          .withValues(alpha: 0.45)
                                      : colorScheme.onSurface,
                                  fontSize: 15,
                                  fontStyle: isDraft
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                            if (index != null)
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.subdirectory_arrow_left,
                                    color: isDraft
                                        ? colorScheme.onSurface
                                            .withValues(alpha: 0.2)
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                    size: 19,
                                  ),
                                  tooltip: isDraft
                                      ? 'Select a template first'
                                      : 'Copy & Inject',
                                  onPressed: isDraft
                                      ? null
                                      : () => _copyAndMarkCopied(note),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          note.formattedText.isNotEmpty
                              ? note.formattedText
                              : note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDraft
                                ? colorScheme.onSurface
                                    .withValues(alpha: 0.38)
                                : colorScheme.onSurface
                                    .withValues(alpha: 0.68),
                            height: 1.45,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.38)),
                            const SizedBox(width: 4),
                            Text(
                              "${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.38),
                                fontSize: 11.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    note.status == NoteStatus.ready
                                        ? Icons.check_circle_outline
                                        : note.status == NoteStatus.copied
                                            ? Icons.copy_outlined
                                            : Icons.auto_awesome,
                                    size: 11,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}
