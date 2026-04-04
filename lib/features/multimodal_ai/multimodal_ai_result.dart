// ============================================================
// MULTIMODAL AI — RESULT DATA MODEL
// ============================================================
// Part of: lib/features/multimodal_ai/
//
// This data model is shared between all implementations of
// MultimodalAIService (AI Studio, Vertex AI, Backend proxy).
// ============================================================

/// The result of a multimodal AI note-processing request.
/// Returned by every implementation of [MultimodalAIService].
class MultimodalAIResult {
  /// The final formatted medical note ready for physician review.
  /// Contains [bracket] placeholders for any missing fields.
  final String formattedNote;

  /// True if the response was received successfully from the AI model.
  final bool success;

  /// Human-readable error message when [success] is false.
  final String? errorMessage;

  /// The underlying provider that generated this result.
  /// Useful for debugging and analytics.
  final String providerName;

  const MultimodalAIResult({
    required this.formattedNote,
    required this.success,
    required this.providerName,
    this.errorMessage,
  });

  /// Convenience factory for error results.
  factory MultimodalAIResult.error(String message, {String provider = 'unknown'}) {
    return MultimodalAIResult(
      formattedNote: '',
      success: false,
      errorMessage: message,
      providerName: provider,
    );
  }

  @override
  String toString() => 'MultimodalAIResult('
      'success=$success, provider=$providerName, '
      'length=${formattedNote.length})';
}
