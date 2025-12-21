import 'package:isar/isar.dart';

part 'inbox_note_io.g.dart';

@Collection()
class InboxNote {
  Id id = Isar.autoIncrement;

  late String rawText;

  String? patientName;

  String? summary;

  @Enumerated(EnumType.name)
  late InboxStatus status;

  DateTime? createdAt;

  int? suggestedMacroId;
}

enum InboxStatus {
  pending,
  processed,
  archived
}
