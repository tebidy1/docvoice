class ProcessedNote {
  final String rawTranscript;
  final String formattedText;
  final List<Suggestion> suggestions;
  final Duration processingTime;
  final ProcessingMetrics metrics;
  
  ProcessedNote({
    required this.rawTranscript,
    required this.formattedText,
    this.suggestions = const [],
    required this.processingTime,
    required this.metrics,
  });
}

class Suggestion {
  final String label;
  final String textToInsert;
  
  Suggestion({required this.label, required this.textToInsert});

  // Serialization helpers if needed for JSON/WebSocket
  Map<String, dynamic> toJson() => {
    'label': label,
    'text_to_insert': textToInsert,
  };

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      label: json['label'] as String,
      textToInsert: json['text_to_insert'] as String,
    );
  }
}

class ProcessingMetrics {
  final Duration transcriptionTime;
  final Duration formattingTime;
  final String groqModelUsed;
  final String geminiModeUsed;

  ProcessingMetrics({
    required this.transcriptionTime,
    required this.formattingTime,
    required this.groqModelUsed,
    required this.geminiModeUsed,
  });
}
