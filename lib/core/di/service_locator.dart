import 'package:get_it/get_it.dart';
import 'package:soutnote/core/repositories/i_auth_service.dart';
import 'package:soutnote/core/repositories/audio_transcription_repository.dart';
import 'package:soutnote/core/repositories/macro_repository.dart';
import 'package:soutnote/core/repositories/inbox_note_repository.dart';
import 'package:soutnote/core/services/audio_service_interface.dart';
import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/data/services/auth_service.dart';
import 'package:soutnote/data/services/audio_service_impl.dart';
import 'package:soutnote/data/cache_strategy.dart';
import 'package:soutnote/core/usecases/usecases.dart';
import 'package:soutnote/data/repositories/api_macro_repository.dart';
import 'package:soutnote/data/repositories/local_macro_repository.dart';
import 'package:soutnote/data/repositories/cached_macro_repository.dart';
import 'package:soutnote/data/repositories/api_inbox_note_repository.dart';
import 'package:soutnote/data/repositories/api_audio_transcription_repository.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;

  static T get<T extends Object>() => _getIt.get<T>();

  static bool isRegistered<T extends Object>() => _getIt.isRegistered<T>();

  static Future<void> initialize() async {
    _getIt.registerSingleton<ApiClient>(ApiClient());
    _getIt.registerSingleton<AuthService>(AuthService());
    _getIt.registerSingleton<IAuthService>(_getIt.get<AuthService>());

    _getIt.registerLazySingleton<ApiMacroRepository>(() => ApiMacroRepository(
          ApiClient: _getIt.get<ApiClient>(),
        ));

    _getIt
        .registerLazySingleton<LocalMacroRepository>(() => LocalMacroRepository(
              cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
            ));

    _getIt.registerLazySingleton<MacroRepository>(() => CachedMacroRepository(
          apiRepository: _getIt.get<ApiMacroRepository>(),
          localRepository: _getIt.get<LocalMacroRepository>(),
          cacheStrategy: RepositoryCacheStrategies.macroStrategy(),
        ));

    _getIt.registerLazySingleton<ApiInboxNoteRepository>(
        () => ApiInboxNoteRepository(
              ApiClient: _getIt.get<ApiClient>(),
            ));

    _getIt.registerLazySingleton<InboxNoteRepository>(
        () => _getIt.get<ApiInboxNoteRepository>());

    _getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl());

    _getIt.registerLazySingleton<AudioTranscriptionRepository>(
        () => ApiAudioTranscriptionRepository(
              apiClient: _getIt.get<ApiClient>(),
            ));

    _getIt.registerLazySingleton<LoginUseCase>(
        () => LoginUseCase(_getIt.get<IAuthService>()));
    _getIt.registerLazySingleton<RegisterUseCase>(
        () => RegisterUseCase(_getIt.get<IAuthService>()));
    _getIt.registerLazySingleton<AuthStateUseCase>(
        () => AuthStateUseCase(_getIt.get<IAuthService>()));
    _getIt.registerLazySingleton<GetMacrosUseCase>(
        () => GetMacrosUseCase(_getIt.get<MacroRepository>()));
    _getIt.registerLazySingleton<GetInboxNotesUseCase>(
        () => GetInboxNotesUseCase(_getIt.get<InboxNoteRepository>()));
    _getIt.registerLazySingleton<UploadAudioUseCase>(
        () => UploadAudioUseCase(_getIt.get<AudioTranscriptionRepository>()));

    await _getIt.get<ApiClient>().init();
    await _getIt.get<AudioService>().initialize();
    await _getIt.get<IAuthService>().initialize();
  }

  static Future<void> reset() async {
    await _getIt.reset();
  }

  static void registerSingleton<T extends Object>(T instance) {
    _getIt.registerSingleton<T>(instance);
  }

  static void registerLazySingleton<T extends Object>(T Function() factory) {
    _getIt.registerLazySingleton<T>(factory);
  }

  static void registerFactory<T extends Object>(T Function() factory) {
    _getIt.registerFactory<T>(factory);
  }

  static Future<void> unregister<T extends Object>() async {
    await _getIt.unregister<T>();
  }
}

extension ServiceLocatorExtension on Object {
  T getService<T extends Object>() => ServiceLocator.get<T>();
}
