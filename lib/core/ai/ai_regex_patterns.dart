// ignore_for_file: dangling_library_doc_comments
/// ============================================================
/// AI REGEX PATTERNS — Docvoice Core AI Brain
/// ============================================================
/// Centralized repository for ALL Regular Expression patterns
/// used in AI-related text processing across all platforms.
///
/// Benefits of centralization:
///   - Consistent placeholder detection across: Mobile, Desktop,
///     Chrome Extension, and PWA.
///   - Single point of update if placeholder format ever changes.
///   - Enables unit testing of patterns in isolation.
///
/// USAGE EXAMPLE:
///   final hasPlaceholder = AIRegexPatterns.missingInfoPattern
///       .hasMatch(someText);
/// ============================================================

class AIRegexPatterns {
  AIRegexPatterns._(); // Prevent instantiation

  // ----------------------------------------------------------
  // PLACEHOLDER / MISSING INFO PATTERNS
  // ----------------------------------------------------------

  /// Detects "missing information" placeholders injected by AI
  /// when template fields had no matching data in the transcript.
  ///
  /// Matches patterns like:
  ///   - [Duration not specified]
  ///   - [License number not provided]
  ///   - [No medical conditions identified]
  ///   - [ Select ]
  ///   - [None]
  ///   - [Not provided]
  static final RegExp missingInfoPattern = RegExp(
    r'\[.*?(not\s+specified|not\s+provided|no\s+.*?\s+identified|select|none|not\s+reported|unknown|n\/a)\s*.*?\]',
    caseSensitive: false,
    dotAll: false,
  );

  /// Detects bare "Not Reported" text outside of brackets.
  /// Legacy pattern maintained for backward compatibility.
  static final RegExp notReportedPattern = RegExp(
    r'\bNot\s+Reported\b',
    caseSensitive: false,
  );

  /// Detects the specific "[ Select ]" placeholder that
  /// represents an unresolved dropdown/choice field.
  static final RegExp selectPlaceholderPattern = RegExp(
    r'\[\s*Select\s*\]',
    caseSensitive: false,
  );

  // ----------------------------------------------------------
  // BRACKET HIGHLIGHTING PATTERNS
  // ----------------------------------------------------------

  /// Matches ANY text enclosed in square brackets [like this].
  /// Used by PatternHighlightController to render orange
  /// highlighted placeholders in the editor.
  static final RegExp anyBracketPattern = RegExp(r'\[(.*?)\]');

  // ----------------------------------------------------------
  // HEADER FORMATTING PATTERN
  // ----------------------------------------------------------

  /// Matches section HEADERS in formatted medical notes.
  /// Headers are: ALL CAPS words followed by a colon.
  ///
  /// Examples matched:
  ///   - "SUBJECTIVE:"
  ///   - "PLAN:"
  ///   - "VITAL SIGNS:"
  ///   - "ASSESSMENT/PLAN:"
  ///
  /// Used by PatternHighlightController to render bold,
  /// underlined section headers.
  static final RegExp headerPattern = RegExp(
    r'^[A-Z][A-Z0-9\s\/\-\(\)\&]+:',
    multiLine: true,
  );

  // ----------------------------------------------------------
  // SMART COPY — INLINE PLACEHOLDER EXTRACTION
  // ----------------------------------------------------------

  /// Used by Smart Copy to REMOVE only the placeholder token
  /// from a line, preserving surrounding clinical data.
  ///
  /// This is the FIXED version of smart copy that avoids
  /// deleting entire lines containing valid medical data.
  ///
  /// Example:
  ///   Input:  "Vitals: BP: 120/80, HR: [Not Reported]"
  ///   Output: "Vitals: BP: 120/80, HR:"
  ///
  /// The old approach deleted the entire line — this is unsafe
  /// as it destroys valid data (e.g., BP: 120/80 above).
  static final RegExp inlinePlaceholderPattern = RegExp(
    r'\[.*?(not\s+specified|not\s+provided|no\s+.*?\s+identified|select|none|not\s+reported|unknown|n\/a)\s*.*?\]',
    caseSensitive: false,
    dotAll: false,
  );

  // ----------------------------------------------------------
  // ASR CORRECTION HELPERS (For reference, not used in Dart)
  // ----------------------------------------------------------
  // ASR corrections are handled server-side by the Gemini prompt.
  // Common corrections documented here for reference:
  //   "met for min"       -> "Metformin"
  //   "lasix"             -> "Furosemide"
  //   "am ox a cil in"    -> "Amoxicillin"
  //   "tylenol"           -> "Acetaminophen (Paracetamol)"
  //   "vit d"             -> "Vitamin D"
}






