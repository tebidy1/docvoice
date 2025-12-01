import 'package:isar/isar.dart';
import '../models/inbox_note.dart';
import 'database_service.dart';
import 'dart:async';

class InboxService {
  static final InboxService _instance = InboxService._internal();
  factory InboxService() => _instance;
  InboxService._internal();
  
  final DatabaseService _dbService = DatabaseService();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      print("InboxService: Already initialized");
      return;
    }
    
    print("InboxService: Starting initialization...");
    await _dbService.init();
    _isInitialized = true;
    print("InboxService: Database ready");
  }

  Future<void> addNote(String rawText, {String? patientName, String? summary, int? suggestedMacroId}) async {
    await init();
    
    final isar = await _dbService.isar;
    final note = InboxNote()
      ..rawText = rawText
      ..patientName = patientName ?? 'Unknown Patient'
      ..summary = summary ?? rawText.substring(0, rawText.length > 50 ? 50 : rawText.length)
      ..status = InboxStatus.pending
      ..createdAt = DateTime.now()
      ..suggestedMacroId = suggestedMacroId;

    await isar.writeTxn(() async {
      await isar.inboxNotes.put(note);
    });
  }

  Future<List<InboxNote>> getPendingNotes() async {
    await init();
    final isar = await _dbService.isar;
    return await isar.inboxNotes
        .filter()
        .statusEqualTo(InboxStatus.pending)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<void> updateStatus(Id id, InboxStatus status) async {
    await init();
    final isar = await _dbService.isar;
    await isar.writeTxn(() async {
      final note = await isar.inboxNotes.get(id);
      if (note != null) {
        note.status = status;
        await isar.inboxNotes.put(note);
      }
    });
  }

  Future<void> archiveNote(Id id) async {
    await updateStatus(id, InboxStatus.archived);
  }

  Future<void> deleteNote(Id id) async {
    await init();
    final isar = await _dbService.isar;
    await isar.writeTxn(() async {
      await isar.inboxNotes.delete(id);
    });
  }

  Stream<List<InboxNote>> watchPendingNotes() async* {
    print("InboxService: Start watching pending notes...");
    try {
      await init();
      print("InboxService: Init complete, yielding stream...");
      final isar = await _dbService.isar;
      yield* isar.inboxNotes
          .filter()
          .statusEqualTo(InboxStatus.pending)
          .sortByCreatedAtDesc()
          .watch(fireImmediately: true);
    } catch (e) {
      print("InboxService: Error watching notes: $e");
      yield [];
    }
  }
  Stream<List<InboxNote>> watchArchivedNotes() async* {
    try {
      await init();
      final isar = await _dbService.isar;
      yield* isar.inboxNotes
          .filter()
          .statusEqualTo(InboxStatus.archived)
          .sortByCreatedAtDesc()
          .watch(fireImmediately: true);
    } catch (e) {
      print("InboxService: Error watching archived notes: $e");
      yield [];
    }
  }
}
