import 'package:isar/isar.dart';
import 'note_model_base.dart';

export 'note_model_base.dart';

part 'note_model_mobile.g.dart';

@collection
class NoteModel extends NoteModelBase {
  @override
  Id get id => super.id;

  @override
  set id(int value) => super.id = value;

  @Index()
  @override
  late String uuid;

  @Enumerated(EnumType.name)
  @override
  late NoteStatus status;
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

// Schema export for database service
final noteModelSchema = NoteModelSchema;
