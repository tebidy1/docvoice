import 'dart:async';
import '../models/inbox_note.dart';
import 'api_service.dart';

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();

  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }
    await _apiService.init();
    _isInitialized = true;
  }

  Future<void> addNote(
    String rawText, {
    String? patientName,
    String? summary,
    int? suggestedMacroId,
  }) async {
    try {
      await init();
      final response = await _apiService.post('/inbox-notes', body: {
        'raw_text': rawText,
        if (patientName != null) 'patient_name': patientName,
        if (summary != null) 'summary': summary,
        if (suggestedMacroId != null) 'suggested_macro_id': suggestedMacroId,
      });

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to add note');
      }
    } catch (e) {
      // Log error but don't print if it's a timeout/network error (already handled by ApiService)
      if (!e.toString().contains('timeout') && !e.toString().contains('connection')) {
        print('Error adding note: $e');
      }
      rethrow;
    }
  }

  Future<List<InboxNote>> getPendingNotes() async {
    await init();
    try {
      final response = await _apiService.get('/inbox-notes/pending');

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => _mapToInboxNote(json)).toList();
      }

      return [];
    } catch (e) {
      // Don't print here - let watchPendingNotes handle error logging
      rethrow;
    }
  }

  Future<List<InboxNote>> getArchivedNotes() async {
    try {
      final response = await _apiService.get('/inbox-notes/archived');

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => _mapToInboxNote(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting archived notes: $e');
      return [];
    }
  }

  Future<void> updateStatus(int id, InboxStatus status) async {
    await init();
    try {
      final response = await _apiService.patch(
        '/inbox-notes/$id/status',
        body: {'status': status.name},
      );

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      print('Error updating status: $e');
      rethrow;
    }
  }

  Future<void> archiveNote(int id) async {
    try {
      final response = await _apiService.patch('/inbox-notes/$id/archive');

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to archive note');
      }
    } catch (e) {
      print('Error archiving note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(int id) async {
    await init();
    try {
      final response = await _apiService.delete('/inbox-notes/$id');

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to delete note');
      }
    } catch (e) {
      print('Error deleting note: $e');
      rethrow;
    }
  }

  Stream<List<InboxNote>> watchPendingNotes() async* {
    // Polling implementation - can be replaced with WebSocket later
    int consecutiveErrors = 0;
    String? lastError;
    const int maxConsecutiveErrors = 3;
    const Duration baseDelay = Duration(seconds: 5);
    const Duration maxDelay = Duration(seconds: 30);
    
    while (true) {
      try {
        final notes = await getPendingNotes();
        yield notes;
        // Reset error count on success
        consecutiveErrors = 0;
        lastError = null;
        await Future.delayed(baseDelay);
      } catch (e) {
        consecutiveErrors++;
        final errorMessage = e.toString();
        
        // Only print error if it's different from the last one or first time
        if (errorMessage != lastError || consecutiveErrors == 1) {
          // Suppress repeated error messages after maxConsecutiveErrors
          if (consecutiveErrors <= maxConsecutiveErrors) {
            print('Error watching pending notes: $e');
          }
          lastError = errorMessage;
        }
        
        yield [];
        
        // Exponential backoff: increase delay with each consecutive error
        final delaySeconds = (baseDelay.inSeconds * (1 << (consecutiveErrors - 1).clamp(0, 3))).clamp(
          baseDelay.inSeconds,
          maxDelay.inSeconds,
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  Stream<List<InboxNote>> watchArchivedNotes() async* {
    // Polling implementation - can be replaced with WebSocket later
    int consecutiveErrors = 0;
    String? lastError;
    const int maxConsecutiveErrors = 3;
    const Duration baseDelay = Duration(seconds: 5);
    const Duration maxDelay = Duration(seconds: 30);
    
    while (true) {
      try {
        final notes = await getArchivedNotes();
        yield notes;
        // Reset error count on success
        consecutiveErrors = 0;
        lastError = null;
        await Future.delayed(baseDelay);
      } catch (e) {
        consecutiveErrors++;
        final errorMessage = e.toString();
        
        // Only print error if it's different from the last one or first time
        if (errorMessage != lastError || consecutiveErrors == 1) {
          // Suppress repeated error messages after maxConsecutiveErrors
          if (consecutiveErrors <= maxConsecutiveErrors) {
            print('Error watching archived notes: $e');
          }
          lastError = errorMessage;
        }
        
        yield [];
        
        // Exponential backoff: increase delay with each consecutive error
        final delaySeconds = (baseDelay.inSeconds * (1 << (consecutiveErrors - 1).clamp(0, 3))).clamp(
          baseDelay.inSeconds,
          maxDelay.inSeconds,
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  InboxNote _mapToInboxNote(Map<String, dynamic> json) {
    // Map API response to InboxNote model
    // Note: This is a simplified mapping. You may need to adjust based on your actual API response structure
    // Since we're using the web model (not Isar), we create a simple class instance
    final note = InboxNote();
    note.id = json['id'] ?? 0;
    note.rawText = json['raw_text'] ?? '';
    note.patientName = json['patient_name'];
    note.summary = json['summary'];
    note.status = _mapStatus(json['status'] ?? 'pending');
    note.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    note.suggestedMacroId = json['suggested_macro_id'];
    return note;
  }

  InboxStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return InboxStatus.pending;
      case 'processed':
        return InboxStatus.processed;
      case 'archived':
        return InboxStatus.archived;
      default:
        return InboxStatus.pending;
    }
  }
}
