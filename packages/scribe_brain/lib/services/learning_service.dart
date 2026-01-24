class LearningService {
  // In the future, this will use Isar to store persistent rules.
  // For now, it manages the "Global Prompt" combining static rules and dynamic user preferences.

  final List<String> _staticRules = [
    "Always capitalize brand name drugs.",
    "Use 'Patient' instead of 'Pt' or 'The patient'.",
    "Convert 'degrees' to '°C'.",
  ];

  String? _userCustomPrompt;

  LearningService();

  /// Updates the user's custom prompt preference (Explicit Learning)
  void updateUserPrompt(String prompt) {
    _userCustomPrompt = prompt;
  }

  /// Generates the full Global Prompt string
  String getGlobalPrompt() {
    final buffer = StringBuffer();
    
    // Add Static Safety Rules
    buffer.writeln("CORE SAFETY RULES:");
    for (var rule in _staticRules) {
      buffer.writeln("- $rule");
    }

    // Add User Custom Rules
    if (_userCustomPrompt != null && _userCustomPrompt!.isNotEmpty) {
      buffer.writeln("\nUSER PREFERENCES:");
      buffer.writeln(_userCustomPrompt);
    }
    
    return buffer.toString();
  }
}
