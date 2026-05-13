import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soutnote/core/entities/note_model.dart';
import '../../core/entities/macro.dart';
import '../../core/services/inbox_service.dart';
import '../../core/services/macro_service.dart';
import 'inbox_card.dart';

class InboxWidget extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const InboxWidget(
      {super.key, required this.isExpanded, required this.onToggle});

  @override
  State<InboxWidget> createState() => _InboxWidgetState();
}

class _InboxWidgetState extends State<InboxWidget> {
  final _inboxService = InboxService();
  final _macroService = MacroService();
  int _selectedTab = 0;
  List<Macro> _allMacros = [];
  List<NoteModel> _pendingNotes = [];
  List<NoteModel> _archivedNotesData = [];
  bool _pendingLoading = false;
  bool _archivedLoading = false;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadMacros();
    _inboxService.init().then((_) => _inboxService.goToPendingPage(1));
    _stateSub = _inboxService.watch().listen((service) {
      if (mounted) {
        setState(() {
          _pendingNotes = service.pendingItems;
          _pendingLoading = service.pendingLoading;
        });
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMacros() async {
    await _macroService.init();
    final macros = await _macroService.getAllMacros();
    if (mounted) setState(() => _allMacros = macros);
  }

  Future<void> _switchTab(int index) async {
    setState(() => _selectedTab = index);
    if (index == 0) {
      await _inboxService.goToPendingPage(1);
    } else if (index == 1) {
      setState(() => _archivedLoading = true);
      final items = await _inboxService.goToArchivedPage(1);
      if (mounted) setState(() { _archivedNotesData = items; _archivedLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _selectedTab == 0 ? _pendingNotes : _archivedNotesData;
    final count = notes.length;
    final svc = _inboxService;

    if (!widget.isExpanded) {
      return Positioned(
        right: 20,
        bottom: 80,
        child: GestureDetector(
          onTap: widget.onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xDD1E1E1E),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                  color: count > 0
                      ? const Color(0xFF00A5FE).withOpacity(0.6)
                      : Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 0)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A5FE),
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.inbox, color: Colors.white70, size: 20),
                const SizedBox(width: 6),
                Text(
                  count > 0 ? '$count' : 'Inbox',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isLoading = _selectedTab == 0 ? _pendingLoading : _archivedLoading;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Material(
        elevation: 20,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
            ),
            border: Border(
              left: BorderSide(color: const Color(0xFF00A5FE).withOpacity(0.3), width: 2),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00A5FE).withOpacity(0.15),
                      const Color(0xFF00A5FE).withOpacity(0.05),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFF00A5FE).withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inbox, color: Color(0xFF00A5FE), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            _buildTab(0, 'Notes', svc.pendingTotal),
                            _buildTab(1, 'Archive', null),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onToggle,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading && notes.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox, color: Colors.white30, size: 60),
                                const SizedBox(height: 16),
                                const Text('All caught up!',
                                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTab == 0 ? 'Start recording to add notes' : 'No archived notes yet',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              return InboxCard(
                                note: notes[index],
                                noteNumber: svc.pendingTotal - index,
                                quickMacros: _allMacros,
                                onArchived: () {},
                              );
                            },
                          ),
              ),
              if (_selectedTab == 0 && svc.pendingTotal > 0)
                _buildPagination(svc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(InboxService svc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 18),
            onPressed: svc.hasPreviousPage ? () => svc.previousPendingPage() : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text(
            '${svc.pendingCurrentPage} / ${svc.pendingLastPage}',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
            onPressed: svc.hasNextPage ? () => svc.nextPendingPage() : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text(
            '${svc.pendingTotal} total',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int? count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00A5FE).withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00A5FE) : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A5FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
