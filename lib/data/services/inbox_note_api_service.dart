import 'package:flutter/foundation.dart';
import 'package:soutnote/core/entities/note_model.dart';
import 'package:soutnote/data/models/interfaces/paginated_response.dart';
import 'base_api_service.dart';

/// API Service for Inbox Notes
///
/// Provides methods to interact with the inbox notes API endpoints.
/// Extends BaseApiClient for common CRUD operations.
///
/// Example usage:
/// ```dart
/// final service = InboxNoteApiClient();
/// final notes = await service.fetchPendingNotes();
/// ```
class InboxNoteApiClient extends BaseApiClient {
  @override
  String get baseEndpoint => '/inbox-notes';

  // ============================================
  // Fetch Operations
  // ============================================

  /// Fetch all pending (non-archived) notes (legacy - fetches all at once)
  Future<List<NoteModel>> fetchPendingNotes() async {
    return await customGet<List<NoteModel>>(
      endpoint: '$baseEndpoint/pending',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => NoteModel.fromJson(item)).toList();
      },
    );
  }

  /// Fetch pending notes with pagination
  Future<PaginatedResponse<NoteModel>> fetchPendingNotesPaginated({
    int page = 1,
    int perPage = 15,
  }) async {
    return await customGet<PaginatedResponse<NoteModel>>(
      endpoint: '$baseEndpoint/pending',
      queryParams: {'page': '$page', 'per_page': '$perPage'},
      fromJson: (json) => PaginatedResponse.fromJson(
        json,
        (e) => NoteModel.fromJson(e as Map<String, dynamic>),
      ),
    );
  }

  /// Fetch all archived notes (legacy)
  Future<List<NoteModel>> fetchArchivedNotes() async {
    return await customGet<List<NoteModel>>(
      endpoint: '$baseEndpoint/archived',
      fromJson: (json) {
        final List<dynamic> data = json is List ? json : (json['data'] ?? []);
        return data.map((item) => NoteModel.fromJson(item)).toList();
      },
    );
  }

  /// Fetch archived notes with pagination
  Future<PaginatedResponse<NoteModel>> fetchArchivedNotesPaginated({
    int page = 1,
    int perPage = 15,
  }) async {
    return await customGet<PaginatedResponse<NoteModel>>(
      endpoint: '$baseEndpoint/archived',
      queryParams: {'page': '$page', 'per_page': '$perPage'},
      fromJson: (json) => PaginatedResponse.fromJson(
        json,
        (e) => NoteModel.fromJson(e as Map<String, dynamic>),
      ),
    );
  }

  /// Fetch all notes (pending and archived)
  Future<List<NoteModel>> fetchAllNotes() async {
    return await fetchAll<NoteModel>(
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  /// Fetch a single note by ID
  Future<NoteModel> fetchNoteById(String id) async {
    return await fetchById<NoteModel>(
      id: id,
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  // ============================================
  // Create & Update Operations
  // ============================================

  /// Create a new note
  Future<NoteModel> createNote(NoteModel note) async {
    return await create<NoteModel>(
      data: note.toJson(),
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  /// Update an existing note
  Future<NoteModel> updateNote(String id, NoteModel note) async {
    final payload = note.toJson();
    payload.remove(
        'uuid'); // Prevent Laravel "uuid has already been taken" validation error

    return await update<NoteModel>(
      id: id,
      data: payload,
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  // ============================================
  // Status Operations
  // ============================================

  /// Archive a note
  Future<NoteModel> archiveNote(String id) async {
    return await patch<NoteModel>(
      endpoint: '$baseEndpoint/$id/archive',
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  /// Update note status
  Future<NoteModel> updateStatus(String id, NoteStatus status) async {
    return await patch<NoteModel>(
      endpoint: '$baseEndpoint/$id/status',
      data: {'status': status.toString().split('.').last},
      fromJson: (json) => NoteModel.fromJson(json),
    );
  }

  // ============================================
  // Macro Application
  // ============================================

  /// Apply a macro to a note via backend API
  /// Calls POST /inbox-notes/{id}/apply-macro with { macro_id }
  /// Returns the updated NoteModel with generated outputs
  Future<NoteModel> applyMacro(String noteId, int macroId) async {
    return await customPost<NoteModel>(
      endpoint: '$baseEndpoint/$noteId/apply-macro',
      data: {'macro_id': macroId},
      fromJson: (json) => NoteModel.fromJson(json),
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
