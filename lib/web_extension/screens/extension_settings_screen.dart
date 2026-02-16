import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import '../../screens/admin_dashboard_screen.dart';
import '../../screens/secure_pairing_screen.dart';
import '../../mobile_app/features/auth/qr_scanner_screen.dart';
import '../../mobile_app/features/settings/company_settings_screen.dart';
import '../../mobile_app/features/settings/macro_manager_screen.dart';

// Services & Core
import '../../services/auth_service.dart';
import '../../mobile_app/core/theme.dart';
import '../../mobile_app/services/macro_service.dart';
import '../../mobile_app/services/websocket_service.dart';

class ExtensionSettingsScreen extends StatefulWidget {
  const ExtensionSettingsScreen({super.key});

  @override
  State<ExtensionSettingsScreen> createState() => _ExtensionSettingsScreenState();
}

class _ExtensionSettingsScreenState extends State<ExtensionSettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

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
          "Are you sure you want to log out of the extension?",
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
          builder: (_) => const Center(child: CircularProgressIndicator()));
    }

    await AuthService().logout();

    if (mounted) {
      // Clear navigation stack and go to Login (reloading app effectively)
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load from company settings if possible (optional sync)
    // ... logic omitted for brevity in Extension context unless explicitly needed, 
    // but we load server IP
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";
    });
    
    // Check initial connection status if needed
    // WebSocketService().isConnected ? ...
  }

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
        content: const Text("This will restore default templates.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Reset", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await MacroService().resetToDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Macros reset to defaults")));
      }
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
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Account Section ---
            _buildSectionHeader(context, "Account"),
            Card(
              clipBehavior: Clip.antiAlias,
              color: AppTheme.surface,
              child: _isFetchingProfile
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.2),
                            child: Text(
                                _currentUser?['name'] != null
                                    ? (_currentUser!['name'] as String)[0].toUpperCase()
                                    : "?",
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(
                              _currentUser?['name'] ?? "Guest User",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text(
                              _currentUser?['email'] ?? "Not logged in",
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                          title: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                          onTap: _handleLogout,
                          dense: true,
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          leading: const Icon(Icons.devices, color: Colors.blueAccent, size: 20),
                          title: const Text("Link New Device", style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
                          subtitle: const Text("Generate QR for mobile to scan", style: TextStyle(fontSize: 11, color: Colors.white54)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SecurePairingScreen()),
                            );
                          },
                          dense: true,
                        ),
                        // Only show Scan QR if user really wants to scan FROM laptop (e.g. authorize desktop login?)
                        const Divider(height: 1, color: Colors.white12),
                        ListTile(
                          leading: const Icon(Icons.qr_code_scanner, color: Colors.greenAccent, size: 20),
                          title: const Text("Scan QR to Authorize", style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                          subtitle: const Text("Authorize Desktop login", style: TextStyle(fontSize: 11, color: Colors.white54)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                            );
                          },
                          dense: true,
                        ),

                        // Admin / Company
                        if (_currentUser?['role']?.toString().toLowerCase() == 'admin' ||
                            _currentUser?['role']?.toString().toLowerCase() == 'company_manager') ...[
                          const Divider(height: 1, color: Colors.white12),
                          ListTile(
                            leading: const Icon(Icons.business, color: Colors.amberAccent, size: 20),
                            title: const Text("Company Settings", style: TextStyle(color: Colors.amberAccent, fontSize: 14)),
                            subtitle: const Text("Manage per-company AI settings", style: TextStyle(fontSize: 11, color: Colors.white54)),
                            onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CompanySettingsScreen()),
                                );
                            },
                            dense: true,
                          ),
                          if (_currentUser?['role']?.toString().toLowerCase() == 'admin') ...[
                            const Divider(height: 1, color: Colors.white12),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings, color: Colors.purpleAccent, size: 20),
                              title: const Text("Admin Dashboard", style: TextStyle(color: Colors.purpleAccent, fontSize: 14)),
                              subtitle: const Text("Access advanced controls", style: TextStyle(fontSize: 11, color: Colors.white54)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                                );
                              },
                              dense: true,
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
            
            const SizedBox(height: 24),

            // --- Server Configuration ---
            _buildSectionHeader(context, "Server Configuration"),
            Card(
              color: AppTheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Desktop IP Address",
                        hintText: "e.g. 192.168.1.105",
                        prefixIcon: Icon(Icons.computer, color: Colors.white70),
                        labelStyle: TextStyle(color: Colors.white70),
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveAndConnect,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
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
                        Text(_statusMessage,
                            style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- AI Brain & Macros ---
            _buildSectionHeader(context, "AI Brain & Macros"),
             Card(
              color: AppTheme.surface,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.psychology, color: AppTheme.accent),
                ),
                title: const Text("Macro Manager", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Manage custom templates", style: TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MacroManagerScreen()));
                },
              ),
            ),
            Card(
              color: AppTheme.surface,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.restore, color: Colors.orange),
                ),
                title: const Text("Reset to Default Macros", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Replace all with 8 medical templates", style: TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.warning, size: 16, color: Colors.orange),
                onTap: _resetMacrosToDefaults,
              ),
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader(context, "About"),
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
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
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
