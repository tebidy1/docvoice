import 'dart:async';
import 'package:flutter/foundation.dart';
import '../mobile_app/models/note_model.dart';
import 'inbox_note_api_service.dart';
import 'sync_manager.dart';
import 'cache_manager.dart';

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();

  final InboxNoteApiService _apiService = InboxNoteApiService();
  final SyncManager _syncManager = SyncManager();
  final CacheManager _cacheManager = CacheManager();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _syncManager.init();
    await _cacheManager.init();
    _isInitialized = true;
  }

  // ============================================
  // Note Operations
  // ============================================

  /// Add a new note (Legacy signature)
  Future<int> addNote(
    String rawText, {
    String? patientName,
    String? summary,
    int? suggestedMacroId,
    String? formattedText,
  }) async {
    final note = NoteModel();
    note.uuid = DateTime.now().millisecondsSinceEpoch.toString();
    note.originalText = rawText;
    note.patientName = patientName ?? 'Untitled';
    note.summary = summary;
    note.suggestedMacroId = suggestedMacroId;
    note.formattedText = formattedText ?? '';
    note.status =
        note.formattedText.isNotEmpty ? NoteStatus.processed : NoteStatus.draft;
    note.createdAt = DateTime.now();
    note.updatedAt = DateTime.now();

    final createdNote = await addNoteModel(note);
    return createdNote.id;
  }

  /// Add a new note using NoteModel
  Future<NoteModel> addNoteModel(NoteModel note) async {
    await init();

    try {
      final createdNote = await _apiService.createNote(note);
      _invalidateCache();
      return createdNote;
    } catch (e) {
      debugPrint('⚠️ Network failure, queuing note for sync: $e');

      await _syncManager.addToQueue(SyncItem(
        id: note.uuid,
        endpoint: '/inbox-notes',
        operation: SyncOperation.create,
        data: note.toJson(),
        timestamp: DateTime.now(),
      ));

      return note;
    }
  }

  /// Update an existing note (Legacy signature)
  Future<void> updateNote(
    int noteId, {
    String? rawText,
    String? formattedText,
    String? patientName,
    String? summary,
    int? suggestedMacroId,
  }) async {
    final existing = await getNoteById(noteId);
    if (existing == null) return;

    if (rawText != null) existing.originalText = rawText;
    if (formattedText != null) existing.formattedText = formattedText;
    if (patientName != null) existing.patientName = patientName;
    if (summary != null) existing.summary = summary;
    if (suggestedMacroId != null) existing.suggestedMacroId = suggestedMacroId;

    if (formattedText != null && formattedText.isNotEmpty) {
      existing.status = NoteStatus.processed;
    }

    await updateNoteModel(existing);
  }

  /// Update an existing note using NoteModel
  Future<NoteModel> updateNoteModel(NoteModel note) async {
    await init();

    try {
      final updatedNote =
          await _apiService.updateNote(note.id.toString(), note);
      _invalidateCache();
      return updatedNote;
    } catch (e) {
      debugPrint('⚠️ Network failure, queuing update for sync: $e');

      await _syncManager.addToQueue(SyncItem(
        id: note.id.toString(),
        endpoint: '/inbox-notes/${note.id}',
        operation: SyncOperation.update,
        data: note.toJson(),
        timestamp: DateTime.now(),
      ));

      return note;
    }
  }

  /// Get a single note by ID
  Future<NoteModel?> getNoteById(int id) async {
    await init();
    try {
      return await _apiService.fetchNoteById(id.toString());
    } catch (e) {
      debugPrint('Error fetching note $id: $e');
      return null;
    }
  }

  /// Archive a note
  Future<void> archiveNote(int id) async {
    await init();

    try {
      await _apiService.archiveNote(id.toString());
      _invalidateCache();
    } catch (e) {
      debugPrint('⚠️ Network failure, queuing archive for sync: $e');

      await _syncManager.addToQueue(SyncItem(
        id: id.toString(),
        endpoint: '/inbox-notes/$id/archive',
        operation: SyncOperation.patch,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Update status (Desktop compatibility)
  Future<void> updateStatus(int id, NoteStatus status) async {
    await init();
    try {
      await _apiService.updateStatus(id.toString(), status);
      _invalidateCache();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  /// Delete a note
  Future<void> deleteNote(int id) async {
    await init();

    try {
      await _apiService.deleteNote(id.toString());
      _invalidateCache();
    } catch (e) {
      debugPrint('⚠️ Network failure, queuing delete for sync: $e');

      await _syncManager.addToQueue(SyncItem(
        id: id.toString(),
        endpoint: '/inbox-notes/$id',
        operation: SyncOperation.delete,
        timestamp: DateTime.now(),
      ));
    }
  }

  // ============================================
  // Fetch Operations
  // ============================================

  /// Get pending notes with caching
  Future<List<NoteModel>> getPendingNotes({bool forceRefresh = false}) async {
    await init();

    return await _cacheManager.fetchWithStrategy<List<NoteModel>>(
      cacheKey: 'pending_notes',
      strategy:
          forceRefresh ? CacheStrategy.networkFirst : CacheStrategy.cacheFirst,
      apiCall: () => _apiService.fetchPendingNotes(),
      fromJson: (json) =>
          (json as List).map((i) => NoteModelJson.fromJson(i)).toList(),
      toJson: (notes) => notes.map((n) => n.toJson()).toList(),
      cacheExpiry: const Duration(minutes: 10),
    );
  }

  /// Get archived notes with caching
  Future<List<NoteModel>> getArchivedNotes({bool forceRefresh = false}) async {
    await init();

    return await _cacheManager.fetchWithStrategy<List<NoteModel>>(
      cacheKey: 'archived_notes',
      strategy:
          forceRefresh ? CacheStrategy.networkFirst : CacheStrategy.cacheFirst,
      apiCall: () => _apiService.fetchArchivedNotes(),
      fromJson: (json) =>
          (json as List).map((i) => NoteModelJson.fromJson(i)).toList(),
      toJson: (notes) => notes.map((n) => n.toJson()).toList(),
      cacheExpiry: const Duration(minutes: 30),
    );
  }

  // ============================================
  // Real-time Streams (Polling)
  // ============================================

  /// Watch pending notes
  Stream<List<NoteModel>> watchPendingNotes() async* {
    while (true) {
      try {
        final notes = await getPendingNotes(forceRefresh: true);
        yield notes;
      } catch (e) {
        debugPrint('Error polling pending notes: $e');
        // Handle error in UI
      }
      await Future.delayed(const Duration(seconds: 10)); // Poll every 10s
    }
  }

  /// Watch archived notes
  Stream<List<NoteModel>> watchArchivedNotes() async* {
    while (true) {
      try {
        final notes = await getArchivedNotes(forceRefresh: true);
        yield notes;
      } catch (e) {
        debugPrint('Error polling archived notes: $e');
      }
      await Future.delayed(
          const Duration(seconds: 30)); // Poll every 30s for archive
    }
  }

  // ============================================
  // Helpers
  // ============================================

  void _invalidateCache() {
    _cacheManager.remove('pending_notes');
    _cacheManager.remove('archived_notes');
  }
}
