import 'package:flutter/material.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import '../services/inbox_service.dart';
import '../services/macro_service.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/window_manager_helper.dart';
import 'inbox_card.dart';
import 'package:intl/intl.dart';

class InboxManagerDialog extends StatefulWidget {
  const InboxManagerDialog({super.key});

  @override
  State<InboxManagerDialog> createState() => _InboxManagerDialogState();
}

class _InboxManagerDialogState extends State<InboxManagerDialog> {
  final _inboxService = InboxService();
  final _macroService = MacroService();
  List<Macro> _quickMacros = [];
  int _selectedTab = 0; // 0: Notes, 1: Archive

  @override
  void initState() {
    super.initState();
    // Window is already expanded by the button, just init services
    _initServices();
  }

  Future<void> _initServices() async {
    // Initialize database services before UI tries to access them
    await _inboxService.init();
    await _loadMacros();
  }

  Future<void> _loadMacros() async {
    await _macroService.init();
    var macros = await _macroService.getMostUsed(limit: 10);

    // Fallback: If no "most used" (e.g. fresh install), show all/default macros
    if (macros.isEmpty) {
      print("InboxManager: No most used macros found, fetching defaults...");
      final allMacros = await _macroService.getAllMacros();
      macros = allMacros.take(10).toList();
    }

    print("InboxManager: Loaded ${macros.length} quick macros");

    if (mounted) {
      setState(() {
        _quickMacros = macros;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
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
            color: theme.scaffoldBackgroundColor, // Slate 900
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(0),
              bottomLeft: Radius.circular(0),
            ),
            border: Border(
              left: BorderSide(color: colorScheme.surface, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined,
                        color: colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: Row(
                          children: [
                            _buildTab(0, 'Notes', colorScheme),
                            _buildTab(1, 'Archive', colorScheme),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Notes List
              Expanded(
                child: StreamBuilder<List<NoteModel>>(
                  stream: _selectedTab == 0
                      ? _inboxService.watchPendingNotes()
                      : _inboxService.watchArchivedNotes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                            color: colorScheme.primary),
                      );
                    }

                    final notes = snapshot.data!;
                    // Sort descending (newest first)
                    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: colorScheme.surface,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All caught up!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedTab == 0
                                  ? 'Start recording to add notes'
                                  : 'No archived notes yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
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

                      if (!groupedNotes.containsKey(key)) {
                        groupedNotes[key] = [];
                      }
                      groupedNotes[key]!.add(note);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 10),
                      itemCount: groupedNotes.length,
                      itemBuilder: (context, index) {
                        final key = groupedNotes.keys.elementAt(index);
                        final groupNotes = groupedNotes[key]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 20, bottom: 8, top: 16),
                              child: Text(
                                key.toUpperCase(),
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
                                  onArchived: () {
                                    // Card will update via stream
                                  },
                                )),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, ColorScheme colorScheme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colorScheme.primary : Colors.grey[500],
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
