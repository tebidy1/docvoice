// Conditional export based on platform
export 'database_service_web.dart' if (dart.library.io) 'database_service_mobile.dart';
