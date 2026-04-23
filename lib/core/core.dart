/// Core module exports
/// This file provides a single import point for all core functionality

// Interfaces
export 'repositories/base_repository.dart';
export 'repositories/abstract_repository.dart';
export 'repositories/base_service.dart';
export 'repositories/dto_mapper.dart';
export 'repositories/cache_strategy.dart';
export 'repositories/macro_repository.dart';
export 'repositories/inbox_note_repository.dart';
export 'repositories/user_repository.dart';
export 'repositories/audio_repository.dart';
export 'repositories/settings_repository.dart';
export 'repositories/audio_service.dart';
export 'repositories/realtime_service.dart';
export 'repositories/settings_service.dart';
export 'repositories/offline_service.dart';
export 'repositories/auth_service.dart';

// Entities
export 'entities/app_theme.dart';

// Network
export 'network/api_client.dart';

// Authentication
export 'auth/token_manager.dart';

// DI
export 'di/service_locator.dart';

// Error Handling
export 'error/app_error.dart';
export 'error/error_handler.dart';
export 'error/api_exceptions.dart';
export 'error/api_error_handler.dart';
export 'error/error_recovery_manager.dart';

// Testing
export 'testing/property_test.dart';
export 'testing/generators.dart';
