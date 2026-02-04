import 'dart:developer' as developer;
import '../error/app_error.dart';
import 'mapping_utils.dart';

/// Comprehensive error reporting system for DTO mapping failures
class MappingErrorReporter {
  static final MappingErrorReporter _instance = MappingErrorReporter._internal();
  factory MappingErrorReporter() => _instance;
  MappingErrorReporter._internal();
  
  final List<MappingErrorReport> _errorHistory = [];
  final int _maxHistorySize = 100;
  
  /// Report a mapping error with detailed context
  void reportError(MappingErrorReport report) {
    _errorHistory.add(report);
    
    // Keep history size manageable
    if (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeAt(0);
    }
    
    // Log the error
    _logError(report);
  }
  
  /// Create error report from exception
  MappingErrorReport createReport(
    dynamic error,
    String operation,
    String mapperType,
    dynamic originalData, {
    String? fieldName,
    Map<String, dynamic>? additionalContext,
  }) {
    return MappingErrorReport(
      error: error,
      operation: operation,
      mapperType: mapperType,
      originalData: originalData,
      fieldName: fieldName,
      timestamp: DateTime.now(),
      additionalContext: additionalContext ?? {},
    );
  }
  
  /// Get error statistics
  MappingErrorStatistics getStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastHour = now.subtract(const Duration(hours: 1));
    
    final recent24h = _errorHistory.where((e) => e.timestamp.isAfter(last24Hours)).toList();
    final recent1h = _errorHistory.where((e) => e.timestamp.isAfter(lastHour)).toList();
    
    final errorsByType = <String, int>{};
    final errorsByMapper = <String, int>{};
    final errorsByField = <String, int>{};
    
    for (final error in recent24h) {
      final errorType = error.error.runtimeType.toString();
      errorsByType[errorType] = (errorsByType[errorType] ?? 0) + 1;
      
      errorsByMapper[error.mapperType] = (errorsByMapper[error.mapperType] ?? 0) + 1;
      
      if (error.fieldName != null) {
        errorsByField[error.fieldName!] = (errorsByField[error.fieldName!] ?? 0) + 1;
      }
    }
    
    return MappingErrorStatistics(
      totalErrors: _errorHistory.length,
      errorsLast24Hours: recent24h.length,
      errorsLastHour: recent1h.length,
      errorsByType: errorsByType,
      errorsByMapper: errorsByMapper,
      errorsByField: errorsByField,
      mostRecentError: _errorHistory.isNotEmpty ? _errorHistory.last : null,
    );
  }
  
  /// Get detailed error report for debugging
  Map<String, dynamic> getDetailedReport(MappingErrorReport report) {
    final context = <String, dynamic>{
      'error_id': report.hashCode.toString(),
      'timestamp': report.timestamp.toIso8601String(),
      'operation': report.operation,
      'mapper_type': report.mapperType,
      'error_type': report.error.runtimeType.toString(),
      'error_message': report.error.toString(),
      'field_name': report.fieldName,
      'additional_context': report.additionalContext,
    };
    
    // Add original data analysis
    if (report.originalData != null) {
      context['original_data_analysis'] = _analyzeOriginalData(report.originalData);
    }
    
    // Add error-specific analysis
    if (report.error is MappingException) {
      final mappingError = report.error as MappingException;
      context['mapping_error_details'] = {
        'field_name': mappingError.fieldName,
        'original_value': mappingError.originalValue,
        'cause': mappingError.cause?.toString(),
      };
    }
    
    return context;
  }
  
  /// Clear error history
  void clearHistory() {
    _errorHistory.clear();
  }
  
  /// Get recent errors for a specific mapper
  List<MappingErrorReport> getErrorsForMapper(String mapperType, {int limit = 10}) {
    return _errorHistory
        .where((e) => e.mapperType == mapperType)
        .take(limit)
        .toList()
        .reversed
        .toList();
  }
  
  /// Get recent errors for a specific field
  List<MappingErrorReport> getErrorsForField(String fieldName, {int limit = 10}) {
    return _errorHistory
        .where((e) => e.fieldName == fieldName)
        .take(limit)
        .toList()
        .reversed
        .toList();
  }
  
  /// Check if there are recurring errors
  List<RecurringErrorPattern> findRecurringPatterns() {
    final patterns = <String, List<MappingErrorReport>>{};
    
    for (final error in _errorHistory) {
      final key = '${error.mapperType}:${error.fieldName}:${error.error.runtimeType}';
      patterns[key] = (patterns[key] ?? [])..add(error);
    }
    
    return patterns.entries
        .where((entry) => entry.value.length >= 3) // At least 3 occurrences
        .map((entry) => RecurringErrorPattern(
              pattern: entry.key,
              occurrences: entry.value.length,
              firstOccurrence: entry.value.first.timestamp,
              lastOccurrence: entry.value.last.timestamp,
              errors: entry.value,
            ))
        .toList();
  }
  
  /// Analyze original data structure
  Map<String, dynamic> _analyzeOriginalData(dynamic data) {
    if (data == null) {
      return {'type': 'null', 'analysis': 'Data is null'};
    }
    
    if (data is Map<String, dynamic>) {
      final flattened = MappingUtils.flatten(data);
      return {
        'type': 'Map<String, dynamic>',
        'key_count': data.keys.length,
        'keys': data.keys.toList(),
        'flattened_keys': flattened.keys.toList(),
        'nested_levels': _calculateNestingDepth(data),
        'has_null_values': flattened.values.any((v) => v == null),
        'data_types': _analyzeDataTypes(flattened),
      };
    }
    
    if (data is List) {
      return {
        'type': 'List',
        'length': data.length,
        'item_types': data.map((item) => item.runtimeType.toString()).toSet().toList(),
        'has_null_items': data.any((item) => item == null),
      };
    }
    
    return {
      'type': data.runtimeType.toString(),
      'value': data.toString(),
      'length': data.toString().length,
    };
  }
  
  /// Calculate nesting depth of a map
  int _calculateNestingDepth(Map<String, dynamic> data, [int currentDepth = 0]) {
    int maxDepth = currentDepth;
    
    for (final value in data.values) {
      if (value is Map<String, dynamic>) {
        final depth = _calculateNestingDepth(value, currentDepth + 1);
        if (depth > maxDepth) {
          maxDepth = depth;
        }
      }
    }
    
    return maxDepth;
  }
  
  /// Analyze data types in flattened structure
  Map<String, int> _analyzeDataTypes(Map<String, dynamic> flattened) {
    final typeCounts = <String, int>{};
    
    for (final value in flattened.values) {
      final type = value?.runtimeType.toString() ?? 'null';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    
    return typeCounts;
  }
  
  /// Log error with appropriate level
  void _logError(MappingErrorReport report) {
    final level = _getLogLevel(report.error);
    final message = 'Mapping Error in ${report.mapperType}: ${report.error}';
    
    developer.log(
      message,
      name: 'MappingErrorReporter',
      error: report.error,
      level: level,
      time: report.timestamp,
    );
  }
  
  /// Get appropriate log level for error type
  int _getLogLevel(dynamic error) {
    if (error is ValidationError) return 900; // Warning
    if (error is MappingException) return 1000; // Severe
    if (error is NetworkError) return 800; // Info
    return 1000; // Severe for unknown errors
  }
}

/// Detailed error report for mapping failures
class MappingErrorReport {
  final dynamic error;
  final String operation;
  final String mapperType;
  final dynamic originalData;
  final String? fieldName;
  final DateTime timestamp;
  final Map<String, dynamic> additionalContext;
  
  const MappingErrorReport({
    required this.error,
    required this.operation,
    required this.mapperType,
    required this.originalData,
    this.fieldName,
    required this.timestamp,
    required this.additionalContext,
  });
  
  @override
  String toString() {
    return 'MappingErrorReport(${error.runtimeType}: $error, mapper: $mapperType, field: $fieldName)';
  }
}

/// Statistics about mapping errors
class MappingErrorStatistics {
  final int totalErrors;
  final int errorsLast24Hours;
  final int errorsLastHour;
  final Map<String, int> errorsByType;
  final Map<String, int> errorsByMapper;
  final Map<String, int> errorsByField;
  final MappingErrorReport? mostRecentError;
  
  const MappingErrorStatistics({
    required this.totalErrors,
    required this.errorsLast24Hours,
    required this.errorsLastHour,
    required this.errorsByType,
    required this.errorsByMapper,
    required this.errorsByField,
    this.mostRecentError,
  });
  
  /// Get error rate per hour over last 24 hours
  double get errorRatePerHour => errorsLast24Hours / 24.0;
  
  /// Get most problematic mapper
  String? get mostProblematicMapper {
    if (errorsByMapper.isEmpty) return null;
    return errorsByMapper.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  /// Get most problematic field
  String? get mostProblematicField {
    if (errorsByField.isEmpty) return null;
    return errorsByField.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
  
  /// Check if error rate is concerning
  bool get isErrorRateConcerning => errorRatePerHour > 10.0;
}

/// Pattern of recurring errors
class RecurringErrorPattern {
  final String pattern;
  final int occurrences;
  final DateTime firstOccurrence;
  final DateTime lastOccurrence;
  final List<MappingErrorReport> errors;
  
  const RecurringErrorPattern({
    required this.pattern,
    required this.occurrences,
    required this.firstOccurrence,
    required this.lastOccurrence,
    required this.errors,
  });
  
  /// Get frequency of this pattern (occurrences per hour)
  double get frequency {
    final duration = lastOccurrence.difference(firstOccurrence);
    if (duration.inHours == 0) return occurrences.toDouble();
    return occurrences / duration.inHours;
  }
  
  /// Check if this pattern is critical (high frequency)
  bool get isCritical => frequency > 5.0 || occurrences > 10;
  
  @override
  String toString() {
    return 'RecurringErrorPattern($pattern: $occurrences occurrences, frequency: ${frequency.toStringAsFixed(2)}/hour)';
  }
}