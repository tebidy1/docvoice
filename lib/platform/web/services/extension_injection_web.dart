// Web-only implementation using dart:js_interop.
// This file is only compiled when targeting web platforms.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Attempts to inject [text] into the active Chrome tab via the
/// window.scribeflow extension bridge.  Returns true on success.
Future<bool> tryInjectText(String text) async {
  try {
    final scribeflow = globalContext['scribeflow'];
    if (scribeflow != null) {
      final jsObj = scribeflow as JSObject;
      final promise =
          jsObj.callMethod('injectTextToActiveTab'.toJS, text.toJS)
              as JSPromise;
      final result = await promise.toDart;
      return (result as JSBoolean).toDart;
    }
  } catch (e) {
    // ignore injection errors
  }
  return false;
}






