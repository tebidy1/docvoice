import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soutnote/core/di/service_locator.dart';
import 'package:soutnote/core/network/api_client.dart';
import 'package:soutnote/core/repositories/i_auth_service.dart';
import 'package:soutnote/core/services/auth_service.dart';
import 'package:soutnote/core/services/theme_service.dart';
import 'package:soutnote/core/usecases/auth_state_usecase.dart';
import 'package:soutnote/core/usecases/get_inbox_notes_usecase.dart';
import 'package:soutnote/core/usecases/get_macros_usecase.dart';
import 'package:soutnote/core/usecases/login_usecase.dart';
import 'package:soutnote/core/usecases/register_usecase.dart';
import 'package:soutnote/core/usecases/upload_audio_usecase.dart';
import 'package:soutnote/core/entities/app_theme.dart';
import '../../platform/android/services/websocket_service.dart' as unified_ws;

final apiClientProvider =
    Provider<ApiClient>((ref) => ServiceLocator.get<ApiClient>());

final authServiceProvider =
    Provider<AuthService>((ref) => ServiceLocator.get<AuthService>());

final iAuthProvider =
    Provider<IAuthService>((ref) => ServiceLocator.get<IAuthService>());

final loginUseCaseProvider =
    Provider<LoginUseCase>((ref) => ServiceLocator.get<LoginUseCase>());

final registerUseCaseProvider =
    Provider<RegisterUseCase>((ref) => ServiceLocator.get<RegisterUseCase>());

final authStateUseCaseProvider =
    Provider<AuthStateUseCase>((ref) => ServiceLocator.get<AuthStateUseCase>());

final getMacrosUseCaseProvider =
    Provider<GetMacrosUseCase>((ref) => ServiceLocator.get<GetMacrosUseCase>());

final getInboxNotesUseCaseProvider = Provider<GetInboxNotesUseCase>(
    (ref) => ServiceLocator.get<GetInboxNotesUseCase>());

final uploadAudioUseCaseProvider = Provider<UploadAudioUseCase>(
    (ref) => ServiceLocator.get<UploadAudioUseCase>());

final webSocketServiceProvider = Provider<unified_ws.WebSocketService>((ref) {
  return unified_ws.WebSocketService();
});

final themeProvider = ChangeNotifierProvider<ThemeService>((ref) {
  return ThemeService();
});

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final authUseCase = ref.read(authStateUseCaseProvider);
  return await authUseCase.isAuthenticated();
});

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authUseCase = ref.read(authStateUseCaseProvider);
  return await authUseCase.getCurrentUser();
});

final isAdminProvider = Provider<bool>((ref) {
  final authUseCase = ref.read(authStateUseCaseProvider);
  return authUseCase.isAdmin();
});
