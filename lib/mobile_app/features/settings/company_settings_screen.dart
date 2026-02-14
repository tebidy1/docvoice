import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../core/theme.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  String _groqModel = 'whisper-large-v3-turbo';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final companySettings = await AuthService().getCompanySettings();
      if (companySettings != null) {
        if (companySettings.containsKey('groq_api_key')) {
          _groqKeyController.text = companySettings['groq_api_key'] ?? '';
          await prefs.setString('groq_api_key', _groqKeyController.text);
        }
        if (companySettings.containsKey('gemini_api_key')) {
          _geminiKeyController.text = companySettings['gemini_api_key'] ?? '';
          await prefs.setString('gemini_api_key', _geminiKeyController.text);
        }
        if (companySettings.containsKey('groq_model_pref')) {
          _groqModel =
              companySettings['groq_model_pref'] ?? 'whisper-large-v3-turbo';
          await prefs.setString('groq_model', _groqModel);
        }
        if (companySettings.containsKey('specialty')) {
          _specialtyController.text = companySettings['specialty'] ?? '';
          await prefs.setString('specialty', _specialtyController.text);
        }
        if (companySettings.containsKey('global_ai_prompt')) {
          _promptController.text = companySettings['global_ai_prompt'] ?? '';
          await prefs.setString('global_ai_prompt', _promptController.text);
        }
      } else {
        // Fallback to local if backend fails or returns null
        _groqKeyController.text = prefs.getString('groq_api_key') ?? "";
        _geminiKeyController.text = prefs.getString('gemini_api_key') ?? "";
        _specialtyController.text = prefs.getString('specialty') ?? "";
        _promptController.text = prefs.getString('global_ai_prompt') ?? "";
        _groqModel = prefs.getString('groq_model') ?? 'whisper-large-v3-turbo';
      }
    } catch (e) {
      print("Failed to load company settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // Save to local storage for immediate use
    await prefs.setString('groq_api_key', _groqKeyController.text);
    await prefs.setString('gemini_api_key', _geminiKeyController.text);
    await prefs.setString('specialty', _specialtyController.text);
    await prefs.setString('global_ai_prompt', _promptController.text);
    await prefs.setString('groq_model', _groqModel);

    // Save to backend
    try {
      final success = await AuthService().updateCompanySettings({
        'groq_api_key': _groqKeyController.text,
        'gemini_api_key': _geminiKeyController.text,
        'groq_model_pref': _groqModel,
        'specialty': _specialtyController.text,
        'global_ai_prompt': _promptController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? "Settings Saved Successfully"
                : "Failed to Save Settings"),
            backgroundColor: success ? AppTheme.success : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Company Settings"),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, "AI Configuration"),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _groqKeyController,
                            decoration: const InputDecoration(
                              labelText: "Groq API Key (STT)",
                              hintText: "gsk_...",
                              prefixIcon: Icon(Icons.mic),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),

                          // Groq Model Selection
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                                  child: Text(
                                      "Transcription Model (Speed vs Accuracy)",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                ),
                                RadioListTile<String>(
                                  title: const Text("High Precision (Slower)",
                                      style: TextStyle(fontSize: 14)),
                                  subtitle: const Text("whisper-large-v3",
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  value: 'whisper-large-v3',
                                  groupValue: _groqModel,
                                  onChanged: (val) =>
                                      setState(() => _groqModel = val!),
                                  activeColor: AppTheme.accent,
                                  dense: true,
                                ),
                                RadioListTile<String>(
                                  title: const Text("Turbo (Fastest)",
                                      style: TextStyle(fontSize: 14)),
                                  subtitle: const Text("whisper-large-v3-turbo",
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  value: 'whisper-large-v3-turbo',
                                  groupValue: _groqModel,
                                  onChanged: (val) =>
                                      setState(() => _groqModel = val!),
                                  activeColor: AppTheme.accent,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          TextField(
                            controller: _geminiKeyController,
                            decoration: const InputDecoration(
                              labelText: "Gemini API Key (LLM)",
                              hintText: "AIza...",
                              prefixIcon: Icon(Icons.psychology),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _specialtyController,
                            decoration: const InputDecoration(
                              labelText: "Company Specialty",
                              hintText: "e.g. Cardiology",
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _promptController,
                            decoration: const InputDecoration(
                              labelText: "Global AI Instructions",
                              hintText: "e.g. Always use British spelling...",
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveSettings,
                              icon: const Icon(Icons.save),
                              label: const Text("Save Configuration"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }
}
