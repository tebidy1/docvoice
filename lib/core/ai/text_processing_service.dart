// ignore_for_file: dangling_library_doc_comments
/// ============================================================
/// TEXT PROCESSING SERVICE — Docvoice Core AI Brain
/// ============================================================
/// Centralized service for ALL text transformation operations
/// that occur AFTER the AI generates the formatted note.
///
/// PLATFORM-AGNOSTIC: Works identically on:
///   - Mobile (Android / iOS)
///   - Desktop (Windows / macOS)
///   - Chrome Extension
///   - PWA
///
/// PHASE 3 READY:
/// All methods are pure functions (input -> output, no side
/// effects). Easy to unit test and trivially replaceable when
/// the server handles these operations in Phase 3.
/// ============================================================

import 'ai_regex_patterns.dart';

class TextProcessingService {
  TextProcessingService._(); // Prevent instantiation — use static methods

  // ----------------------------------------------------------
  // SMART COPY — FIXED & SAFE IMPLEMENTATION
  // ----------------------------------------------------------

  /// Removes ALL placeholder tokens from the note text, while
  /// preserving valid clinical data on the same line.
  ///
  /// DESIGN DECISION: Smart Copy removes ALL bracket content
  /// `[...]` — both unfilled template fields (e.g.: [Dx])
  /// AND AI-generated missing-info markers (e.g.: [Not Reported]).
  /// In the final output, any remaining bracket is a placeholder
  /// that should not appear in a note pasted into an EMR.
  ///
  /// ✅ SAFE — Preserves data on same line:
  ///   Input:  "• Vitals: BP: 130/85 mmHg | HR: [Value / bpm] | Temp: 37.1°C"
  ///   Output: "• Vitals: BP: 130/85 mmHg | HR:  | Temp: 37.1°C"  →→ "• Vitals: BP: 130/85 mmHg | HR: | Temp: 37.1°C"
  ///
  /// ✅ DISCARDS label-only lines (no clinical value remaining):
  ///   Input:  "• Diagnosis: [Diagnosis not specified]"
  ///   After:  "• Diagnosis:"   →  meaningless → discarded
  ///
  /// ✅ Preserves structural headers:
  ///   "SUBJECTIVE:" → kept (structural element, not a data label)
  ///
  /// ❌ OLD (BROKEN) BEHAVIOR — now fixed:
  ///   The old code deleted an ENTIRE LINE the moment it found
  ///   any placeholder, destroying valid data on that line.
  ///
  /// [text] The full formatted AI-generated note text.
  /// Returns clean text safe to paste into an EMR system.
  static String applySmartCopy(String text) {
    if (text.isEmpty) return '';

    final lines = text.split('\n');
    final cleanLines = <String>[];

    for (final line in lines) {
      // Preserve intentional blank separator lines (structural)
      if (_isBlankSeparatorLine(line)) {
        cleanLines.add('');
        continue;
      }

      // Step 1: Remove ALL bracket placeholders inline
      // Uses anyBracketPattern — catches [Dx], [Value / bpm],
      // [Not Reported], [Diagnosis not specified], etc.
      String cleanedLine =
          line.replaceAll(AIRegexPatterns.anyBracketPattern, '');

      // Step 2: Remove bare "Not Reported" text (legacy format)
      cleanedLine =
          cleanedLine.replaceAll(AIRegexPatterns.notReportedPattern, '');

      // Step 3: Clean up visual artifacts left after removal
      cleanedLine = _cleanArtifacts(cleanedLine);

      // Step 4: Keep only lines with meaningful clinical content
      if (_hasMeaningfulContent(cleanedLine)) {
        cleanLines.add(cleanedLine);
      }
      // else: silently discard — was placeholder-only or became a bare label
    }

    // Final pass: collapse 3+ consecutive blank lines → 1 blank line
    return _collapseMultipleBlankLines(cleanLines.join('\n')).trim();
  }

  // ----------------------------------------------------------
  // PLACEHOLDER COUNTING
  // ----------------------------------------------------------

  /// Returns the total count of placeholder tokens in [text].
  /// Used for the Smart Copy feedback message:
  ///   "Copied without 3 placeholder tokens."
  ///
  /// Counts ALL bracket occurrences plus bare "Not Reported" text.
  /// Deduplicates by start position to avoid double-counting.
  static int countPlaceholders(String text) {
    if (text.isEmpty) return 0;

    // Use a Set of start positions to avoid double-counting
    // tokens that might match multiple patterns.
    final matchedPositions = <int>{};

    // Count all [...] bracket occurrences (catches everything)
    for (final m in AIRegexPatterns.anyBracketPattern.allMatches(text)) {
      matchedPositions.add(m.start);
    }

    // Count bare "Not Reported" occurrences NOT inside brackets
    for (final m in AIRegexPatterns.notReportedPattern.allMatches(text)) {
      matchedPositions.add(m.start);
    }

    return matchedPositions.length;
  }

  // ----------------------------------------------------------
  // PLACEHOLDER DETECTION
  // ----------------------------------------------------------

  /// Returns true if [text] contains any AI-generated placeholder
  /// token that should not appear in a final clinical document.
  static bool hasPlaceholders(String text) {
    if (text.isEmpty) return false;
    return AIRegexPatterns.anyBracketPattern.hasMatch(text) ||
        AIRegexPatterns.notReportedPattern.hasMatch(text);
  }

  /// Returns all bracket-enclosed placeholder spans in [text].
  /// Each item contains: start index, end index, and content.
  ///
  /// Used by PatternHighlightController and the tap-to-select
  /// gesture handler in editor screens across all platforms.
  static List<({int start, int end, String content})> findAllPlaceholders(
      String text) {
    if (text.isEmpty) return [];
    return AIRegexPatterns.anyBracketPattern
        .allMatches(text)
        .map((m) => (start: m.start, end: m.end, content: m.group(0) ?? ''))
        .toList();
  }

  /// Finds the placeholder span that the cursor is positioned
  /// inside (or at the boundary of).
  ///
  /// Returns (start, end) range to auto-select the full token,
  /// or null if the cursor is not inside any placeholder.
  ///
  /// Used by all editor screens for the "tap-to-select" feature:
  /// pressing any character key inside a bracket placeholder
  /// auto-selects the whole bracket before typing.
  static ({int start, int end})? findPlaceholderAtCursor(
      String text, int cursorOffset) {
    if (text.isEmpty || cursorOffset < 0) return null;

    // Priority 1: Check bracket placeholders [...]
    for (final match in AIRegexPatterns.anyBracketPattern.allMatches(text)) {
      if (cursorOffset >= match.start && cursorOffset <= match.end) {
        return (start: match.start, end: match.end);
      }
    }

    // Priority 2: Check bare "Not Reported" text
    for (final match
        in AIRegexPatterns.notReportedPattern.allMatches(text)) {
      if (cursorOffset >= match.start && cursorOffset <= match.end) {
        return (start: match.start, end: match.end);
      }
    }

    return null;
  }

  // ----------------------------------------------------------
  // PRIVATE HELPERS
  // ----------------------------------------------------------

  /// Returns true if the original line was intentionally blank
  /// (used as a structural section separator in the note).
  static bool _isBlankSeparatorLine(String originalLine) =>
      originalLine.trim().isEmpty;

  /// Returns true if the cleaned line contains meaningful
  /// clinical content worth including in the copied note.
  ///
  /// Logic:
  ///   - Empty → false (discard)
  ///   - ALL-CAPS HEADER (e.g. "SUBJECTIVE:", "PLAN:") → true (keep structure)
  ///   - Label-only line (e.g. "• Diagnosis:") → false (discard = no data)
  ///   - Has actual content beyond label → true (keep)
  static bool _hasMeaningfulContent(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // Always keep ALL-CAPS section headers — they provide structure
    // e.g. "SUBJECTIVE:", "OBJECTIVE:", "PLAN:", "ASSESSMENT/PLAN:"
    if (AIRegexPatterns.headerPattern.hasMatch(trimmed) &&
        trimmed == trimmed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s\/\-:]'), trimmed)) {
      // It's a structural header — check it's truly all-caps
      final upperContent = trimmed.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (upperContent == upperContent.toUpperCase()) return true;
    }

    // Discard lines that are ONLY a label (field name + colon + nothing)
    // Pattern: optional bullet • - * then label text then colon then only whitespace
    // Examples that should be discarded:
    //   "• Diagnosis:"
    //   "- Chief Complaint:"
    //   "Primary Diagnosis:"
    //   "  • HPI:"
    final labelOnlyPattern = RegExp(r'^[•\-\*\s]*[^:\n]+:\s*$');
    if (labelOnlyPattern.hasMatch(trimmed)) return false;

    // Has actual clinical content beyond just a label
    return true;
  }

  /// Cleans up visual artifacts left after placeholder removal:
  ///   - Collapses multiple consecutive spaces
  ///   - Removes lines that are ONLY punctuation/bullets after cleaning
  ///   - Trims the result
  static String _cleanArtifacts(String line) {
    // Collapse multiple consecutive spaces into one
    String result = line.replaceAll(RegExp(r'  +'), ' ');

    // Trim leading/trailing whitespace
    result = result.trim();

    // Discard lines that are ONLY punctuation or bullet symbols
    // e.g. "•", "-", "| |", ":"
    if (result.isNotEmpty &&
        RegExp(r'^[•\-\|\:\,\.\;\s]+$').hasMatch(result)) {
      return '';
    }

    return result;
  }

  /// Collapses 3+ consecutive blank lines into a single blank line.
  /// Preserves intentional double-spacing but prevents excessive gaps.
  static String _collapseMultipleBlankLines(String text) {
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }
}






