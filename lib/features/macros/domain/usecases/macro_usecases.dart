import '../entities/macro_entity.dart';
import '../repositories/macro_feature_repository.dart';

class GetMacrosByCategoryUseCase {
  final MacroFeatureRepository _repository;
  GetMacrosByCategoryUseCase(this._repository);

  Future<List<MacroEntity>> execute(String category) =>
      _repository.getByCategory(category);
}

class GetFavoriteMacrosUseCase {
  final MacroFeatureRepository _repository;
  GetFavoriteMacrosUseCase(this._repository);

  Future<List<MacroEntity>> execute() => _repository.getFavorites();
}

class CreateMacroUseCase {
  final MacroFeatureRepository _repository;
  CreateMacroUseCase(this._repository);

  Future<MacroEntity> execute(MacroEntity macro) => _repository.create(macro);
}

class UpdateMacroUseCase {
  final MacroFeatureRepository _repository;
  UpdateMacroUseCase(this._repository);

  Future<MacroEntity> execute(MacroEntity macro) => _repository.update(macro);
}

class DeleteMacroUseCase {
  final MacroFeatureRepository _repository;
  DeleteMacroUseCase(this._repository);

  Future<void> execute(String id) => _repository.delete(id);
}

class ToggleMacroFavoriteUseCase {
  final MacroFeatureRepository _repository;
  ToggleMacroFavoriteUseCase(this._repository);

  Future<void> execute(String id) => _repository.toggleFavorite(id);
}

class SearchMacrosUseCase {
  final MacroFeatureRepository _repository;
  SearchMacrosUseCase(this._repository);

  Future<List<MacroEntity>> execute(String trigger) =>
      _repository.searchByTrigger(trigger);
}

class SyncMacrosUseCase {
  final MacroFeatureRepository _repository;
  SyncMacrosUseCase(this._repository);

  Future<void> execute() => _repository.sync();
}
