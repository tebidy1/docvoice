/// Platform-specific database service
/// Exports the correct implementation based on the platform

// Export IO implementation on non-web platforms
// Export Web stub on web
export 'database_service_io.dart'
    if (dart.library.html) 'database_service_web.dart';
