import 'package:get_it/get_it.dart';
import '../interfaces/audio_service.dart';
import '../interfaces/realtime_service.dart';
import '../interfaces/settings_service.dart';
import '../interfaces/offline_service.dart';
import '../interfaces/macro_repository.dart';
import '../interfaces/inbox_note_repository.dart';
import '../interfaces/user_repository.dart';
import '../interfaces/cache_strategy.dart';
import '../repositories/api_macro_repository.dart';
import '../repositories/local_macro_repository.dart';
import '../repositories/cached_macro_repository.dart';
import '../repositories/api_inbox_note_repository.dart';
import '../services/audio_service_impl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

/// Service locator for dependency injection
class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;
  
  /// Get service instance
  static T get<T extends Object>() => _getIt.get<T>();
  
  /// Check if service is registered
  static bool isRegistered<T extends Object>() => _getIt.isRegistered<T>();
  
  /// Initialize all services
  static Future<void> initialize() async {
    // Register existing services
    _getIt.registerSingleton<ApiService>(ApiService());
    _getIt.registerSingleton<AuthService>(AuthService());
    
    // Register repository implementations
    _getIt.registerLazySingleton<ApiMacroRepository>(() => ApiMacroRepository(
      apiService: _getIt.get<ApiService>(),
    ));
    
    _getIt.registerLazySingleton<LocalMacroRepository>(() => LocalMacroRepository(
      cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
    ));
    
    _getIt.registerLazySingleton<MacroRepository>(() => CachedMacroRepository(
      apiRepository: _getIt.get<ApiMacroRepository>(),
      localRepository: _getIt.get<LocalMacroRepository>(),
      cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
    ));
    
    // Register inbox note repository
    _getIt.registerLazySingleton<ApiInboxNoteRepository>(() => ApiInboxNoteRepository(
      apiService: _getIt.get<ApiService>(),
    ));
    
    _getIt.registerLazySingleton<InboxNoteRepository>(() => _getIt.get<ApiInboxNoteRepository>());
    
    // Register audio service
    _getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl());
    
    // Register other repositories (will be implemented in later tasks)
    // _getIt.registerLazySingleton<UserRepository>(() => ApiUserRepository());
    
    // Register services (will be implemented in later tasks)
    // _getIt.registerLazySingleton<RealtimeService>(() => WebSocketRealtimeService());
    // _getIt.registerLazySingleton<SettingsService>(() => SettingsServiceImpl());
    // _getIt.registerLazySingleton<OfflineService>(() => OfflineServiceImpl());
    
    // Initialize core services
    await _getIt.get<ApiService>().init();
    await _getIt.get<AudioService>().initialize();
  }
  
  /// Reset all services (for testing)
  static Future<void> reset() async {
    await _getIt.reset();
  }
  
  /// Register service
  static void registerSingleton<T extends Object>(T instance) {
    _getIt.registerSingleton<T>(instance);
  }
  
  /// Register lazy singleton
  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _getIt.registerLazySingleton<T>(factory);
  }
  
  /// Register factory
  static void registerFactory<T extends Object>(T Function() factory) {
    _getIt.registerFactory<T>(factory);
  }
  
  /// Unregister service
  static Future<void> unregister<T extends Object>() async {
    await _getIt.unregister<T>();
  }
}

/// Extension for easy access to services
extension ServiceLocatorExtension on Object {
  /// Get service from locator
  T getService<T extends Object>() => ServiceLocator.get<T>();
}