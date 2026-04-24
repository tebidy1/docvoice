import '../../domain/entities/inbox_note_entity.dart';
import '../../domain/repositories/inbox_feature_repository.dart';
import '../datasources/inbox_remote_datasource.dart';
import '../models/inbox_note_dto.dart';

class InboxFeatureRepositoryImpl implements InboxFeatureRepository {
  final InboxRemoteDataSource _remoteDataSource;

  InboxFeatureRepositoryImpl({required InboxRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<InboxNoteEntity>> getAll() async {
    final rawData = await _remoteDataSource.getAll();
    return rawData.map((json) => InboxNoteDto.fromJson(json).toEntity()).toList();
  }

  @override
  Future<InboxNoteEntity?> getById(String id) async {
    final raw = await _remoteDataSource.getById(id);
    final data = raw['data'] ?? raw['payload'] ?? raw;
    if (data is Map<String, dynamic>) {
      return InboxNoteDto.fromJson(data).toEntity();
    }
    return null;
  }

  @override
  Future<InboxNoteEntity> create(InboxNoteEntity entity) async {
    final dto = InboxNoteDto.fromEntity(entity);
    final response = await _remoteDataSource.create(dto.toJson());
    final data = response['data'] ?? response['payload'] ?? response;
    return InboxNoteDto.fromJson(data is Map<String, dynamic> ? data : dto.toJson()).toEntity();
  }

  @override
  Future<InboxNoteEntity> update(InboxNoteEntity entity) async {
    final dto = InboxNoteDto.fromEntity(entity);
    final response = await _remoteDataSource.update(entity.id.toString(), dto.toJson());
    final data = response['data'] ?? response['payload'] ?? response;
    return InboxNoteDto.fromJson(data is Map<String, dynamic> ? data : dto.toJson()).toEntity();
  }

  @override
  Future<void> delete(String id) async {
    await _remoteDataSource.delete(id);
  }

  @override
  Future<List<InboxNoteEntity>> getByStatus(InboxNoteStatus status) async {
    final all = await getAll();
    return all.where((n) => n.status == status).toList();
  }

  @override
  Future<List<InboxNoteEntity>> getRecent({int limit = 20}) async {
    final all = await getAll();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  @override
  Future<void> updateStatus(String id, InboxNoteStatus status) async {
    final note = await getById(id);
    if (note != null) {
      await update(note.copyWith(status: status));
    }
  }

  @override
  Future<void> archive(String id) async {
    await updateStatus(id, InboxNoteStatus.archived);
  }

  @override
  Future<List<InboxNoteEntity>> searchByContent(String query) async {
    final all = await getAll();
    final q = query.toLowerCase();
    return all.where((n) => n.content.toLowerCase().contains(q) || n.title.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> sync() async {}
}
