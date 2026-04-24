import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> requestWebMicrophonePermission() async {
  try {
    // Workaround: explicitly request permission to show prompt before `record` package starts.
    // This prevents an issue where `record` swallows the recording/blob if delayed by the browser prompt.
    final stream = await web.window.navigator.mediaDevices.getUserMedia(
      web.MediaStreamConstraints(audio: true.toJS)
    ).toDart;
    
    final tracks = stream.getTracks().toDart;
    for (final track in tracks) {
      track.stop();
    }
    return true;
  } catch (e) {
    return false;
  }
}






