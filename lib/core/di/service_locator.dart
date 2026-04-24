import 'package:get_it/get_it.dart';
import 'package:soutnote/core/repositories/repositories.dart';
import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/core/services/auth_service.dart';
import 'package:soutnote/core/services/audio_service_impl.dart';
import 'package:soutnote/data/repositories/repositories.dart';

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
    _getIt.registerSingleton<ApiClient>(ApiClient());
    _getIt.registerSingleton<AuthService>(AuthService());
    
    // Register repository implementations
    _getIt.registerLazySingleton<ApiMacroRepository>(() => ApiMacroRepository(
      ApiClient: _getIt.get<ApiClient>(),
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
      ApiClient: _getIt.get<ApiClient>(),
    ));
    
    _getIt.registerLazySingleton<InboxNoteRepository>(() => _getIt.get<ApiInboxNoteRepository>());
    
    // Register audio service
    _getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl());
    
    // Initialize core services
    await _getIt.get<ApiClient>().init();
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
