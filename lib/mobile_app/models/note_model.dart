// Conditional export: use web version on web, mobile version otherwise
export 'note_model_web.dart' if (dart.library.io) 'note_model_mobile.dart';
