/// Core module exports
/// This file provides a single import point for all core functionality

// Interfaces
export 'interfaces/base_repository.dart';
export 'interfaces/abstract_repository.dart';
export 'interfaces/base_service.dart';
export 'interfaces/dto_mapper.dart';
export 'interfaces/cache_strategy.dart';
export 'interfaces/macro_repository.dart';
export 'interfaces/inbox_note_repository.dart';
export 'interfaces/user_repository.dart';
export 'interfaces/audio_repository.dart';
export 'interfaces/settings_repository.dart';
export 'interfaces/audio_service.dart';
export 'interfaces/realtime_service.dart';
export 'interfaces/settings_service.dart';
export 'interfaces/offline_service.dart';
export 'interfaces/auth_service.dart';

// DTOs
export 'dto/macro_dto.dart';
export 'dto/inbox_note_dto.dart';
export 'dto/user_dto.dart';
export 'dto/user_settings_dto.dart';

// Models
export 'models/audio_models.dart';
export 'models/api_models.dart';

// API Client
export 'api/api_client.dart';

// Authentication
export 'auth/token_manager.dart';

// Repository Implementations
export 'repositories/api_macro_repository.dart';
export 'repositories/local_macro_repository.dart';
export 'repositories/cached_macro_repository.dart';
export 'repositories/api_inbox_note_repository.dart';

// Service Implementations
export 'services/audio_service_impl.dart';

// DTO Mappers
export 'dto/enhanced_dto_mapper.dart';
export 'dto/mapping_utils.dart';
export 'dto/mapping_error_reporter.dart';

// Configuration
export 'config/api_config.dart';

// Dependency Injection
export 'di/service_locator.dart';

// Error Handling
export 'error/app_error.dart';
export 'error/error_handler.dart';
export 'error/api_exceptions.dart';
export 'error/api_error_handler.dart';
export 'error/error_recovery_manager.dart';

// Testing (only export in test environment)
export 'testing/property_test.dart';
export 'testing/generators.dart';