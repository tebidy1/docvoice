import '../../domain/entities/macro_entity.dart';
import '../../domain/repositories/macro_feature_repository.dart';
import '../datasources/macro_remote_datasource.dart';
import '../models/macro_dto.dart';

class MacroFeatureRepositoryImpl implements MacroFeatureRepository {
  final MacroRemoteDataSource _remoteDataSource;

  MacroFeatureRepositoryImpl({required MacroRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<MacroEntity>> getAll() async {
    final rawData = await _remoteDataSource.getAll();
    return rawData.map((json) => MacroDto.fromJson(json).toEntity()).toList();
  }

  @override
  Future<MacroEntity?> getById(String id) async {
    final raw = await _remoteDataSource.getById(id);
    final data = raw['data'] ?? raw['payload'] ?? raw;
    if (data is Map<String, dynamic>) {
      return MacroDto.fromJson(data).toEntity();
    }
    return null;
  }

  @override
  Future<MacroEntity> create(MacroEntity entity) async {
    final dto = MacroDto.fromEntity(entity);
    final response = await _remoteDataSource.create(dto.toJson());
    final data = response['data'] ?? response['payload'] ?? response;
    return MacroDto.fromJson(data is Map<String, dynamic> ? data : dto.toJson()).toEntity();
  }

  @override
  Future<MacroEntity> update(MacroEntity entity) async {
    final dto = MacroDto.fromEntity(entity);
    final response = await _remoteDataSource.update(entity.id.toString(), dto.toJson());
    final data = response['data'] ?? response['payload'] ?? response;
    return MacroDto.fromJson(data is Map<String, dynamic> ? data : dto.toJson()).toEntity();
  }

  @override
  Future<void> delete(String id) async {
    await _remoteDataSource.delete(id);
  }

  @override
  Future<List<MacroEntity>> getByCategory(String category) async {
    final rawData = await _remoteDataSource.getByCategory(category);
    return rawData.map((json) => MacroDto.fromJson(json).toEntity()).toList();
  }

  @override
  Future<List<MacroEntity>> getFavorites() async {
    final all = await getAll();
    return all.where((m) => m.isFavorite).toList();
  }

  @override
  Future<List<MacroEntity>> searchByTrigger(String trigger) async {
    final all = await getAll();
    return all.where((m) => m.trigger.toLowerCase().contains(trigger.toLowerCase())).toList();
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final macro = await getById(id);
    if (macro != null) {
      await update(macro.copyWith(isFavorite: !macro.isFavorite));
    }
  }

  @override
  Future<void> incrementUsage(String id) async {
    final macro = await getById(id);
    if (macro != null) {
      await update(macro.copyWith(
        usageCount: macro.usageCount + 1,
        lastUsed: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> sync() async {
    // Sync handled by CachedMacroRepository in the existing architecture
  }
}
