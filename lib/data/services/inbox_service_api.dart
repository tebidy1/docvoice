import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:soutnote/core/entities/note_model.dart';
import 'package:soutnote/core/entities/generated_output.dart';
import 'inbox_note_api_service.dart';
import 'package:soutnote/core/services/sync_manager.dart';
import 'package:soutnote/core/services/cache_manager.dart';

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();

  final InboxNoteApiClient _ApiClient = InboxNoteApiClient();
  final SyncManager _syncManager = SyncManager();
  final CacheManager _cacheManager = CacheManager();

  bool _isInitialized = false;

  // ============================================
  // Pagination State
  // ============================================

  int _pendingCurrentPage = 1;
  int _pendingLastPage = 1;
  int _pendingTotal = 0;
  int _pendingPerPage = 15;
  bool _pendingLoading = false;
  List<NoteModel> _pendingItems = [];

  List<NoteModel> get pendingItems => _pendingItems;
  int get pendingCurrentPage => _pendingCurrentPage;
  int get pendingLastPage => _pendingLastPage;
  int get pendingTotal => _pendingTotal;
  int get pendingPerPage => _pendingPerPage;
  bool get pendingLoading => _pendingLoading;
  bool get hasPreviousPage => _pendingCurrentPage > 1;
  bool get hasNextPage => _pendingCurrentPage < _pendingLastPage;

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
  Future<NoteModel> addNote(
    String rawText, {
    String? patientName,
    String? summary,
    int? suggestedMacroId,
    String? formattedText,
    String? audioPath,
    List<Map<String, dynamic>>? generatedOutputs,
  }) async {
    final note = NoteModel();
    note.uuid = DateTime.now().millisecondsSinceEpoch.toString();
    note.originalText = rawText;
    note.patientName = patientName ?? 'Untitled';
    note.summary = summary;
    note.suggestedMacroId = suggestedMacroId;
    note.formattedText = formattedText ?? '';
    note.audioPath = audioPath;
    if (generatedOutputs != null) {
      note.generatedOutputs =
          generatedOutputs.map((e) => GeneratedOutput.fromJson(e)).toList();
    }
    note.content = note.formattedText.isNotEmpty
        ? note.formattedText
        : note.originalText;
    note.status =
        note.formattedText.isNotEmpty ? NoteStatus.processed : NoteStatus.pending;
    note.createdAt = DateTime.now();
    note.updatedAt = DateTime.now();

    final createdNote = await addNoteModel(note);
    return createdNote;
  }

  /// Add a new note using NoteModel
  Future<NoteModel> addNoteModel(NoteModel note) async {
    await init();

    try {
      final createdNote = await _ApiClient.createNote(note);
      _invalidateCache();
      refresh();
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
  Future<NoteModel?> updateNote(
    int noteId, {
    String? rawText,
    String? formattedText,
    String? patientName,
    String? summary,
    int? suggestedMacroId,
    List<Map<String, dynamic>>? generatedOutputs,
  }) async {
    print('🔄 [InboxService] updateNote called for ID: $noteId');
    final existing = await getNoteById(noteId);
    if (existing == null) {
      print(
          '❌ [InboxService] updateNote failed: existing note is null for ID $noteId');
      return null;
    }

    if (rawText != null) existing.originalText = rawText;
    if (formattedText != null) existing.formattedText = formattedText;
    if (patientName != null) existing.patientName = patientName;
    if (summary != null) existing.summary = summary;
    if (suggestedMacroId != null) existing.suggestedMacroId = suggestedMacroId;
    if (generatedOutputs != null) {
      existing.generatedOutputs =
          generatedOutputs.map((e) => GeneratedOutput.fromJson(e)).toList();
    }

    if (formattedText != null && formattedText.isNotEmpty) {
      existing.status = NoteStatus.processed;
    }

    return await updateNoteModel(existing);
  }

  /// Update an existing note using NoteModel
  Future<NoteModel> updateNoteModel(NoteModel note) async {
    await init();

    try {
      final updatedNote = await _ApiClient.updateNote(note.id.toString(), note);
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
      return await _ApiClient.fetchNoteById(id.toString());
    } catch (e) {
      debugPrint('Error fetching note $id: $e');
      return null;
    }
  }

  /// Apply a macro to a note via backend API
  /// Returns the updated NoteModel with generated outputs
  Future<NoteModel?> applyMacro(int noteId, int macroId) async {
    await init();

    try {
      final updatedNote =
          await _ApiClient.applyMacro(noteId.toString(), macroId);
      _invalidateCache();
      refresh();
      return updatedNote;
    } catch (e) {
      debugPrint('⚠️ Network failure applying macro: $e');

      await _syncManager.addToQueue(SyncItem(
        id: '${noteId}_apply_macro_$macroId',
        endpoint: '/inbox-notes/$noteId/apply-macro',
        operation: SyncOperation.create,
        data: {'macro_id': macroId},
        timestamp: DateTime.now(),
      ));

      return null;
    }
  }

  /// Archive a note
  Future<void> archiveNote(int id) async {
    await init();

    try {
      await _ApiClient.archiveNote(id.toString());
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
      await _ApiClient.updateStatus(id.toString(), status);
      _invalidateCache();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  /// Delete a note
  Future<void> deleteNote(int id) async {
    await init();

    try {
      await _ApiClient.deleteNote(id.toString());
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
  // Paginated Fetch Operations
  // ============================================

  /// Fetch a specific page of pending notes
  Future<void> goToPendingPage(int page) async {
    await init();
    _pendingLoading = true;
    _pendingController.add(this);

    try {
      final result = await _ApiClient.fetchPendingNotesPaginated(
        page: page,
        perPage: _pendingPerPage,
      );
      _pendingItems = result.items;
      _pendingCurrentPage = result.currentPage;
      _pendingLastPage = result.lastPage;
      _pendingTotal = result.total;
      _pendingPerPage = result.perPage;
    } catch (e) {
      debugPrint('Error fetching page $page: $e');
      _pendingItems = [];
      _pendingCurrentPage = 1;
      _pendingLastPage = 1;
      _pendingTotal = 0;
    }
    _pendingLoading = false;
    _pendingController.add(this);
  }

  /// Go to next page of pending notes
  Future<void> nextPendingPage() async {
    if (!hasNextPage) return;
    await goToPendingPage(_pendingCurrentPage + 1);
  }

  /// Go to previous page of pending notes
  Future<void> previousPendingPage() async {
    if (!hasPreviousPage) return;
    await goToPendingPage(_pendingCurrentPage - 1);
  }

  /// Fetch a specific page of archived notes
  Future<List<NoteModel>> goToArchivedPage(int page) async {
    await init();

    try {
      final result = await _ApiClient.fetchArchivedNotesPaginated(
        page: page,
        perPage: 15,
      );
      return result.items;
    } catch (e) {
      debugPrint('Error fetching archived page $page: $e');
      return [];
    }
  }

  /// Get pending notes with caching (legacy - fetches all at once)
  Future<List<NoteModel>> getPendingNotes({bool forceRefresh = false}) async {
    await init();

    return await _cacheManager.fetchWithStrategy<List<NoteModel>>(
      cacheKey: 'pending_notes',
      strategy:
          forceRefresh ? CacheStrategy.networkFirst : CacheStrategy.cacheFirst,
      apiCall: () => _ApiClient.fetchPendingNotes(),
      fromJson: (json) =>
          (json as List).map((i) => NoteModel.fromJson(i)).toList(),
      toJson: (notes) => notes.map((n) => n.toJson()).toList(),
      cacheExpiry: const Duration(minutes: 10),
    );
  }

  /// Get archived notes with caching (legacy)
  Future<List<NoteModel>> getArchivedNotes({bool forceRefresh = false}) async {
    await init();

    return await _cacheManager.fetchWithStrategy<List<NoteModel>>(
      cacheKey: 'archived_notes',
      strategy:
          forceRefresh ? CacheStrategy.networkFirst : CacheStrategy.cacheFirst,
      apiCall: () => _ApiClient.fetchArchivedNotes(),
      fromJson: (json) =>
          (json as List).map((i) => NoteModel.fromJson(i)).toList(),
      toJson: (notes) => notes.map((n) => n.toJson()).toList(),
      cacheExpiry: const Duration(minutes: 30),
    );
  }

  // ============================================
  // Reactive State (Page-based)
  // ============================================

  final _pendingController = StreamController<InboxService>.broadcast();

  /// Watch the InboxService state for reactive UI updates
  Stream<InboxService> watch() {
    return _pendingController.stream;
  }

  /// Manually trigger a refresh (goes back to page 1)
  Future<void> refresh() async {
    await goToPendingPage(1);
  }

  // ============================================
  // Legacy Stream Support (for backward compat)
  // ============================================

  final _pendingNotesLegacyController =
      StreamController<List<NoteModel>>.broadcast();
  Timer? _pollingTimer;

  /// Legacy stream that emits all pending notes (no pagination)
  Stream<List<NoteModel>> watchPendingNotes() {
    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _startPolling();
    }
    return _pendingNotesLegacyController.stream;
  }

  void _startPolling() async {
    try {
      final cachedNotes = await getPendingNotes(forceRefresh: false);
      if (cachedNotes.isNotEmpty) {
        _pendingNotesLegacyController.add(cachedNotes);
      }
    } catch (e) {
      debugPrint('Cache load failed: $e');
    }
    _refreshPendingNotesLegacy();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshPendingNotesLegacy();
    });
  }

  Future<void> _refreshPendingNotesLegacy() async {
    try {
      final notes = await getPendingNotes(forceRefresh: true);
      _pendingNotesLegacyController.add(notes);
    } catch (e) {
      debugPrint('Error refreshing pending notes: $e');
    }
  }

  /// Watch archived notes (legacy)
  Stream<List<NoteModel>> watchArchivedNotes() async* {
    while (true) {
      try {
        final notes = await getArchivedNotes(forceRefresh: true);
        yield notes;
      } catch (e) {
        debugPrint('Error polling archived notes: $e');
      }
      await Future.delayed(const Duration(seconds: 30));
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
