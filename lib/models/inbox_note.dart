import '../mobile_app/models/note_model.dart';

/// Unified Inbox Note model
/// Exports the correct implementation based on the platform
export '../mobile_app/models/note_model.dart';

/// Legacy compatibility for Desktop app
typedef InboxNote = NoteModel;

/// Legacy compatibility for Desktop app
enum InboxStatus { pending, processed, archived }
