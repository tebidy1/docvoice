import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class PwaManager {
  // We use a ValueNotifier so the UI can listen to changes
  final ValueNotifier<bool> isInstallPromptAvailable = ValueNotifier(false);

  web.Event? _deferredPrompt;

  PwaManager() {
    _init();
  }

  void _init() {
    // Listen for the 'beforeinstallprompt' event
    final eventName = 'beforeinstallprompt';
    web.window.addEventListener(
        eventName,
        (web.Event event) {
          // Prevent the mini-infobar from appearing on mobile
          event.preventDefault();

          // Stash the event so it can be triggered later.
          _deferredPrompt = event;

          // Update UI notify user they can install the PWA
          isInstallPromptAvailable.value = true;
          debugPrint("PWA Install prompt captured!");
        }.toJS);
  }

  void promptInstall() {
    if (_deferredPrompt != null) {
      // The event is a BeforeInstallPromptEvent, which has a prompt() method.
      // Since package:web might not have the exact type typed out yet in standard lib for this specific non-standard event,
      // we use JS interop to call prompt().

      // Cast event to JSObject to call prompt()
      final promptEvent = _deferredPrompt as JSObject;
      promptEvent.callMethod('prompt'.toJS);

      // Wait for the user to respond to the prompt
      // We can listen to userChoice if needed, but for now just clearing the prompt is enough
      _deferredPrompt = null;
      isInstallPromptAvailable.value = false;
    } else {
      debugPrint("No PWA install prompt available.");
    }
  }
}

PwaManager getPwaManager() => PwaManager();
