import 'package:flutter/material.dart';
import '../models/inbox_note.dart';
import '../models/macro.dart';
import 'inbox_note_detail_view.dart';

class InboxCard extends StatelessWidget {
  final InboxNote note;
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
    final isProcessed = note.status == InboxStatus.processed || note.status == InboxStatus.archived;
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => _openDetailView(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                                note.patientName ?? 'Unknown Patient',
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
          
          // Quick Actions Divider
          if (quickMacros.isNotEmpty)
            Divider(height: 1, color: Colors.white.withOpacity(0.05)),
            
          // Quick Actions (Most Used Templates)
          if (quickMacros.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on, size: 14, color: Colors.amber.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: quickMacros.map((macro) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openDetailView(context, autoStartMacro: macro),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        macro.trigger,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDetailView(BuildContext context, {Macro? autoStartMacro}) async {
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
