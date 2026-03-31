import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soutnote/core/services/api_service.dart';
import 'package:soutnote/core/services/auth_service.dart';
import 'package:soutnote/core/services/websocket_service.dart';
import '../interfaces/audio_service.dart';
import '../interfaces/macro_repository.dart';
import '../interfaces/inbox_note_repository.dart';
import '../repositories/api_macro_repository.dart';
import '../repositories/local_macro_repository.dart';
import '../repositories/cached_macro_repository.dart';
import '../repositories/api_inbox_note_repository.dart';
import 'package:soutnote/core/services/audio_service_impl.dart';
import '../interfaces/cache_strategy.dart';

/// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for WebSocketService
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// Provider for AudioService
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioServiceImpl();
});

/// Provider for ApiMacroRepository
final apiMacroRepositoryProvider = Provider<ApiMacroRepository>((ref) {
  return ApiMacroRepository(
    apiService: ref.watch(apiServiceProvider),
  );
});

/// Provider for LocalMacroRepository
final localMacroRepositoryProvider = Provider<LocalMacroRepository>((ref) {
  return LocalMacroRepository(
    cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
  );
});

/// Provider for MacroRepository (Cached implementation)
final macroRepositoryProvider = Provider<MacroRepository>((ref) {
  return CachedMacroRepository(
    apiRepository: ref.watch(apiMacroRepositoryProvider),
    localRepository: ref.watch(localMacroRepositoryProvider),
    cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
  );
});

/// Provider for ApiInboxNoteRepository
final apiInboxNoteRepositoryProvider = Provider<ApiInboxNoteRepository>((ref) {
  return ApiInboxNoteRepository(
    apiService: ref.watch(apiServiceProvider),
  );
});

/// Provider for InboxNoteRepository
final inboxNoteRepositoryProvider = Provider<InboxNoteRepository>((ref) {
  // Using API repository directly for now
  return ref.watch(apiInboxNoteRepositoryProvider);
});

/// Provider to initialize all repositories
final initializeRepositoriesProvider = FutureProvider<void>((ref) async {
  await ref.read(macroRepositoryProvider).initialize();
  await ref.read(inboxNoteRepositoryProvider).initialize();
});
