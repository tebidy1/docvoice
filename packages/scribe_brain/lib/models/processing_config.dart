enum GroqModel {
  turbo('whisper-large-v3-turbo'),   // 50% faster, 95% accuracy
  precise('whisper-large-v3');       // Standard, 99% accuracy
  
  final String modelId;
  const GroqModel(this.modelId);
}

enum GeminiMode {
  fast,    // formatText() - Text only
  smart,   // formatTextWithSuggestions() - Text + JSON
}

class ProcessingConfig {
  final GroqModel groqModel;
  final GeminiMode geminiMode;
  final String? selectedMacroId;
  final Map<String, String>? userPreferences;
  
  const ProcessingConfig({
    required this.groqModel,
    required this.geminiMode,
    this.selectedMacroId,
    this.userPreferences,
  });
}
