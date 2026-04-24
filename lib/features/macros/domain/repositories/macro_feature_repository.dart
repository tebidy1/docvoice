import '../entities/macro_entity.dart';

abstract class MacroFeatureRepository {
  Future<List<MacroEntity>> getAll();
  Future<MacroEntity?> getById(String id);
  Future<MacroEntity> create(MacroEntity entity);
  Future<MacroEntity> update(MacroEntity entity);
  Future<void> delete(String id);
  Future<List<MacroEntity>> getByCategory(String category);
  Future<List<MacroEntity>> getFavorites();
  Future<List<MacroEntity>> searchByTrigger(String trigger);
  Future<void> toggleFavorite(String id);
  Future<void> incrementUsage(String id);
  Future<void> sync();
}
