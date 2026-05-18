import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'injection_logger.dart';



class WindowsAutomationInjector {
  static WindowsAutomationInjector? _instance;
  Process? _engineProcess;
  StreamIterator<String>? _responseIterator;
  bool _isInitialized = false;

  factory WindowsAutomationInjector() {
    _instance ??= WindowsAutomationInjector._internal();
    return _instance!;
  }

  bool get isEngineAvailable => _isInitialized;

  WindowsAutomationInjector._internal();

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final exePath = _getEnginePath();
      if (await File(exePath).exists()) {
        _engineProcess = await Process.start(exePath, [],
            mode: ProcessStartMode.normal,
            workingDirectory: File(exePath).parent.path);

        // Create persistent StreamIterator over stdout (single-subscription stream)
        _responseIterator = StreamIterator(
          _engineProcess!.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter()),
        );

        _isInitialized = true;
        debugPrint('[WindowsAutomation] Engine initialized');
        return true;
      }
      debugPrint('[WindowsAutomation] Engine not found, using native mode');
      return false;
    } catch (e) {
      debugPrint('[WindowsAutomation] Failed to initialize: $e');
      return false;
    }
  }

  String _getEnginePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\automation_engine.exe',
      '${Directory.current.path}\\build\\windows\\x64\\debug\\automation_engine.exe',
      '${Directory.current.path}\\build\\windows\\x64\\profile\\automation_engine.exe',
      '${Directory.current.path}\\build\\windows\\x64\\release\\automation_engine.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return candidates.first;
  }

  Future<List<AppInfo>> getRunningApps() async {
    await initialize();

    if (_isInitialized) {
      try {
        final response = await _sendCommand({'action': 'list_apps'});
        if (response['success'] == true && response['data'] != null) {
          final apps = (response['data'] as List)
              .map((a) => AppInfo.fromJson(a as Map<String, dynamic>))
              .toList();
          if (apps.isNotEmpty) return apps;
          debugPrint('[WindowsAutomation] Engine returned empty list, falling back to native');
        }
      } catch (e) {
        debugPrint('[WindowsAutomation] Engine command failed, using native: $e');
      }
    }

    return _getRunningAppsNative();
  }

  Future<List<AppInfo>> _getRunningAppsNative() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r"Get-Process | Where-Object { $_.MainWindowTitle -ne '' } | "
        r"Select-Object @{N='name';E={$_.ProcessName}}, "
        r"@{N='processId';E={$_.Id}}, "
        r"@{N='mainWindowTitle';E={$_.MainWindowTitle}} | "
        r"ConvertTo-Json",
      ]);

      if (result.exitCode != 0) return [];

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return [];

      final decoded = jsonDecode(output);
      final list = decoded is List ? decoded : [decoded];

      return list
          .map((a) => AppInfo.fromJson(a as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[WindowsAutomation] Native listing failed: $e');
      return [];
    }
  }

  Future<List<ScannedElement>> scanApp(String appName) async {
    if (!_isInitialized) {
      InjectionLogger.instance.log('SCAN SKIPPED: Engine not initialized');
      return [];
    }

    final log = InjectionLogger.instance;
    log.logSection('SCANNING TARGET APP: $appName');

    final response = await _sendCommand({
      'action': 'scan',
      'targetApp': appName,
    });

    if (response['success'] == true && response['data'] != null) {
      final elements = (response['data'] as List)
          .map((e) => ScannedElement.fromJson(e as Map<String, dynamic>))
          .toList();

      log.log('Found ${elements.length} elements in $appName:');
      log.log('');
      log.log('  ${'Element Name'.padRight(30)} ${'Control'.padRight(20)} ${'AutomationId'.padRight(25)} Value');
      log.log('  ${'-'*30} ${'-'*20} ${'-'*25} ${'-'*30}');
      for (final el in elements) {
        final name = el.name.length > 28 ? '${el.name.substring(0, 27)}~' : el.name;
        final ctrl = el.controlType.length > 18 ? '${el.controlType.substring(0, 17)}~' : el.controlType;
        final aid = (el.automationId ?? '').length > 23 ? '${el.automationId!.substring(0, 22)}~' : (el.automationId ?? '-');
        final val = (el.value ?? '').length > 28 ? '${el.value!.substring(0, 27)}~' : (el.value ?? '');
        log.log('  ${name.padRight(30)} ${ctrl.padRight(20)} ${aid.padRight(25)} $val');
      }
      log.log('');

      return elements;
    }

    log.log('SCAN returned no data or failed');
    log.log('Response: ${jsonEncode(response)}');
    return [];
  }

  Future<List<ScannedElement>> findFieldsByLabels(
      String appName, List<String> labels) async {
    if (!_isInitialized) return [];

    final log = InjectionLogger.instance;
    log.logSection('FIND FIELDS BY LABELS: $appName');
    log.log('Looking for labels: ${labels.join(", ")}');

    final response = await _sendCommand({
      'action': 'find_fields',
      'targetApp': appName,
      'selector': {
        'label': labels.join(','),
        'targetControl': 'Edit',
        'sameParent': true,
        'direction': 'right',
        'maxDistance': 300,
      },
    });

    if (response['success'] == true && response['data'] != null) {
      final fields = (response['data'] as List)
          .map((f) => ScannedElement.fromJson(f as Map<String, dynamic>))
          .toList();

      log.log('Found ${fields.length} matching fields:');
      for (final f in fields) {
        log.log('  ${f.name} (${f.controlType}) [${f.automationId ?? "no-id"}] = "${f.value ?? ""}"');
      }

      return fields;
    }

    log.log('find_fields returned no results');
    log.log('Response: ${jsonEncode(response)}');
    return [];
  }

  /// Inject a single field with a specific label. Returns raw engine response.
  Future<Map<String, dynamic>> injectField(
      String appName, String label, String value) async {
    if (!_isInitialized) {
      return {'success': false, 'error': 'Engine not initialized'};
    }

    return await _sendCommand({
      'action': 'inject',
      'targetApp': appName,
      'label': label,
      'value': value,
    });
  }

  Future<List<InjectionResult>> inject(
      String appName, Map<String, String> data) async {
    if (!_isInitialized) {
      InjectionLogger.instance.log('INJECT SKIPPED: Engine not initialized');
      return [];
    }

    final log = InjectionLogger.instance;
    log.logSection('INJECTION TO: $appName');
    log.logData('Input fields', data);

    final results = <InjectionResult>[];
    for (final entry in data.entries) {
      final label = entry.key.replaceAll('_', ' ').trim();
      log.log('Sending: label="$label", value="${entry.value}"');

      final response = await _sendCommand({
        'action': 'inject',
        'targetApp': appName,
        'label': label,
        'value': entry.value,
      });

      final success = response['success'] == true;
      final error = response['error'] as String?;

      log.logInjectionResult(label, success, entry.value,
          method: response['method'] as String?, error: error);

      results.add(InjectionResult(
        label: entry.key,
        success: success,
        value: entry.value,
        method: response['method'] ?? (success ? 'UIAutomation' : 'failed'),
        error: error,
      ));
    }

    log.logSection('INJECTION SUMMARY');
    final successCount = results.where((r) => r.success).length;
    log.log('$successCount/${results.length} fields succeeded');

    return results;
  }

  Future<List<FieldPreview>> previewInjection(
      String appName, String content) async {
    if (!_isInitialized) return [];

    final response = await _sendCommand({
      'action': 'preview',
      'targetApp': appName,
      'value': content,
    });

    if (response['success'] == true && response['details'] != null) {
      final previews = (response['details'] as List)
          .map((p) => FieldPreview.fromJson(p as Map<String, dynamic>))
          .toList();
      return previews;
    }

    return [];
  }

  Future<Map<String, dynamic>> _sendCommand(Map<String, dynamic> command) async {
    try {
      final jsonStr = jsonEncode(command);
      _engineProcess!.stdin.writeln(jsonStr);

      if (_responseIterator == null) {
        return {'success': false, 'error': 'Engine not initialized'};
      }

      final hasNext = await _responseIterator!.moveNext();
      if (!hasNext) {
        return {'success': false, 'error': 'Engine closed stdout'};
      }

      return jsonDecode(_responseIterator!.current) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[WindowsAutomation] Command failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _engineProcess?.kill();
    _engineProcess = null;
    _isInitialized = false;
  }
}

class AppInfo {
  final String name;
  final int processId;
  final String? mainWindowTitle;
  final String? className;

  AppInfo({
    required this.name,
    required this.processId,
    this.mainWindowTitle,
    this.className,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      name: json['name'] ?? '',
      processId: json['processId'] ?? 0,
      mainWindowTitle: json['mainWindowTitle'],
      className: json['className'],
    );
  }
}

class ScannedElement {
  final String name;
  final String? automationId;
  final String controlType;
  final String? className;
  final BoundingRect? boundingRectangle;
  final String? value;
  final String? label;
  final String? xpath;

  ScannedElement({
    required this.name,
    this.automationId,
    required this.controlType,
    this.className,
    this.boundingRectangle,
    this.value,
    this.label,
    this.xpath,
  });

  factory ScannedElement.fromJson(Map<String, dynamic> json) {
    return ScannedElement(
      name: json['name'] ?? '',
      automationId: json['automationId'],
      controlType: json['controlType'] ?? '',
      className: json['className'],
      boundingRectangle: json['boundingRectangle'] != null
          ? BoundingRect.fromJson(json['boundingRectangle'])
          : null,
      value: json['value'],
      label: json['label'],
      xpath: json['xpath'],
    );
  }
}

class BoundingRect {
  final double x;
  final double y;
  final double width;
  final double height;

  BoundingRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory BoundingRect.fromJson(Map<String, dynamic> json) {
    return BoundingRect(
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
    );
  }
}

class InjectionResult {
  final String label;
  final bool success;
  final String value;
  final String method;
  final String? error;

  InjectionResult({
    required this.label,
    required this.success,
    required this.value,
    required this.method,
    this.error,
  });

  factory InjectionResult.fromJson(Map<String, dynamic> json) {
    return InjectionResult(
      label: json['label'] ?? '',
      success: json['success'] ?? false,
      value: json['value'] ?? '',
      method: json['method'] ?? '',
      error: json['error'],
    );
  }
}

class FieldPreview {
  final String label;
  final bool success;
  final String? elementName;
  final String? automationId;
  final String? controlType;
  final String? error;

  FieldPreview({
    required this.label,
    required this.success,
    this.elementName,
    this.automationId,
    this.controlType,
    this.error,
  });

  factory FieldPreview.fromJson(Map<String, dynamic> json) {
    return FieldPreview(
      label: json['label'] ?? '',
      success: json['success'] ?? false,
      elementName: json['elementName'],
      automationId: json['automationId'],
      controlType: json['controlType'],
      error: json['error'],
    );
  }
}