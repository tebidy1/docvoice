import '../entities/inbox_note_entity.dart';

abstract class InboxFeatureRepository {
  Future<List<InboxNoteEntity>> getAll();
  Future<InboxNoteEntity?> getById(String id);
  Future<InboxNoteEntity> create(InboxNoteEntity entity);
  Future<InboxNoteEntity> update(InboxNoteEntity entity);
  Future<void> delete(String id);
  Future<List<InboxNoteEntity>> getByStatus(InboxNoteStatus status);
  Future<List<InboxNoteEntity>> getRecent({int limit = 20});
  Future<void> updateStatus(String id, InboxNoteStatus status);
  Future<void> archive(String id);
  Future<List<InboxNoteEntity>> searchByContent(String query);
  Future<void> sync();
}
