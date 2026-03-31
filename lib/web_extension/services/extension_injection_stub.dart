import 'package:flutter/foundation.dart';

/// Stub implementation of text injection for non-web platforms.
/// Always returns false since injection into Chrome tabs is only supported via JS interop in a web environment.
Future<bool> injectTextToWebTab(String text) async {
  debugPrint("Smart Inject is only available on web.");
  return false;
}
