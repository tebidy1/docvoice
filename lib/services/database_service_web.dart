import 'package:flutter/foundation.dart' show kIsWeb;

/// Web-compatible stub for DatabaseService
/// On web, Isar is not supported, so this is a no-op implementation
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  bool _isInitialized = false;

  /// On web, this returns a stub
  Future<dynamic> get isar async {
    if (!_isInitialized) {
      await init();
    }
    return null; // Web doesn't support Isar
  }

  Future<void> init() async {
    if (_isInitialized) {
      print("DatabaseService (Web): Stub - no database on web");
      return;
    }
    
    print("DatabaseService (Web): Initializing stub (no actual database)...");
    _isInitialized = true;
    print("DatabaseService (Web): ✅ Stub initialized");
  }
}
