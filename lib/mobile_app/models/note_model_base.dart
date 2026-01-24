import 'package:flutter/foundation.dart' show kIsWeb;

enum NoteStatus {
  draft,      // Initial recording or raw text
  processed,  // AI macro applied
  ready,      // Confirmed by user, waiting to sync
  archived    // Synced/Completed
}

class NoteModelBase {
  // Use int for universal compatibility
  int id = 0;

  late String uuid; // Sync UUID

  late String title; // E.g. "Recording 1" or Patient Name
  
  late String content; // The text body
  
  String? audioPath; // Path to local .m4a file
  
  late NoteStatus status;
  
  late DateTime createdAt;
  late DateTime updatedAt;

  // Metadata for AI
  String? appliedMacroId;
  
  // API Sync Fields
  String originalText = ''; // Raw text from API/Input
  String formattedText = ''; // Processed text from API/AI
}
