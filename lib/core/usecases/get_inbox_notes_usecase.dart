import '../repositories/inbox_note_repository.dart';
import '../entities/inbox_note.dart';

class GetInboxNotesUseCase {
  final InboxNoteRepository _inboxNoteRepository;

  GetInboxNotesUseCase(this._inboxNoteRepository);

  Future<List<InboxNote>> execute() async {
    return await _inboxNoteRepository.getAll();
  }

  Future<List<InboxNote>> getByStatus(NoteStatus status) async {
    return await _inboxNoteRepository.getByStatus(status);
  }

  Future<List<InboxNote>> getRecent({int limit = 20}) async {
    return await _inboxNoteRepository.getRecent(limit: limit);
  }
}
