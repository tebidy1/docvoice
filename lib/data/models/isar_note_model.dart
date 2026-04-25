import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:soutnote/core/entities/generated_output.dart';
import 'package:soutnote/core/entities/note_model.dart';

part 'isar_note_model.g.dart';

@collection
class IsarNoteModel extends NoteModel {
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

  @ignore
  @override
  List<GeneratedOutput> generatedOutputs = [];

  List<String> get generatedOutputsJson =>
      generatedOutputs.map((e) => jsonEncode(e.toJson())).toList();
  set generatedOutputsJson(List<String> jsons) {
    generatedOutputs =
        jsons.map((e) => GeneratedOutput.fromJson(jsonDecode(e))).toList();
  }
}

// Extension methods for JSON serialization
extension IsarNoteModelJson on IsarNoteModel {
  /// Create IsarNoteModel from JSON
  static IsarNoteModel fromJson(Map<String, dynamic> json) {
    final base = NoteModel.fromJson(json);
    final note = IsarNoteModel();
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
    note.generatedOutputs = base.generatedOutputs;
    return note;
  }
}

// Schema export for database service
final isarNoteModelSchema = IsarNoteModelSchema;