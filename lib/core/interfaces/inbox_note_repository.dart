import 'base_repository.dart';
import '../../models/inbox_note.dart';

/// Repository interface for InboxNote entities
abstract class InboxNoteRepository extends BaseRepository<InboxNote> {
  /// Get notes by status
  Future<List<InboxNote>> getByStatus(NoteStatus status);
  
  /// Get recent notes
  Future<List<InboxNote>> getRecent({int limit = 20});
  
  /// Update note status
  Future<void> updateStatus(String id, NoteStatus status);
  
  /// Archive note
  Future<void> archive(String id);
  
  /// Get notes by date range
  Future<List<InboxNote>> getByDateRange(DateTime start, DateTime end);
  
  /// Search notes by content
  Future<List<InboxNote>> searchByContent(String query);
  
  /// Get notes with audio
  Future<List<InboxNote>> getNotesWithAudio();
  
  /// Apply macro to note
  Future<void> applyMacro(String noteId, String macroId);
  
  /// Sync with remote server
  Future<void> sync();
}