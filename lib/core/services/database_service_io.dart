import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soutnote/data/models/isar_note_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Isar? _isar;
  bool _isInitialized = false;

  Future<Isar> get isar async {
    if (!_isInitialized) {
      await init();
    }
    return _isar!;
  }

  Future<void> init() async {
    if (_isInitialized && _isar != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();

      _isar = await Isar.open(
        [isarNoteModelSchema],
        directory: dir.path,
        name: 'inbox_db',
      );

      _isInitialized = true;
    } catch (e) {
      if (e.toString().contains("Instance has already been opened")) {
        final instance = Isar.getInstance('inbox_db');
        if (instance != null) {
          _isar = instance;
          _isInitialized = true;
        } else {
          throw Exception("Failed to recover Isar instance");
        }
      } else {
        rethrow;
      }
    }
  }
}
