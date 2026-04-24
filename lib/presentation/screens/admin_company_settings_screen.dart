import 'package:flutter/material.dart';

import '../../platform/android/core/theme.dart';
import '../../core/services/admin_service.dart';

class AdminCompanySettingsScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const AdminCompanySettingsScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<AdminCompanySettingsScreen> createState() =>
      _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState
    extends State<AdminCompanySettingsScreen> {
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

    try {
      final companySettings =
          await AdminService().getCompanySettings(widget.companyId);
      if (companySettings != null) {
        if (companySettings.containsKey('groq_api_key')) {
          _groqKeyController.text = companySettings['groq_api_key'] ?? '';
        }
        if (companySettings.containsKey('gemini_api_key')) {
          _geminiKeyController.text = companySettings['gemini_api_key'] ?? '';
        }
        if (companySettings.containsKey('groq_model_pref')) {
          _groqModel =
              companySettings['groq_model_pref'] ?? 'whisper-large-v3-turbo';
        }
        if (companySettings.containsKey('specialty')) {
          _specialtyController.text = companySettings['specialty'] ?? '';
        }
        if (companySettings.containsKey('global_ai_prompt')) {
          _promptController.text = companySettings['global_ai_prompt'] ?? '';
        }
      }
    } catch (e) {
      print("Failed to load company settings for admin: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error loading settings: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final success =
          await AdminService().updateCompanySettings(widget.companyId, {
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
            backgroundColor: success ? MobileAppTheme.success : Colors.red,
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
        title: Text("Settings: ${widget.companyName}"),
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
                                  activeColor: MobileAppTheme.accent,
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
                                  activeColor: MobileAppTheme.accent,
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
                                backgroundColor: MobileAppTheme.accent,
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
