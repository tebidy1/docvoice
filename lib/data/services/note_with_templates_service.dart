import 'package:flutter/foundation.dart';
import 'package:soutnote/core/entities/note_model.dart';
import 'package:soutnote/core/entities/generated_output.dart';
import 'inbox_note_api_service.dart';

/// Service for managing notes with multiple templates (outputs)
///
/// This service provides methods to save notes with multiple template outputs,
/// handling the upsert logic based on macro_id + inbox_note_id.
///
/// Usage:
/// ```dart
/// final service = NoteWithTemplatesService();
///
/// // Create a note with multiple templates
/// await service.saveNoteWithTemplates(
///   note: myNote,
///   outputs: [
///     GeneratedOutput(macroId: 1, title: 'Template 1', content: 'Content 1'),
///     GeneratedOutput(macroId: 2, title: 'Template 2', content: 'Content 2'),
///   ],
/// );
/// ```
class NoteWithTemplatesService {
  final InboxNoteApiClient _ApiClient = InboxNoteApiClient();

  /// Save a note with multiple template outputs
  ///
  /// This method:
  /// 1. First saves the note (creates or updates)
  /// 2. Then fetches existing outputs from the server
  /// 3. Performs upsert based on macro_id + inbox_note_id
  ///
  /// [note] - The note to save
  /// [outputs] - List of template outputs to save
  /// [isNewNote] - Set to true if creating a new note (default: based on note.id)
  Future<NoteModel> saveNoteWithTemplates({
    required NoteModel note,
    required List<GeneratedOutput> outputs,
    bool? isNewNote,
  }) async {
    try {
      // Determine if this is a new note
      final bool isNew = isNewNote ?? (note.id == 0);

      // Step 1: Save the note first
      NoteModel savedNote;
      if (isNew) {
        // Include outputs in the initial create request
        note.generatedOutputs = outputs;
        savedNote = await _ApiClient.createNote(note);
        debugPrint('✅ Created new note with ID: ${savedNote.id}');
      } else {
        // Update note without outputs first
        savedNote = await _ApiClient.updateNote(note.id.toString(), note);
        debugPrint('✅ Updated note ID: ${savedNote.id}');

        // Step 2: Fetch existing outputs from server
        final existingNote = await _ApiClient.fetchNoteById(note.id.toString());
        final existingOutputs = existingNote.generatedOutputs;

        // Step 3: Perform upsert based on macro_id + inbox_note_id
        final updatedOutputs = _performUpsert(
          noteId: savedNote.id,
          newOutputs: outputs,
          existingOutputs: existingOutputs,
        );

        // Step 4: Save the updated outputs
        savedNote.generatedOutputs = updatedOutputs;
        savedNote = await _ApiClient.updateNote(
          savedNote.id.toString(),
          savedNote,
        );
      }

      return savedNote;
    } catch (e) {
      debugPrint('❌ Error saving note with templates: $e');
      rethrow;
    }
  }

  /// Perform upsert operation based on macro_id + inbox_note_id
  List<GeneratedOutput> _performUpsert({
    required int noteId,
    required List<GeneratedOutput> newOutputs,
    required List<GeneratedOutput> existingOutputs,
  }) {
    final result = <GeneratedOutput>[];
    final processedMacroIds = <int>{};

    // First, iterate through new outputs and match with existing
    for (int i = 0; i < newOutputs.length; i++) {
      final newOutput = newOutputs[i];
      if (newOutput.macroId != null) {
        // Try to find existing output with same macro_id
        final existingMatch = existingOutputs.firstWhere(
          (e) => e.macroId == newOutput.macroId,
          orElse: () => GeneratedOutput(),
        );

        if (existingMatch.id != null && existingMatch.id != 0) {
          // Update existing - keep the same ID
          result.add(GeneratedOutput(
            id: existingMatch.id,
            macroId: newOutput.macroId,
            title: newOutput.title,
            content: newOutput.content,
            orderIndex: i,
          ));
          processedMacroIds.add(newOutput.macroId!);
        } else {
          // Create new - no ID yet
          result.add(GeneratedOutput(
            macroId: newOutput.macroId,
            title: newOutput.title,
            content: newOutput.content,
            orderIndex: i,
          ));
        }
      } else {
        // No macro_id, just add as new
        result.add(GeneratedOutput(
          title: newOutput.title,
          content: newOutput.content,
          orderIndex: i,
        ));
      }
    }

    // Add existing outputs that are NOT in new outputs (keep them)
    for (final existing in existingOutputs) {
      if (existing.macroId != null &&
          !processedMacroIds.contains(existing.macroId)) {
        // This output was in existing but not in new - keep it
        result.add(GeneratedOutput(
          id: existing.id,
          macroId: existing.macroId,
          title: existing.title,
          content: existing.content,
          orderIndex: result.length,
        ));
      }
    }

    return result;
  }

  /// Quick method to add a single template output to an existing note
  Future<NoteModel> addTemplateToNote({
    required int noteId,
    required int macroId,
    required String title,
    required String content,
  }) async {
    // Fetch existing note with outputs
    final existingNote = await _ApiClient.fetchNoteById(noteId.toString());

    // Check if this macro already exists
    final existingOutputIndex =
        existingNote.generatedOutputs.indexWhere((o) => o.macroId == macroId);

    if (existingOutputIndex >= 0) {
      // Update existing
      existingNote.generatedOutputs[existingOutputIndex] = GeneratedOutput(
        id: existingNote.generatedOutputs[existingOutputIndex].id,
        macroId: macroId,
        title: title,
        content: content,
        orderIndex: existingOutputIndex,
      );
    } else {
      // Add new
      existingNote.generatedOutputs.add(GeneratedOutput(
        macroId: macroId,
        title: title,
        content: content,
        orderIndex: existingNote.generatedOutputs.length,
      ));
    }

    return await _ApiClient.updateNote(noteId.toString(), existingNote);
  }

  /// Quick method to remove a template output from a note
  Future<NoteModel> removeTemplateFromNote({
    required int noteId,
    required int macroId,
  }) async {
    // Fetch existing note with outputs
    final existingNote = await _ApiClient.fetchNoteById(noteId.toString());

    // Remove the output with matching macro_id
    existingNote.generatedOutputs.removeWhere((o) => o.macroId == macroId);

    // Re-index order
    for (int i = 0; i < existingNote.generatedOutputs.length; i++) {
      existingNote.generatedOutputs[i].orderIndex = i;
    }

    return await _ApiClient.updateNote(noteId.toString(), existingNote);
  }

  /// Get all outputs for a specific macro from a note
  Future<GeneratedOutput?> getOutputForMacro({
    required int noteId,
    required int macroId,
  }) async {
    final note = await _ApiClient.fetchNoteById(noteId.toString());
    try {
      return note.generatedOutputs.firstWhere((o) => o.macroId == macroId);
    } catch (e) {
      return null;
    }
  }
}
