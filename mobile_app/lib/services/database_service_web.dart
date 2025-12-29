import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

// Web Implementation: In-memory storage
class DatabaseService {
  final List<NoteModel> _notes = [];
  final StreamController<List<NoteModel>> _notesController = 
      StreamController<List<NoteModel>>.broadcast();

  int _nextId = 1;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint("DatabaseService: Web mode - using in-memory storage");
    }
    // No initialization needed for Web
  }

  Future<void> saveNote(NoteModel note) async {
    if (note.id == 0) {
      note.id = _nextId++;
    }
    
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    } else {
      _notes.add(note);
    }
    
    _notifyListeners();
  }

  Future<List<NoteModel>> getAllNotes() async {
    final sorted = List<NoteModel>.from(_notes);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Stream<List<NoteModel>> watchNotes() {
    // Emit current state immediately
    Future.microtask(() => _notifyListeners());
    return _notesController.stream;
  }

  Future<void> deleteNote(int id) async {
    _notes.removeWhere((n) => n.id == id);
    _notifyListeners();
  }

  void _notifyListeners() {
    final sorted = List<NoteModel>.from(_notes);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notesController.add(sorted);
  }

  void dispose() {
    _notesController.close();
  }
}
