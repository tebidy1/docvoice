/// Web-compatible stub for InboxNote
/// On web, Isar is not supported, so this is a simple class without database annotations

class InboxNote {
  int id = 0;
  late String rawText;
  String? patientName;
  String? summary;
  late InboxStatus status;
  DateTime? createdAt;
  int? suggestedMacroId;

  InboxNote({
    this.id = 0,
    this.rawText = '',
    this.patientName,
    this.summary,
    this.status = InboxStatus.pending,
    this.createdAt,
    this.suggestedMacroId,
  });
}

enum InboxStatus {
  pending,
  processed,
  archived
}
