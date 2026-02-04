import 'base_repository.dart';
import '../../models/macro.dart';

/// Repository interface for Macro entities
abstract class MacroRepository extends BaseRepository<Macro> {
  /// Get macros by category
  Future<List<Macro>> getByCategory(String category);
  
  /// Get favorite macros
  Future<List<Macro>> getFavorites();
  
  /// Get most used macros
  Future<List<Macro>> getMostUsed({int limit = 10});
  
  /// Toggle favorite status
  Future<void> toggleFavorite(String id);
  
  /// Increment usage count
  Future<void> incrementUsage(String id);
  
  /// Get all categories
  Future<List<String>> getCategories();
  
  /// Find expansion for text
  Future<String?> findExpansion(String text);
  
  /// Search macros by trigger or content
  Future<List<Macro>> searchByTrigger(String trigger);
  
  /// Get macros as JSON string
  Future<String> getMacrosAsJson();
  
  /// Sync with remote server
  Future<void> sync();
}