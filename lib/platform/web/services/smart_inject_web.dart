import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

Future<bool> performSmartInject(String cleanText) async {
  try {
    final scribeflow = globalContext['scribeflow'];
    if (scribeflow != null) {
      final jsObj = scribeflow as JSObject;
      final promise = jsObj.callMethod('injectTextToActiveTab'.toJS, cleanText.toJS) as JSPromise;
      final result = await promise.toDart;
      return (result as JSBoolean).toDart;
    } else {
      debugPrint("Injection failed: window.scribeflow is null. Ensure extension_interop.js is loaded.");
    }
  } catch (e) {
    debugPrint("Injection failed: $e");
  }
  return false;
}






