/// Platform-specific keyboard service
/// Exports the correct implementation based on the platform

// Export Windows implementation on Windows
export 'keyboard_service_windows.dart'
    if (dart.library.html) 'keyboard_service_web.dart';
