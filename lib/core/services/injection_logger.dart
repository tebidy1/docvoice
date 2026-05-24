import 'dart:io';
import 'dart:convert';

class InjectionLogger {
  static final InjectionLogger _instance = InjectionLogger._();
  static InjectionLogger get instance => _instance;
  InjectionLogger._();

  final StringBuffer _buf = StringBuffer();
  String? _currentPath;
  bool _sessionActive = false;
  bool _enabled = false; // Set to true to enable logging

  bool get isEnabled => _enabled;
  void enable() => _enabled = false;
  void disable() => _enabled = false;

  String _logDir() {
    return '${Directory.current.path}\\inject_logs';
  }

  void startSession(String label) {
    if (!_enabled) return;
    _buf.clear();
    _buf.writeln('=== SESSION START: $label ===');
    _buf.writeln('Time: ${DateTime.now()}');

    try {
      final dir = Directory(_logDir());
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final safeLabel = label.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      _currentPath = '${dir.path}\\inject_${timestamp}_$safeLabel.txt';

      _buf.writeln('Log: $_currentPath');
      _buf.writeln('');
      _sessionActive = true;

      // Also print to console
      print('[InjectLogger] Session started: $_currentPath');
    } catch (e) {
      print('[InjectLogger] Failed to create log dir: $e');
      _currentPath = null;
      _sessionActive = true; // still log to buffer even if file fails
    }
  }

  void log(String message) {
    if (!_enabled) return;
    _buf.writeln('[${_timestamp()}] $message');
    _flushDebug();
  }

  void logRaw(String message) {
    if (!_enabled) return;
    _buf.writeln(message);
  }

  void logData(String title, Map<String, String> data) {
    if (!_enabled) return;
    _buf.writeln('');
    _buf.writeln('--- $title ---');
    for (final entry in data.entries) {
      _buf.writeln('  ${entry.key}: ${entry.value}');
    }
    _buf.writeln('');
    _flushDebug();
  }

  void logInjectionResult(String label, bool success, String value,
      {String? method, String? error}) {
    if (!_enabled) return;
    final status = success ? '✓' : '✗';
    _buf.writeln('$status [$label] -> "$value"'
        '${method != null ? ' [method: $method]' : ''}'
        '${error != null ? ' ERROR: $error' : ''}');
    _flushDebug();
  }

  void logSection(String title) {
    if (!_enabled) return;
    _buf.writeln('');
    _buf.writeln('=' * 60);
    _buf.writeln('  $title');
    _buf.writeln('=' * 60);
    _flushDebug();
  }

  void logScannedElements(List<Map<String, String>> elements) {
    if (!_enabled) return;
    _buf.writeln('');
    _buf.writeln(
        '  ${'Name'.padRight(30)} ${'Control'.padRight(20)} ${'AutomationId'.padRight(25)} Value');
    _buf.writeln('  ${'-' * 30} ${'-' * 20} ${'-' * 25} ${'-' * 30}');
    for (final el in elements) {
      _buf.writeln(
          '  ${el['name']!.padRight(30)} ${el['controlType']!.padRight(20)} '
          '${el['automationId']!.padRight(25)} ${el['value']!}');
    }
    _buf.writeln('');
    _flushDebug();
  }

  void endSession() {
    if (!_enabled) return;
    if (!_sessionActive) return;

    _buf.writeln('');
    _buf.writeln('=== SESSION END ===');

    if (_currentPath != null) {
      try {
        File(_currentPath!).writeAsStringSync(_buf.toString(), flush: true);
        print('[InjectLogger] Log saved: $_currentPath');
      } catch (e) {
        print('[InjectLogger] Failed to write log file: $e');
        // If file writing fails, print the full buffer
        print('===== INJECT LOG (file write failed) =====');
        print(_buf.toString());
        print('===========================================');
      }
    } else {
      // No file path, print to console
      print('===== INJECT LOG =====');
      print(_buf.toString());
      print('=======================');
    }

    _buf.clear();
    _sessionActive = false;
  }

  void _flushDebug() {
    // Print last line to debug console for real-time feedback
    final lines = _buf.toString().split('\n');
    if (lines.length > 1) {
      print(lines[
          lines.length - 2]); // second to last (last is empty after writeln)
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _timestamp() {
    final now = DateTime.now();
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  }
}
