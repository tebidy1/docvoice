import 'dart:async';
import 'package:flutter/material.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import '../services/inbox_service.dart';
import '../services/macro_service.dart';
import '../services/audio_recorder_service.dart';
import '../utils/window_manager_helper.dart';
import '../screens/settings_dialog.dart';
import 'inbox_card.dart';
import 'macro_manager_dialog.dart';
import 'package:intl/intl.dart';
import '../../widgets/animated_record_button.dart';
import '../../widgets/listening_mode_view.dart';

class InboxManagerDialog extends StatefulWidget {
  final Future<void> Function()? onRecordTap;
  final bool isRecording;
  final bool isProcessing;
  final AudioRecorderService? recorderService;

  const InboxManagerDialog({
    super.key,
    this.onRecordTap,
    this.isRecording = false,
    this.isProcessing = false,
    this.recorderService,
  });

  @override
  State<InboxManagerDialog> createState() => _InboxManagerDialogState();
}

class _InboxManagerDialogState extends State<InboxManagerDialog>
    with TickerProviderStateMixin {
  final _inboxService = InboxService();
  final _macroService = MacroService();
  List<Macro> _quickMacros = [];
  int _selectedTab = 0;

  // ── Local recording state (drives UI updates) ──
  bool _localIsRecording = false;

  @override
  void initState() {
    super.initState();
    _localIsRecording = widget.isRecording;
    _initServices();
  }

  @override
  void didUpdateWidget(InboxManagerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRecording && _localIsRecording && !widget.isProcessing) {
      if (mounted) {
        setState(() {
          _localIsRecording = false;
        });
      }
    }
  }

  Future<void> _initServices() async {
    await _inboxService.init();
    await _loadMacros();
  }

  Future<void> _loadMacros() async {
    await _macroService.init();
    var macros = await _macroService.getMostUsed(limit: 10);
    if (macros.isEmpty) {
      final all = await _macroService.getAllMacros();
      macros = all.take(10).toList();
    }
    if (mounted) setState(() => _quickMacros = macros);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => WindowManagerHelper.setOpacity(1.0),
      onExit: (_) => WindowManagerHelper.setOpacity(0.7),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: WindowManagerHelper.sidebarWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[800]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(theme, colorScheme),

              // ── Body: AnimatedSwitcher between list and listening view ──
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: _localIsRecording
                      ? _buildListeningView(key: const ValueKey('listening'))
                      : _buildNotesList(
                          colorScheme, key: const ValueKey('list')),
                ),
              ),

              // ── Bottom Action Bar ──
              _buildBottomBar(theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _localIsRecording ? Icons.graphic_eq : Icons.inbox_outlined,
              color: _localIsRecording
                  ? const Color(0xFF00A6FB)
                  : colorScheme.primary,
              size: 22,
              key: ValueKey(_localIsRecording),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _localIsRecording
                  ? Text(
                      "Recording...",
                      key: ValueKey("recording"),
                      style: const TextStyle(
                        color: Color(0xFF00A6FB),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    )
                  : Container(
                      key: const ValueKey('tabs'),
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(children: [
                        _buildTab(0, 'Notes', colorScheme),
                        _buildTab(1, 'Archive', colorScheme),
                      ]),
                    ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // LISTENING VIEW — Animated waveform rings
  // ──────────────────────────────────────────────
  Widget _buildListeningView({Key? key}) {
    return ListeningModeView(
      key: key,
      getAmplitude: () async {
        if (widget.recorderService != null) {
          try {
            final amp = await widget.recorderService!.getAmplitude();
            return amp.current; // Returns -160.0 to 0.0
          } catch (_) {}
        }
        return -160.0;
      },
    );
  }

  // ──────────────────────────────────────────────
  // NOTES LIST
  // ──────────────────────────────────────────────
  Widget _buildNotesList(ColorScheme colorScheme, {Key? key}) {
    return StreamBuilder<List<NoteModel>>(
      key: key,
      stream: _selectedTab == 0
          ? _inboxService.watchPendingNotes()
          : _inboxService.watchArchivedNotes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        final notes = snapshot.data!;
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_none_rounded, color: Colors.grey[700], size: 64),
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
                  _selectedTab == 0
                      ? 'Tap the mic to start recording'
                      : 'No archived notes yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Group notes by date
        final groupedNotes = <String, List<NoteModel>>{};
        for (var note in notes) {
          final date = note.createdAt;
          final now = DateTime.now();
          String key;
          if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day) {
            key = 'Today';
          } else if (date.year == now.year &&
              date.month == now.month &&
              date.day == now.day - 1) {
            key = 'Yesterday';
          } else {
            key = DateFormat('MMMM d, y').format(date);
          }
          groupedNotes.putIfAbsent(key, () => []).add(note);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: groupedNotes.length,
          itemBuilder: (context, index) {
            final dateKey = groupedNotes.keys.elementAt(index);
            final groupNotes = groupedNotes[dateKey]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 8, top: 16),
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
                ...groupNotes.map((note) => InboxCard(
                      note: note,
                      quickMacros: _quickMacros,
                      onArchived: () {},
                    )),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // BOTTOM ACTION BAR
  // ──────────────────────────────────────────────
  Widget _buildBottomBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomBarIcon(
                icon: Icons.description_outlined,
                label: 'Templates',
                onTap: () async {
                  await WindowManagerHelper.centerDialog();
                  if (!mounted) return;
                  await showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const MacroManagerDialog(),
                  );
                  if (mounted) {
                    await WindowManagerHelper.expandToSidebar(context);
                  }
                },
              ),
              const SizedBox(width: 70),
              _buildBottomBarIcon(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () async {
                  await WindowManagerHelper.centerDialog();
                  if (!mounted) return;
                  await showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const SettingsDialog(),
                  );
                  if (mounted) {
                    await WindowManagerHelper.expandToSidebar(context);
                  }
                },
              ),
            ],
          ),

              // Center Record FAB (elevated)
              Positioned(
                top: -20,
                child: AnimatedRecordButton(
                  onStartRecording: widget.onRecordTap,
                  onStopRecording: widget.onRecordTap,
                  initialIsRecording: widget.isRecording,
                  initialIsProcessing: widget.isProcessing,
                  onRecordingStateChanged: (isRecording) {
                    if (mounted) {
                      setState(() {
                        _localIsRecording = isRecording;
                      });
                    }
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildBottomBarIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[500], size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, ColorScheme colorScheme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() => _selectedTab = index);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colorScheme.primary : Colors.grey[500],
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
