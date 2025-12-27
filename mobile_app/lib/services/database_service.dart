import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note_model.dart';

class DatabaseService {
  late Isar _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteModelSchema],
      directory: dir.path,
    );
  }

  // CRUD
  Future<void> saveNote(NoteModel note) async {
    await _isar.writeTxn(() async {
      await _isar.noteModels.put(note);
    });
  }

  Future<List<NoteModel>> getAllNotes() async {
    return await _isar.noteModels.where().sortByCreatedAtDesc().findAll();
  }
  
  Stream<List<NoteModel>> watchNotes() {
    return _isar.noteModels.where().sortByCreatedAtDesc().watch(fireImmediately: true);
  }

  Future<void> deleteNote(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.noteModels.delete(id);
    });
  }
}
