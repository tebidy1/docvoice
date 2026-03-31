/// Represents an AI-generated suggestion for missing clinical information
/// Used in the Smart Editor to provide quick-add functionality
class SmartSuggestion {
  /// Short label for the suggestion button (e.g., "Add BP", "No Fever")
  final String label;
  
  /// Full text to insert into the document when the suggestion is selected
  final String textToInsert;

  SmartSuggestion({
    required this.label,
    required this.textToInsert,
  });

  /// Create from JSON response from Gemini API
  factory SmartSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartSuggestion(
      label: json['label'] as String,
      textToInsert: json['text_to_insert'] as String,
    );
  }

  /// Convert to JSON for debugging/logging
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'text_to_insert': textToInsert,
    };
  }

  @override
  String toString() => 'SmartSuggestion(label: $label)';
}
