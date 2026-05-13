import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/entities/inbox_note.dart';
import '../../core/entities/macro.dart';
import '../../core/services/inbox_service.dart';
import '../../core/services/macro_service.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/utils/window_manager_helper.dart';
import '../../presentation/screens/settings_dialog.dart';
import 'inbox_card.dart';
import 'macro_manager_dialog.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../platform/android/features/inbox/archive_screen.dart';
import '../../presentation/widgets/animated_record_button.dart';
import '../../presentation/widgets/listening_mode_view.dart';
import 'widgets/desktop_bottom_nav.dart';

class InboxManagerDialog extends StatefulWidget {
  final Future<void> Function()? onRecordTap;
  final bool isRecording;
  final bool isProcessing;
  final AudioRecorderService? recorderService;
  final String? compressionLabel;

  const InboxManagerDialog({
    super.key,
    this.onRecordTap,
    this.isRecording = false,
    this.isProcessing = false,
    this.recorderService,
    this.compressionLabel,
  });

  @override
  State<InboxManagerDialog> createState() => _InboxManagerDialogState();
}

class _InboxManagerDialogState extends State<InboxManagerDialog>
    with TickerProviderStateMixin {
  final _inboxService = InboxService();
  final _macroService = MacroService();
  List<Macro> _quickMacros = [];

  // ── Local recording state (drives UI updates) ──
  bool _localIsRecording = false;

  // ── Bottom nav tab state ──
  int _navTab = 0; // 0 = الملاحظات (notes), 1 = الإعدادات (settings)

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
    final all = await _macroService.getAllMacros();
    if (mounted) setState(() => _quickMacros = all);
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

              // ── Body: IndexedStack for navigation between notes and settings ──
              Expanded(
                child: IndexedStack(
                  index: _navTab,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: _localIsRecording
                          ? _buildListeningView(key: const ValueKey('listening'))
                          : _buildNotesList(colorScheme,
                              key: const ValueKey('list')),
                    ),
                    _buildSettingsView(colorScheme),
                  ],
                ),
              ),

// ── Bottom Action Bar ──
              _buildBottomBar(theme, colorScheme),
              // ── Bottom Navigation Bar ──
              DesktopBottomNav(
                currentIndex: _navTab.clamp(0, 1),
                onTap: (index) {
                  if (index == 2) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _navTab = index);
                  }
                },
                items: const [
                  BottomNavItem(
                    icon: Icons.notes_rounded,
                    label: 'الملاحظات',
                  ),
                  BottomNavItem(
                    icon: Icons.settings_rounded,
                    label: 'الإعدادات',
                  ),
                  BottomNavItem(
                    icon: Icons.home_rounded,
                    label: 'الرئيسية',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // SETTINGS VIEW (embedded inline)
  // ──────────────────────────────────────────────
  Widget _buildSettingsView(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإعدادات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingsItem(
            icon: Icons.mic,
            title: 'إعدادات الميكروفون',
            subtitle: 'اختر الميكروفون الافتراضي',
            colorScheme: colorScheme,
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.language,
            title: 'اللغة',
            subtitle: 'العربية',
            colorScheme: colorScheme,
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.notifications,
            title: 'الإشعارات',
            subtitle: 'مفعّل',
            colorScheme: colorScheme,
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'حول التطبيق',
            subtitle: 'الإصدار 1.0.0',
            colorScheme: colorScheme,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  void _openArchive() async {
    final archivedNotes = await _inboxService.getArchivedNotes();
    if (!mounted) return;
    await WindowManagerHelper.centerDialog();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          archivedNotes: archivedNotes,
          onClearAll: () {},
        ),
      ),
    );
    if (!mounted) return;
    await WindowManagerHelper.expandToSidebar(context);
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
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
            ),
          ),
          IconButton(
            icon: Icon(Icons.inventory_2_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.7)),
            tooltip: 'View Archive',
            onPressed: _openArchive,
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
    return Stack(
      key: key,
      children: [
        ListeningModeView(
          getAmplitude: () async {
            if (widget.recorderService != null) {
              try {
                final amp = await widget.recorderService!.getAmplitude();
                return amp.current; // Returns -160.0 to 0.0
              } catch (_) {}
            }
            return -160.0;
          },
        ),
        if (widget.compressionLabel != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: Text(
              widget.compressionLabel!,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.blueGrey.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // NOTES LIST
  // ──────────────────────────────────────────────
  Widget _buildNotesList(ColorScheme colorScheme, {Key? key}) {
    return StreamBuilder<List<NoteModel>>(
      key: key,
      stream: _inboxService.watchPendingNotes(),
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
                  'Tap the mic to start recording',
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

        // Compute total for reversed numbering (oldest = NO-1)
        final totalNotes = notes.length;
        int runningOffset = 0;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: groupedNotes.length,
          itemBuilder: (context, index) {
            final dateKey = groupedNotes.keys.elementAt(index);
            final groupNotes = groupedNotes[dateKey]!;

            // Calculate the starting offset for this group
            // Groups are newest-first, so we need to count notes AFTER this group
            int notesAfterThisGroup = 0;
            for (int i = index + 1; i < groupedNotes.length; i++) {
              notesAfterThisGroup += groupedNotes.values.elementAt(i).length;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8, top: 16),
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
                  // Within each group, newest note is first (index 0)
                  // noteNumber = notesAfterThisGroup + (groupSize - entryIndex)
                  final noteNumber =
                      notesAfterThisGroup + (groupNotes.length - entry.key);
                  return InboxCard(
                    note: entry.value,
                    noteNumber: noteNumber,
                    quickMacros: _quickMacros,
                    onArchived: () {},
                  );
                }),
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
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              width: 0.5),
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
                onTap: () {
                  Navigator.of(context).push(DialogRoute(
                    context: context,
                    builder: (_) => const MacroManagerDialog(),
                    barrierDismissible: true,
                    barrierColor: Colors.transparent,
                  ));
                },
              ),
              const SizedBox(width: 70),
              _buildBottomBarIcon(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.of(context).push(DialogRoute(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                    barrierDismissible: true,
                    barrierColor: Colors.transparent,
                  ));
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
