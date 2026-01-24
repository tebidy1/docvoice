import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';

// Web Implementation: In-memory storage
// Web Implementation: SharedPreferences storage
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final List<NoteModel> _notes = [];
  final StreamController<List<NoteModel>> _notesController = 
      StreamController<List<NoteModel>>.broadcast();

  static const String _storageKey = 'web_notes_storage';
  int _nextId = 1;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    if (kIsWeb) {
      debugPrint("DatabaseService: Web mode - initializing storage");
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      
      if (data != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(data);
          _notes.clear();
          
          // Basic deserialization for Web NoteModel
          for (var item in jsonList) {
            final note = NoteModel();
            note.id = item['id'];
            note.uuid = item['uuid'] ?? '';
            note.title = item['title'] ?? 'Untitled';
            note.content = item['content'] ?? '';
            note.status = NoteStatus.values.firstWhere(
              (e) => e.toString() == item['status'], 
              orElse: () => NoteStatus.draft
            );
            note.createdAt = DateTime.fromMillisecondsSinceEpoch(item['createdAt']);
            note.updatedAt = DateTime.fromMillisecondsSinceEpoch(item['updatedAt']);
            note.audioPath = item['audioPath'];
            _notes.add(note);
          }
          
          if (_notes.isNotEmpty) {
            _nextId = _notes.map((e) => e.id).reduce((max, id) => id > max ? id : max) + 1;
          }
          debugPrint("DatabaseService: Loaded ${_notes.length} notes from storage.");
        } catch (e) {
          debugPrint("DatabaseService: Error loading notes: $e");
        }
      }
    }
    _initialized = true;
    _notifyListeners();
  }

  Future<void> saveNote(NoteModel note) async {
    if (!_initialized) await init();

    if (note.id == 0) {
      note.id = _nextId++;
      note.createdAt = DateTime.now(); // Ensure created at is set
      note.updatedAt = DateTime.now();
    } else {
      note.updatedAt = DateTime.now();
    }
    
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    } else {
      _notes.add(note);
    }
    
    await _persist();
    _notifyListeners();
  }

  Future<List<NoteModel>> getAllNotes() async {
    if (!_initialized) await init();
    final sorted = List<NoteModel>.from(_notes);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Stream<List<NoteModel>> watchNotes() {
    // Ensure initialized before emitting? 
    // For now, emit current and make sure init is called at app start
    if (!_initialized) init(); 
    
    Future.microtask(() => _notifyListeners());
    return _notesController.stream;
  }

  Future<void> deleteNote(int id) async {
    _notes.removeWhere((n) => n.id == id);
    await _persist();
    _notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_notes.map((n) => {
      'id': n.id,
      'uuid': n.uuid,
      'title': n.title,
      'content': n.content,
      'status': n.status.toString(),
      'createdAt': n.createdAt.millisecondsSinceEpoch,
      'updatedAt': n.updatedAt.millisecondsSinceEpoch,
      'audioPath': n.audioPath,
    }).toList());
    
    await prefs.setString(_storageKey, data);
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
