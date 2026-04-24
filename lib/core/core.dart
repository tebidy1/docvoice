/// Core module exports
/// This file provides a single import point for all core functionality

// Repositories (Interfaces)
export 'repositories/repositories.dart';

// Entities
export 'entities/inbox_note.dart';
export 'entities/macro.dart';
export 'entities/user.dart';
export 'entities/company.dart';
export 'entities/app_theme.dart';
export 'entities/smart_suggestion.dart';

// Network (API Client)
export 'network/api_client.dart';

// Services
export 'services/auth_service.dart';
export 'services/audio_service_impl.dart';

// Authentication
export 'auth/token_manager.dart';

// Models (Shared/Base models)
export 'models/audio_models.dart';
export 'models/api_models.dart';

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
