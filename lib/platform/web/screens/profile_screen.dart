import 'package:flutter/material.dart';
import '../../../data/services/auth_service.dart';
import '../../../presentation/screens/secure_pairing_screen.dart';

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
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
        title: Text("Log Out?",
            style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(
          "Are you sure you want to log out?",
          style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                              backgroundColor:
                                  colorScheme.primary.withValues(alpha: 0.2),
                              child: Text(
                                  _currentUser?['name'] != null
                                      ? (_currentUser!['name'] as String)[0]
                                          .toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(_currentUser?['name'] ?? "Guest User",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: onSurface)),
                            subtitle: Text(
                                _currentUser?['email'] ?? "Not logged in",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: onSurface.withValues(alpha: 0.7))),
                          ),
                          Divider(
                              height: 1,
                              color:
                                  theme.dividerColor.withValues(alpha: 0.12)),
                          ListTile(
                            leading: const Icon(Icons.devices,
                                color: Colors.blueAccent, size: 20),
                            title: const Text("Link New Device",
                                style: TextStyle(
                                    color: Colors.blueAccent, fontSize: 14)),
                            subtitle: Text(
                                "Log in on another device using a QR code",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: onSurface.withValues(alpha: 0.54))),
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
                          Divider(
                              height: 1,
                              color:
                                  theme.dividerColor.withValues(alpha: 0.12)),
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
              Card(
                child: ListTile(
                  title: Text("ScribeFlow Extension",
                      style: TextStyle(color: onSurface)),
                  subtitle: Text("Version 1.0.0",
                      style:
                          TextStyle(color: onSurface.withValues(alpha: 0.54))),
                  leading: const Icon(Icons.info_outline),
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
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }
}
