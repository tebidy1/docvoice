import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/macro.dart';
import '../mobile_app/models/note_model.dart';

/// Centralized database service to manage Isar instance
/// This prevents schema conflicts between MacroService and InboxService
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
    if (_isInitialized && _isar != null) {
      print("DatabaseService: Already initialized");
      return;
    }

    print("DatabaseService: Initializing with all schemas...");

    try {
      final dir = await getApplicationDocumentsDirectory();
      print("DatabaseService: Opening DB at ${dir.path}");

      _isar = await Isar.open(
        [MacroSchema, noteModelSchema],
        directory: dir.path,
        name: 'inbox_db', // Keep original name to preserve existing data
      );

      _isInitialized = true;
      print("DatabaseService: ✅ Initialized successfully");
    } catch (e) {
      if (e.toString().contains("Instance has already been opened")) {
        print("DatabaseService: Recovering existing instance...");
        final instance = Isar.getInstance('inbox_db');
        if (instance != null) {
          _isar = instance;
          _isInitialized = true;
          print("DatabaseService: ✅ Recovered successfully");
        } else {
          throw Exception("Failed to recover Isar instance");
        }
      } else {
        print("DatabaseService: ❌ Error: $e");
        rethrow;
      }
    }
  }
}
