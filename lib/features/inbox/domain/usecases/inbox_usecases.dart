import '../entities/inbox_note_entity.dart';
import '../repositories/inbox_feature_repository.dart';

class GetInboxNotesByStatusUseCase {
  final InboxFeatureRepository _repository;
  GetInboxNotesByStatusUseCase(this._repository);

  Future<List<InboxNoteEntity>> execute(InboxNoteStatus status) =>
      _repository.getByStatus(status);
}

class GetRecentInboxNotesUseCase {
  final InboxFeatureRepository _repository;
  GetRecentInboxNotesUseCase(this._repository);

  Future<List<InboxNoteEntity>> execute({int limit = 20}) =>
      _repository.getRecent(limit: limit);
}

class CreateInboxNoteUseCase {
  final InboxFeatureRepository _repository;
  CreateInboxNoteUseCase(this._repository);

  Future<InboxNoteEntity> execute(InboxNoteEntity note) =>
      _repository.create(note);
}

class UpdateInboxNoteUseCase {
  final InboxFeatureRepository _repository;
  UpdateInboxNoteUseCase(this._repository);

  Future<InboxNoteEntity> execute(InboxNoteEntity note) =>
      _repository.update(note);
}

class DeleteInboxNoteUseCase {
  final InboxFeatureRepository _repository;
  DeleteInboxNoteUseCase(this._repository);

  Future<void> execute(String id) => _repository.delete(id);
}

class ArchiveInboxNoteUseCase {
  final InboxFeatureRepository _repository;
  ArchiveInboxNoteUseCase(this._repository);

  Future<void> execute(String id) => _repository.archive(id);
}

class SearchInboxNotesUseCase {
  final InboxFeatureRepository _repository;
  SearchInboxNotesUseCase(this._repository);

  Future<List<InboxNoteEntity>> execute(String query) =>
      _repository.searchByContent(query);
}

class SyncInboxNotesUseCase {
  final InboxFeatureRepository _repository;
  SyncInboxNotesUseCase(this._repository);

  Future<void> execute() => _repository.sync();
}
