import 'dart:async';
import '../models/note_model.dart';
import '../../services/api_service.dart';

// Unified InboxService for Mobile (API Based)
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

  Future<int> addNote(
    String rawText, {
    String? patientName,
    String? summary,
    int? suggestedMacroId,
    // Add formatted text support as Mobile processes it locally first
    String? formattedText, 
  }) async {
    try {
      await init();
      final body = {
        'raw_text': rawText,
        if (patientName != null) 'patient_name': patientName,
        if (summary != null) 'summary': summary,
        if (suggestedMacroId != null) 'suggested_macro_id': suggestedMacroId,
        // Mobile sends the processed text directly if available
        if (formattedText != null) 'formatted_text': formattedText,
        if (formattedText != null) 'status': 'processed', // Auto-mark as processed if we send formatted text
      };

      final response = await _apiService.post('/inbox-notes', body: body);

      if (response['status'] != true || response['payload'] == null) {
        throw Exception(response['message'] ?? 'Failed to add note');
      }
      
      final payload = response['payload'];
      return payload['id'] is int ? payload['id'] : int.parse(payload['id'].toString());
      
    } catch (e) {
      print('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(
    int noteId, {
    String? rawText,
    String? formattedText,
    String? patientName,
    String? summary,
    int? suggestedMacroId,
  }) async {
    try {
      await init();
      final body = <String, dynamic>{};
      
      if (rawText != null) body['raw_text'] = rawText;
      if (formattedText != null) body['formatted_text'] = formattedText;
      if (patientName != null) body['patient_name'] = patientName;
      if (summary != null) body['summary'] = summary;
      if (suggestedMacroId != null) body['suggested_macro_id'] = suggestedMacroId;
      
      // Update status to processed if formatted text is provided
      if (formattedText != null && formattedText.isNotEmpty) {
        body['status'] = 'processed';
      }

      final response = await _apiService.put('/inbox-notes/$noteId', body: body);

      if (response['status'] != true) {
        throw Exception(response['message'] ?? 'Failed to update note');
      }
    } catch (e) {
      print('Error updating note: $e');
      rethrow;
    }
  }

  Future<List<NoteModel>> getPendingNotes() async {
    await init();
    try {
      final response = await _apiService.get('/inbox-notes/pending');

      if (response['status'] == true && response['payload'] != null) {
        final List<dynamic> data = response['payload'] is List
            ? response['payload']
            : [];
        
        return data.map((json) => _mapToNoteModel(json)).toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<NoteModel?> getNoteById(int id) async {
    await init();
    try {
      final response = await _apiService.get('/inbox-notes/$id');
      if (response['status'] == true && response['payload'] != null) {
         return _mapToNoteModel(response['payload']);
      }
      return null;
    } catch (e) {
      print('Error fetching note $id: $e');
      return null;
    }
  }

  // Polling Stream for Real-time updates (until WebSocket is fully integrated for data sync)
  Stream<List<NoteModel>> watchPendingNotes() async* {
    int consecutiveErrors = 0;
    
    while (true) {
      try {
        final notes = await getPendingNotes();
        yield notes;
        consecutiveErrors = 0;
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        consecutiveErrors++;
         // Exponential backoff
        await Future.delayed(Duration(seconds: 5 * consecutiveErrors));
        if (consecutiveErrors > 5) yield []; // Return empty on verified failure
      }
    }
  }

  NoteModel _mapToNoteModel(Map<String, dynamic> json) {
    // Map API response to Mobile's NoteModel
    final note = NoteModel();
    note.id = json['id'] is int ? json['id'] : int.parse(json['id'].toString());
    note.title = json['patient_name'] ?? 'Untitled'; // Map patient_name to title
    note.originalText = json['raw_text'] ?? '';
    note.formattedText = json['formatted_text'] ?? ''; // Ensure API returns this
    note.status = _mapStatus(json['status'] ?? 'pending');
    note.createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    note.uuid = json['uuid'] ?? json['id'].toString(); // Fallback to ID if UUID missing
    note.content = note.formattedText.isNotEmpty ? note.formattedText : note.originalText; // Populate content
    note.updatedAt = json['updated_at'] != null 
        ? DateTime.parse(json['updated_at']) 
        : note.createdAt;
    return note;
  }

  NoteStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return NoteStatus.draft; // Map 'pending' to 'draft'
      case 'processed':
        return NoteStatus.processed;
      case 'archived':
        return NoteStatus.archived;
      default:
        return NoteStatus.draft;
    }
  }
}
