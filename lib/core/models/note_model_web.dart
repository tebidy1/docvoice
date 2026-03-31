import 'note_model_base.dart';

export 'note_model_base.dart';

// Web version - simple class extending base, no Isar
// Web version - simple class extending base, no Isar
class NoteModel extends NoteModelBase {
  // Default constructor
  NoteModel() : super();
}

// Extension methods for JSON serialization
extension NoteModelJson on NoteModel {
  /// Create NoteModel from JSON
  static NoteModel fromJson(Map<String, dynamic> json) {
    final base = NoteModelBase.fromJson(json);
    final note = NoteModel();
    note.id = base.id;
    note.uuid = base.uuid;
    note.title = base.title;
    note.content = base.content;
    note.audioPath = base.audioPath;
    note.status = base.status;
    note.createdAt = base.createdAt;
    note.updatedAt = base.updatedAt;
    note.appliedMacroId = base.appliedMacroId;
    note.originalText = base.originalText;
    note.formattedText = base.formattedText;
    return note;
  }
}
