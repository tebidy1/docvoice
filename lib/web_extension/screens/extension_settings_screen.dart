import 'package:flutter/material.dart';
import '../../mobile_app/core/theme.dart';
import '../../services/auth_service.dart';
import 'profile_screen.dart';

class ExtensionSettingsScreen extends StatefulWidget {
  const ExtensionSettingsScreen({super.key});

  @override
  State<ExtensionSettingsScreen> createState() => _ExtensionSettingsScreenState();
}

class _ExtensionSettingsScreenState extends State<ExtensionSettingsScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Root of tab
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Button / Card
              _buildSectionHeader("Account"),
              Card(
                clipBehavior: Clip.antiAlias,
                color: AppTheme.surface, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accent.withOpacity(0.2),
                          radius: 24,
                          child: _isLoading 
                             ? const CircularProgressIndicator(strokeWidth: 2) 
                             : Text(
                                _currentUser?['name'] != null ? (_currentUser!['name'] as String)[0].toUpperCase() : "?",
                                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18),
                             ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?['name'] ?? "User Profile",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Manage account & devices",
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              _buildSectionHeader("General"),
              
              // Theme Setting (Visual Only for now as we enforced Dark)
              Card(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  value: true, 
                  onChanged: (val) {}, // Locked to Dark Mode
                  title: const Text("Dark Theme", style: TextStyle(color: Colors.white)),
                  subtitle: Text("Always on", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  secondary: const Icon(Icons.dark_mode, color: Colors.purpleAccent),
                  activeColor: AppTheme.accent,
                ),
              ),
              
              const SizedBox(height: 24),
              _buildSectionHeader("About"),
              Card(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: Text("ScribeFlow Extension", style: TextStyle(color: Colors.white)),
                  subtitle: Text("Version 1.0.0", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
