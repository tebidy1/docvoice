import 'note_model.dart';

export 'note_model.dart';

/// Legacy compatibility for Desktop app
typedef InboxNote = NoteModel;

/// Legacy compatibility for Desktop app
enum InboxStatus { pending, processed, archived }
