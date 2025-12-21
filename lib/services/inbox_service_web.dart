import '../models/inbox_note_web.dart';
import 'dart:async';

/// Web-compatible stub for InboxService
/// On web, local database features are not supported
class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print("InboxService (Web): Already initialized (stub)");
      return;
    }
    
    print("InboxService (Web): Initializing stub (no actual functionality)...");
    _isInitialized = true;
    print("InboxService (Web): ✅ Stub initialized");
  }

  Future<void> addNote(String rawText, {String? patientName, String? summary, int? suggestedMacroId}) async {
    await init();
    print("InboxService (Web): addNote stub called - not supported on web");
  }

  Future<List<InboxNote>> getPendingNotes() async {
    await init();
    print("InboxService (Web): getPendingNotes stub called - returning empty list");
    return [];
  }

  Future<void> updateStatus(int id, InboxStatus status) async {
    await init();
    print("InboxService (Web): updateStatus stub called - not supported on web");
  }

  Future<void> archiveNote(int id) async {
    await updateStatus(id, InboxStatus.archived);
  }

  Future<void> deleteNote(int id) async {
    await init();
    print("InboxService (Web): deleteNote stub called - not supported on web");
  }

  Stream<List<InboxNote>> watchPendingNotes() async* {
    print("InboxService (Web): watchPendingNotes stub - yielding empty stream");
    await init();
    yield [];
  }

  Stream<List<InboxNote>> watchArchivedNotes() async* {
    print("InboxService (Web): watchArchivedNotes stub - yielding empty stream");
    await init();
    yield [];
  }
}
