import 'package:flutter/foundation.dart';

class PwaManager {
  ValueNotifier<bool> get isInstallPromptAvailable => ValueNotifier(false);

  void promptInstall() {
    debugPrint("PWA Install prompt not supported on this platform.");
  }
}

PwaManager getPwaManager() => PwaManager();
