import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../models/app_theme.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/window_manager_helper.dart';

class CompanySettingsDialog extends StatefulWidget {
  const CompanySettingsDialog({super.key});

  @override
  State<CompanySettingsDialog> createState() => _CompanySettingsDialogState();
}

class _CompanySettingsDialogState extends State<CompanySettingsDialog> {
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  String _groqModel = 'whisper-large-v3-turbo';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setTransparencyLocked(true);
    _loadSettings();
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false);
    _groqKeyController.dispose();
    _geminiKeyController.dispose();
    _specialtyController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final companySettings = await AuthService().getCompanySettings();
      if (companySettings != null) {
        _groqKeyController.text = companySettings['groq_api_key'] ?? '';
        _geminiKeyController.text = companySettings['gemini_api_key'] ?? '';
        _groqModel =
            companySettings['groq_model_pref'] ?? 'whisper-large-v3-turbo';
        _specialtyController.text = companySettings['specialty'] ?? '';
        _promptController.text = companySettings['global_ai_prompt'] ?? '';
      } else {
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

    // Save to local storage
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
            backgroundColor: success ? Colors.green : Colors.red,
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
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        return Center(
          child: GestureDetector(
            onPanStart: (details) => windowManager.startDragging(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 500,
                height: 600,
                decoration: BoxDecoration(
                  color: currentTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTheme.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: currentTheme.borderColor)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business,
                              size: 24, color: currentTheme.iconColor),
                          const SizedBox(width: 12),
                          Text(
                            "Company Settings",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: currentTheme.iconColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _buildSectionHeader(
                                    "AI Configuration", currentTheme),
                                _buildTextField(
                                  label: "Groq API Key (STT)",
                                  controller: _groqKeyController,
                                  theme: currentTheme,
                                  obscure: true,
                                ),
                                const SizedBox(height: 16),
                                _buildModelSelector(currentTheme),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: "Gemini API Key (LLM)",
                                  controller: _geminiKeyController,
                                  theme: currentTheme,
                                  obscure: true,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: "Company Specialty",
                                  controller: _specialtyController,
                                  theme: currentTheme,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: "Global AI Instructions",
                                  controller: _promptController,
                                  theme: currentTheme,
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
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.iconColor.withOpacity(0.7),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required AppTheme theme,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.iconColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: maxLines,
          style: TextStyle(color: theme.iconColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.micIdleBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildModelSelector(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Transcription Model",
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.iconColor),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.micIdleBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: Text("High Precision (Slower)",
                    style: TextStyle(color: theme.iconColor)),
                value: 'whisper-large-v3',
                groupValue: _groqModel,
                onChanged: (val) => setState(() => _groqModel = val!),
                activeColor: Colors.blue,
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: Text("Turbo (Fastest)",
                    style: TextStyle(color: theme.iconColor)),
                value: 'whisper-large-v3-turbo',
                groupValue: _groqModel,
                onChanged: (val) => setState(() => _groqModel = val!),
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
