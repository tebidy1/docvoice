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

// Schema export for database service
final noteModelSchema = NoteModelSchema;
