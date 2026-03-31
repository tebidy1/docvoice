/// Platform-specific macro model
/// Exports the correct implementation based on the platform

// Export IO implementation with Isar on non-web platforms
// Export simple class on web
export 'macro_io.dart'
    if (dart.library.html) 'macro_web.dart';
