import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/websocket_service.dart';
import '../../core/theme.dart';
import 'macro_manager_screen.dart';
import '../../services/macro_service.dart';
import '../../../services/auth_service.dart';
import '../../../screens/secure_pairing_screen.dart';
import '../auth/qr_scanner_screen.dart';

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
  
  String _groqModel = 'whisper-large-v3-turbo';
  bool _isLoading = false;
  String _statusMessage = "Not Connected";
  Color _statusColor = Colors.grey;

  Map<String, dynamic>? _currentUser;
  bool _isFetchingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isFetchingProfile = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Log Out?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
        showDialog(
            context: context, 
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator())
        );
    }

    await AuthService().logout();

    if (mounted) {
      // Clear navigation stack and go to Login
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try to load from company settings first
    try {
      final companySettings = await AuthService().getCompanySettings();
      if (companySettings != null) {
        if (companySettings.containsKey('groq_api_key')) {
          await prefs.setString('groq_api_key', companySettings['groq_api_key'] ?? '');
        }
        if (companySettings.containsKey('gemini_api_key')) {
          await prefs.setString('gemini_api_key', companySettings['gemini_api_key'] ?? '');
        }
        if (companySettings.containsKey('groq_model_pref')) {
          await prefs.setString('groq_model', companySettings['groq_model_pref'] ?? 'whisper-large-v3-turbo');
        }
      }
    } catch (e) {
      print("Failed to load company settings: $e");
    }
    
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";
      _apiKeyController.text = prefs.getString('groq_api_key') ?? "";
      _geminiKeyController.text = prefs.getString('gemini_api_key') ?? "AIzaSyBy2cwuD7oisj_glDlm8ga1036iN_CsLsU";
      _specialtyController.text = prefs.getString('specialty') ?? "";
      _promptController.text = prefs.getString('global_ai_prompt') ?? "";
      _groqModel = prefs.getString('groq_model') ?? 'whisper-large-v3-turbo';
    });
  }

// ... existing code ...

  Future<void> _saveAndConnect() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', _ipController.text);
    
    try {
      await WebSocketService().connect(_ipController.text, "8080");
       if (mounted) {
        setState(() {
          _statusMessage = "Connected";
          _statusColor = AppTheme.successGreen;
          _isLoading = false;
        });
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
          _statusColor = Colors.red;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetMacrosToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Reset Macros?", style: TextStyle(color: Colors.white)),
        content: const Text("This will restore default templates.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Reset", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await MacroService().resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Macros reset to defaults")));
      }
    }
  }

  Future<void> _saveAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save to local storage
    await prefs.setString('groq_api_key', _apiKeyController.text);
    await prefs.setString('gemini_api_key', _geminiKeyController.text);
    await prefs.setString('specialty', _specialtyController.text);
    await prefs.setString('global_ai_prompt', _promptController.text);
    await prefs.setString('groq_model', _groqModel);
    
    // Save API keys to company settings
    try {
      await AuthService().updateCompanySettings({
        'groq_api_key': _apiKeyController.text,
        'gemini_api_key': _geminiKeyController.text,
        'groq_model_pref': _groqModel,
      });
    } catch (e) {
      print("Failed to save company settings: $e");
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Configuration Saved")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            // --- Profile Section (Moved to Top as per standard UX) ---
            _buildSectionHeader(context, "Account"),
            Card(
              clipBehavior: Clip.antiAlias,
              child: _isFetchingProfile 
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.2),
                      child: Text(
                        _currentUser?['name'] != null ? (_currentUser!['name'] as String)[0].toUpperCase() : "?",
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)
                      ),
                    ),
                    title: Text(_currentUser?['name'] ?? "Guest User", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_currentUser?['email'] ?? "Not logged in", style: const TextStyle(fontSize: 12)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    title: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                    onTap: _handleLogout,
                    dense: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.devices, color: Colors.blueAccent, size: 20),
                    title: const Text("Link New Device", style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
                    subtitle: const Text("Generate QR for another phone to scan", style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SecurePairingScreen()),
                      );
                    },
                    dense: true,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner, color: Colors.greenAccent, size: 20),
                    title: const Text("Scan QR to Authorize", style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    subtitle: const Text("Authorize Chrome Extension or Desktop login", style: TextStyle(fontSize: 11)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                      );
                    },
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(context, "Server Configuration"),
            // ... existing code ...
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
                            value: 'whisper-large-v3', // High Precision
                            groupValue: _groqModel, 
                            onChanged: (val) => setState(() => _groqModel = val!),
                            activeColor: AppTheme.accent,
                            dense: true,
                          ),
                          RadioListTile<String>(
                            title: const Text("Turbo (Fastest)", style: TextStyle(fontSize: 14)),
                            subtitle: const Text("whisper-large-v3-turbo", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: 'whisper-large-v3-turbo', // Turbo
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
            
            // Removed duplicate Account Section
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
