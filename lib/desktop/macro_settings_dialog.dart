import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qr_connect_dialog.dart';
import 'gemini_test_dialog.dart';

class MacroSettingsDialog extends StatefulWidget {
  const MacroSettingsDialog({super.key});

  @override
  State<MacroSettingsDialog> createState() => _MacroSettingsDialogState();
}

class _MacroSettingsDialogState extends State<MacroSettingsDialog> {
  String _specialty = "General Practice";
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = true;
  bool _enableAiMacros = false;
  bool _enableSmartSuggestions = true; // Default: enabled

  final List<String> _specialties = [
    "General Practice",
    "Cardiology",
    "Dermatology",
    "Pediatrics",
    "Psychiatry",
    "Emergency Medicine",
    "Surgery",
    "Internal Medicine",
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _specialty = prefs.getString('medical_specialty') ?? "General Practice";
      _promptController.text = prefs.getString('global_ai_prompt') ?? 
          """You are an expert AI Medical Scribe.
1. Extract all clinical info from transcript.
2. Map to the selected template.
3. Fix ASR errors (e.g., 'Met for min' -> 'Metformin').
4. Use professional medical terminology and abbreviations.
5. DO NOT hallucinate missing info.""";
      _enableAiMacros = prefs.getBool('enable_ai_macros') ?? false;
      _enableSmartSuggestions = prefs.getBool('enable_smart_suggestions') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medical_specialty', _specialty);
    await prefs.setString('global_ai_prompt', _promptController.text);
    await prefs.setBool('enable_ai_macros', _enableAiMacros);
    await prefs.setBool('enable_smart_suggestions', _enableSmartSuggestions);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Settings saved!"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.white70),
          SizedBox(width: 10),
          Text("Macro Settings", style: TextStyle(color: Colors.white)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.amber)))
          : SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Connect Mobile Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code, color: Colors.black),
                      label: const Text("Connect Mobile App", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const QrConnectDialog(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Test Gemini Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.psychology, color: Colors.white),
                      label: const Text("Test Gemini AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const GeminiTestDialog(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text("Medical Specialty", style: TextStyle(color: Colors.amber, fontSize: 12)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _specialty,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF333333),
                        style: const TextStyle(color: Colors.white),
                        items: _specialties.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _specialty = newValue!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // AI Macros Toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, color: Colors.purple, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AI Smart Macros",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _enableAiMacros 
                                  ? "Enabled - Uses Gemini to fill templates intelligently"
                                  : "Disabled - Uses static macros only (faster)",
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enableAiMacros,
                          activeColor: Colors.purple,
                          onChanged: (value) {
                            setState(() {
                              _enableAiMacros = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  if (_enableAiMacros) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Global AI Prompt", style: TextStyle(color: Colors.amber, fontSize: 12)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _promptController.text = """You are an expert AI Medical Scribe.
1. Extract all clinical info from transcript.
2. Map to the selected template.
3. Fix ASR errors (e.g., 'Met for min' -> 'Metformin').
4. Use professional medical terminology and abbreviations.
5. DO NOT hallucinate missing info.""";
                            });
                          },
                          child: const Text("Reset to Default", style: TextStyle(color: Colors.blue, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _promptController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Instructions for the AI...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "This prompt guides Gemini when processing AI Macros.",
                      style: TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  ],

                const SizedBox(height: 15),
                
                // Smart Suggestions Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue[300], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Smart Suggestions",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _enableSmartSuggestions
                                  ? "⚡ Enabled - AI suggests missing info (+4-6s)"
                                  : "🚀 Disabled - Faster generation (saves 4-6s)",
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableSmartSuggestions,
                        activeColor: Colors.blue,
                        onChanged: (value) {
                          setState(() {
                            _enableSmartSuggestions = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          onPressed: _saveSettings,
          child: const Text("Save", style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
