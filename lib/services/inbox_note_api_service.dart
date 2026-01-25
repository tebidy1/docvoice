import 'package:flutter/foundation.dart';
import '../mobile_app/models/note_model.dart';
import 'base_api_service.dart';

/// API Service for Inbox Notes
///
/// Provides methods to interact with the inbox notes API endpoints.
/// Extends BaseApiService for common CRUD operations.
///
/// Example usage:
/// ```dart
/// final service = InboxNoteApiService();
/// final notes = await service.fetchPendingNotes();
/// ```
class InboxNoteApiService extends BaseApiService {
  @override
  String get baseEndpoint => '/inbox-notes';

  // ============================================
  // Fetch Operations
  // ============================================

  /// Fetch all pending (non-archived) notes
  Future<List<NoteModel>> fetchPendingNotes() async {
    return await customGet<List<NoteModel>>(
      endpoint: '$baseEndpoint/pending',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => NoteModelJson.fromJson(item)).toList();
      },
    );
  }

  /// Fetch all archived notes
  Future<List<NoteModel>> fetchArchivedNotes() async {
    return await customGet<List<NoteModel>>(
      endpoint: '$baseEndpoint/archived',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => NoteModelJson.fromJson(item)).toList();
      },
    );
  }

  /// Fetch all notes (pending and archived)
  Future<List<NoteModel>> fetchAllNotes() async {
    return await fetchAll<NoteModel>(
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  /// Fetch a single note by ID
  Future<NoteModel> fetchNoteById(String id) async {
    return await fetchById<NoteModel>(
      id: id,
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  // ============================================
  // Create & Update Operations
  // ============================================

  /// Create a new note
  Future<NoteModel> createNote(NoteModel note) async {
    return await create<NoteModel>(
      data: note.toJson(),
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  /// Update an existing note
  Future<NoteModel> updateNote(String id, NoteModel note) async {
    return await update<NoteModel>(
      id: id,
      data: note.toJson(),
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  // ============================================
  // Status Operations
  // ============================================

  /// Archive a note
  Future<NoteModel> archiveNote(String id) async {
    return await patch<NoteModel>(
      endpoint: '$baseEndpoint/$id/archive',
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  /// Update note status
  Future<NoteModel> updateStatus(String id, NoteStatus status) async {
    return await patch<NoteModel>(
      endpoint: '$baseEndpoint/$id/status',
      data: {'status': status.toString().split('.').last},
      fromJson: (json) => NoteModelJson.fromJson(json),
    );
  }

  // ============================================
  // Delete Operations
  // ============================================

  /// Delete a note permanently
  Future<bool> deleteNote(String id) async {
    return await delete(id: id);
  }

  // ============================================
  // Batch Operations
  // ============================================

  /// Archive multiple notes at once
  Future<List<NoteModel>> archiveMultiple(List<String> ids) async {
    final results = <NoteModel>[];

    for (final id in ids) {
      try {
        final note = await archiveNote(id);
        results.add(note);
      } catch (e) {
        // Continue with other notes even if one fails
        debugPrint('Failed to archive note $id: $e');
      }
    }

    return results;
  }

  /// Delete multiple notes at once
  Future<int> deleteMultiple(List<String> ids) async {
    int successCount = 0;

    for (final id in ids) {
      try {
        final success = await deleteNote(id);
        if (success) successCount++;
      } catch (e) {
        debugPrint('Failed to delete note $id: $e');
      }
    }

    return successCount;
  }
}
