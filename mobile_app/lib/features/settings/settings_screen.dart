import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/websocket_service.dart';
import '../../core/theme.dart';
import 'macro_manager_screen.dart';
import 'package:scribe_brain/scribe_brain.dart';
import '../../services/macro_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  
  String _groqModel = 'whisper-large-v3'; // Default to High Accuracy
  bool _isLoading = false;
  String _statusMessage = "Not Connected";
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }



  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";
      _apiKeyController.text = prefs.getString('groq_api_key') ?? "";
      _geminiKeyController.text = prefs.getString('gemini_api_key') ?? "AIzaSyBy2cwuD7oisj_glDlm8ga1036iN_CsLsU";
      _specialtyController.text = prefs.getString('specialty') ?? "";
      _specialtyController.text = prefs.getString('specialty') ?? "";
      _promptController.text = prefs.getString('global_ai_prompt') ?? "";
      _groqModel = prefs.getString('groq_model') ?? 'whisper-large-v3';
    });
  }

  Future<void> _saveAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', _apiKeyController.text.trim());
    await prefs.setString('gemini_api_key', _geminiKeyController.text.trim());
    await prefs.setString('specialty', _specialtyController.text.trim());
    await prefs.setString('global_ai_prompt', _promptController.text.trim());
    await prefs.setString('groq_model', _groqModel);
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Configuration Saved ✅"), backgroundColor: AppTheme.successGreen));
    }
  }

  Future<void> _saveAndConnect() async {
    setState(() => _isLoading = true);
    final ip = _ipController.text.trim();
    
    // Save
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);

    // Connect
    final ws = Provider.of<WebSocketService>(context, listen: false);
    try {
      await ws.connect(ip, "8080");
      if (mounted) {
        setState(() {
          _statusMessage = "Connected to $ip";
          _statusColor = AppTheme.successGreen;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected!"), backgroundColor: AppTheme.successGreen));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Connection Failed";
          _statusColor = AppTheme.recordRed;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: AppTheme.recordRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetMacrosToDefaults() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Reset Macros?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will DELETE all existing macros and restore the 8 default medical templates (SOAP, Sick Leave, Medical Report, etc.).\n\nThis cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final macroService = MacroService();
      
      // Reset (deletes cloud macros and re-seeds defaults)
      await macroService.resetToDefaults();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Macros reset to medical templates"),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to reset: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), // Added bottom padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            _buildSectionHeader(context, "Server Configuration"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: "Desktop IP Address",
                        hintText: "e.g. 192.168.1.105",
                        prefixIcon: Icon(Icons.computer),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveAndConnect,
                        icon: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.link),
                        label: Text(_isLoading ? "Connecting..." : "Connect to Desktop"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, size: 10, color: _statusColor),
                        const SizedBox(width: 8),
                        Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            
            
            _buildSectionHeader(context, "AI Brain & Macros"),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.psychology, color: AppTheme.accent),
                ),
                title: const Text("Macro Manager"),
                subtitle: const Text("Manage custom templates"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MacroManagerScreen()));
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.restore, color: Colors.orange),
                ),
                title: const Text("Reset to Default Macros"),
                subtitle: const Text("Replace all with 8 medical templates"),
                trailing: const Icon(Icons.warning, size: 16, color: Colors.orange),
                onTap: _resetMacrosToDefaults,
              ),
            ),

            const SizedBox(height: 24),
            const SizedBox(height: 24),
            _buildSectionHeader(context, "AI Configuration (Standalone)"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                     TextField(
                      controller: _apiKeyController, // Groq Key
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
                            child: Text("Transcription Model (Speed vs Accuracy)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                          RadioListTile<String>(
                            title: const Text("High Precision (Slower)", style: TextStyle(fontSize: 14)),
                            subtitle: const Text("whisper-large-v3", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: GroqModel.precise.modelId, // Use enum from scribe_brain
                            groupValue: _groqModel, 
                            onChanged: (val) => setState(() => _groqModel = val!),
                            activeColor: AppTheme.accent,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: const Text("Turbo (Fastest)", style: TextStyle(fontSize: 14)),
                            subtitle: const Text("whisper-large-v3-turbo", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: GroqModel.turbo.modelId, // Use enum from scribe_brain
                            groupValue: _groqModel, 
                            onChanged: (val) => setState(() => _groqModel = val!),
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
                        labelText: "Your Specialty",
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
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAIConfig,
                        icon: const Icon(Icons.save),
                        label: const Text("Save AI Configuration"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader(context, "Account"),
            const Card(
              child: ListTile(
                leading: Icon(Icons.person),
                title: Text("Dr. Strange"),
                subtitle: Text("Cardiology"),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }
}
