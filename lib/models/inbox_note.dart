/// Platform-specific inbox note model
/// Exports the correct implementation based on the platform

// Export IO implementation with Isar on non-web platforms
// Export simple class on web
export 'inbox_note_io.dart'
    if (dart.library.html) 'inbox_note_web.dart';
