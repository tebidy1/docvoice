import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiTestDialog extends StatefulWidget {
  const GeminiTestDialog({super.key});

  @override
  State<GeminiTestDialog> createState() => _GeminiTestDialogState();
}

class _GeminiTestDialogState extends State<GeminiTestDialog> {
  final _geminiService = GeminiService(apiKey: dotenv.env['GEMINI_API_KEY'] ?? "");
  final _inputController = TextEditingController(
    text: "Patient John Doe presented with mild headache and fever. Temperature 38.5C, BP 120/80. Prescribed Paracetamol 500mg TID for 3 days. Follow up in 1 week."
  );
  final _questionController = TextEditingController();
  
  String _result = "";
  bool _isLoading = false;
  String _error = "";

  Future<void> _testAnalyzeNote() async {
    setState(() {
      _isLoading = true;
      _error = "";
      _result = "";
    });

    try {
      final analysis = await _geminiService.analyzeNote(_inputController.text);
      setState(() {
        _result = "✅ Success!\n\nPatient: ${analysis['patientName']}\nSummary: ${analysis['summary']}\nType: ${analysis['suggestedMacroType']}";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "❌ Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _testFormatText() async {
    setState(() {
      _isLoading = true;
      _error = "";
      _result = "";
    });

    try {
      final formatted = await _geminiService.formatText(
        _inputController.text,
        macroContext: "SOAP Note Format: Subjective, Objective, Assessment, Plan",
      );
      setState(() {
        _result = "✅ Success!\n\nFormatted Text:\n$formatted";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "❌ Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _testAskQuestion() async {
    if (_questionController.text.isEmpty) {
      setState(() => _error = "Please enter a question first.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = "";
      _result = "";
    });

    try {
      final answer = await _geminiService.askQuestion(
        _inputController.text,
        _questionController.text,
      );
      setState(() {
        _result = "❓ Question: ${_questionController.text}\n\n💡 Answer: $answer";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "❌ Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 650,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A2A),
              const Color(0xFF1A1A1A),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gemini AI Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // API Key Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true
                        ? Icons.check_circle
                        : Icons.error,
                    color: dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dotenv.env['GEMINI_API_KEY']?.isNotEmpty == true
                          ? 'API Key: ${dotenv.env['GEMINI_API_KEY']!.substring(0, 20)}...'
                          : 'API Key not found!',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Input
            const Text('Test Input:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter medical text to test...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Question Input
            const Text('Verification Question (Optional):', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g., What is the patient temperature?',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.question_answer),
                  label: const Text('Ask AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  ),
                  onPressed: _isLoading ? null : _testAskQuestion,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text('Test Analyze'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _testAnalyzeNote,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.format_align_left),
                    label: const Text('Test Format'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _testFormatText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Result
            const Text('Result:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.purple),
                            SizedBox(height: 16),
                            Text(
                              'Calling Gemini API...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _error.isNotEmpty ? _error : (_result.isNotEmpty ? _result : 'Press a button to test Gemini AI'),
                          style: TextStyle(
                            color: _error.isNotEmpty ? Colors.red : Colors.white,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _questionController.dispose();
    super.dispose();
  }
}
