import 'package:isar/isar.dart';

part 'note_model.g.dart';

enum NoteStatus {
  draft,      // Initial recording or raw text
  processed,  // AI macro applied
  ready,      // Confirmed by user, waiting to sync
  archived    // Synced/Completed
}

@collection
class NoteModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String uuid; // Sync UUID

  late String title; // E.g. "Recording 1" or Patient Name
  
  late String content; // The text body
  
  String? audioPath; // Path to local .m4a file
  
  @Enumerated(EnumType.name)
  late NoteStatus status;
  
  late DateTime createdAt;
  late DateTime updatedAt;

  // Metadata for AI
  String? appliedMacroId;
}
