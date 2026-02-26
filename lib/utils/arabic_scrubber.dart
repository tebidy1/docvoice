class ArabicScrubber {
  /// Anonymizes Personal Identifiable Information (PII) from the transcribed text.
  /// Masks names and IDs/MRNs using regex and dictionary lookups.
  static String anonymizePII(String input) {
    if (input.isEmpty) return input;
    
    String scrubbed = input;

    // 1. Mask Numbers: ID numbers, Iqamas, Phone numbers, or MRNs (sequences of 7 to 15 digits)
    final idRegex = RegExp(r'\b\d{7,15}\b');
    scrubbed = scrubbed.replaceAll(idRegex, '[رقم السجل/الهوية]');

    // 2. Mask English Patient Names (e.g., "Patient John Doe", "Patient name is Jane Smith")
    final engPatientNameRegex = RegExp(r'(patient|name is|called)\s+([A-Z][a-z]+\s+[A-Z][a-z]+)', caseSensitive: false);
    scrubbed = scrubbed.replaceAllMapped(engPatientNameRegex, (match) {
      return '${match.group(1)} [NAME HIDDEN]';
    });

    // 3. Mask Arabic Patient Names (e.g., "المريض فلان الفلاني", "المريضة فاطمة محمد")
    // This matches common introductory words followed by 2 Arabic words
    final arPatientNameRegex = RegExp(r'(المريض|المريضة|يدعى|تدعى|اسمه|اسمها)\s+([\u0600-\u06FF]+\s+[\u0600-\u06FF]+)');
    scrubbed = scrubbed.replaceAllMapped(arPatientNameRegex, (match) {
      return '${match.group(1)} [اسم المريض]';
    });

    // 4. Scrub explicit bracketed markers that doctors might dictate literally
    scrubbed = scrubbed.replaceAll(RegExp(r'\[اسم مريض\]|\[رقم هوية\]'), '[PII HIDDEN]');

    return scrubbed;
  }
}
