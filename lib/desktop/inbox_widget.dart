import 'package:flutter/material.dart';
import '../models/inbox_note.dart';
import '../services/inbox_service.dart';
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
  int _selectedTab = 0; // 0: Notes, 1: Archive (Force Update)

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteModel>>(
      stream: _selectedTab == 0
          ? _inboxService.watchPendingNotes()
          : _inboxService.watchArchivedNotes(),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? [];
        final count = notes.length;

        if (!widget.isExpanded) {
          // Collapsed state: floating pill
          return Positioned(
            right: 20,
            bottom: 80,
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xDD1E1E1E),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                      color: count > 0
                          ? Colors.orange.withOpacity(0.6)
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
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.inbox, color: Colors.white70, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      count > 0 ? '$count' : 'Inbox',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Expanded state: side panel
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
                  colors: [
                    const Color(0xFF2A2A2A),
                    const Color(0xFF1A1A1A),
                  ],
                ),
                border: Border(
                  left: BorderSide(
                      color: Colors.amber.withOpacity(0.3), width: 2),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.withOpacity(0.15),
                          Colors.amber.withOpacity(0.05),
                        ],
                      ),
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.amber.withOpacity(0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inbox, color: Colors.amber, size: 24),
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
                                _buildTab(0, 'Notes', count),
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

                  // Notes list
                  Expanded(
                    child: notes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox,
                                    color: Colors.white30, size: 60),
                                const SizedBox(height: 16),
                                const Text(
                                  'All caught up!',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTab == 0
                                      ? 'Start recording to add notes'
                                      : 'No archived notes yet',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
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
                                onArchived: () {
                                  // Card will automatically update via stream
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
      },
    );
  }

  Widget _buildTab(int index, String label, int? count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.amber : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count != null && count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
