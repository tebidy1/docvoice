import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../mobile_app/core/theme.dart';
import '../../screens/secure_pairing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isFetchingProfile = true;

  @override
  void initState() {
    super.initState();
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
          builder: (_) => const Center(child: CircularProgressIndicator()));
    }

    await AuthService().logout();

    if (mounted) {
      // Clear navigation stack and go to Login
      // For extension, this usually means reloading the app or hitting the AuthGuard
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, "Account"),
              Card(
                clipBehavior: Clip.antiAlias,
                child: _isFetchingProfile
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withOpacity(0.2),
                              child: Text(
                                  _currentUser?['name'] != null
                                      ? (_currentUser!['name'] as String)[0]
                                          .toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                                _currentUser?['name'] ?? "Guest User",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                _currentUser?['email'] ?? "Not logged in",
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.devices,
                                color: Colors.blueAccent, size: 20),
                            title: const Text("Link New Device",
                                style: TextStyle(
                                    color: Colors.blueAccent, fontSize: 14)),
                            subtitle: const Text(
                                "Log in on another device using a QR code",
                                style: TextStyle(fontSize: 11)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SecurePairingScreen()),
                              );
                            },
                            dense: true,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout,
                                color: Colors.redAccent, size: 20),
                            title: const Text("Log Out",
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 14)),
                            onTap: _handleLogout,
                            dense: true,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(context, "About"),
              const Card(
                child: ListTile(
                  title: Text("ScribeFlow Extension"),
                  subtitle: Text("Version 1.0.0"),
                  leading: Icon(Icons.info_outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }
}
