import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../desktop/qr_pairing_dialog.dart';
import '../mobile_app/features/auth/qr_scanner_screen.dart';
import '../models/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_server.dart';
import '../services/theme_service.dart';
import '../utils/window_manager_helper.dart';
import 'admin_dashboard_screen.dart';
import 'company_settings_dialog.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String _localIp = "Loading...";
  // Track initial values to determine if changes occurred

  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setTransparencyLocked(true);
    _fetchIp();
    _loadSettings();
    _authService.getCurrentUser().then((_) {
      if (mounted) setState(() {});
    });
    _resizeWindow(true);
  }

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try to fetch from Company Settings (Backend)
    try {
      final companySettings = await _authService.getCompanySettings();
      if (companySettings != null) {
        // Update local SharedPreferences with company values
        if (companySettings.containsKey('groq_model_pref')) {
          await prefs.setString(
              'groq_model_pref', companySettings['groq_model_pref']);
        }
        if (companySettings.containsKey('gemini_api_key')) {
          await prefs.setString(
              'gemini_api_key', companySettings['gemini_api_key']);
        }
        if (companySettings.containsKey('groq_api_key')) {
          await prefs.setString(
              'groq_api_key', companySettings['groq_api_key']);
        }
      }
    } catch (e) {
      print("Failed to fetch company settings: $e");
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchIp() async {
    final ip = await ConnectivityServer.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false);
    _resizeWindow(false);
    super.dispose();
  }

  Future<void> _resizeWindow(bool expanded) async {
    // Enable resizing temporarily to animate/change size
    await windowManager.setResizable(true);
    if (expanded) {
      await windowManager
          .setSize(const Size(500, 600)); // Comfortable Settings Size
      await windowManager.center();
    } else {
      await windowManager
          .setSize(const Size(350, 56)); // Restore to Native Utility Toolbar
      await windowManager.setResizable(false); // Lock it back
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
        valueListenable: ThemeService(),
        builder: (context, currentTheme, child) {
          return Center(
            // Center content in the expanded window
            child: GestureDetector(
              onPanStart: (details) => windowManager.startDragging(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 500,
                  height: 600,
                  decoration: BoxDecoration(
                    color: currentTheme.backgroundColor, // Theme Background
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: currentTheme.borderColor), // Theme Border
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            0.5), // Using slightly darker shadow for all contexts
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
                              bottom: BorderSide(
                                  color: currentTheme
                                      .borderColor)), // Theme Border
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.settings,
                                size: 24,
                                color: currentTheme.iconColor), // Theme Icon
                            const SizedBox(width: 12),
                            Text(
                              "Settings",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: currentTheme.iconColor, // Theme Text
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
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildSectionHeader("Account", currentTheme),
                            _buildMenuItem(
                              icon: Icons.person_outline,
                              label: "My Profile",
                              subtitle: "Manage your account details",
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Profile Settings clicked")),
                                );
                              },
                              theme: currentTheme,
                            ),

                            const SizedBox(height: 16),

                            const SizedBox(height: 16),
                            _buildSectionHeader(
                                "Device Connection", currentTheme),
                            _buildMenuItem(
                              icon: Icons.qr_code_2,
                              label: "Connect Mobile App",
                              subtitle: "IP: $_localIp",
                              onTap: () async {
                                // Show QR Dialog
                                Navigator.pop(context);
                                await showDialog(
                                  context: context,
                                  builder: (context) => QrPairingDialog(
                                      ipAddress: _localIp, port: 8080),
                                );
                              },
                              theme: currentTheme,
                            ),
                            _buildMenuItem(
                              icon: Icons.qr_code_scanner,
                              label: "Scan QR to Authorize",
                              subtitle: "Authorize another device's login",
                              onTap: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const QrScannerScreen()),
                                );
                              },
                              theme: currentTheme,
                            ),

                            const SizedBox(height: 16),

                            const SizedBox(height: 16),
                            _buildSectionHeader("Appearance", currentTheme),

                            // Dark Onyx (Dark 2)
                            _buildThemeItem(
                              icon: Icons.dark_mode,
                              label: "Dark Onyx",
                              isSelected: currentTheme.id == 'dark_onyx',
                              onTap: () {
                                ThemeService().setTheme(AppTheme.darkOnyx);
                              },
                              theme: currentTheme,
                            ),

                            // Slate Dark (Standard)
                            _buildThemeItem(
                              icon: Icons.nightlight_round,
                              label: "Slate Dark",
                              isSelected: currentTheme.id == 'slate_dark',
                              onTap: () {
                                ThemeService().setTheme(AppTheme.slateDark);
                              },
                              theme: currentTheme,
                            ),

                            // Native Light (Default)
                            _buildThemeItem(
                              icon: Icons.light_mode,
                              label: "Native Light",
                              isSelected: currentTheme.id == 'light_native',
                              onTap: () {
                                ThemeService().setTheme(AppTheme.lightNative);
                              },
                              theme: currentTheme,
                            ),

                            if (_authService.isAdmin() ||
                                _authService.isCompanyManager()) ...[
                              const SizedBox(height: 16),
                              _buildSectionHeader(
                                  "Administration", currentTheme),
                              _buildMenuItem(
                                icon: Icons.business_outlined,
                                label: "Company Settings",
                                subtitle: "Manage AI & Company configuration",
                                onTap: () async {
                                  Navigator.pop(context);
                                  await showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    barrierColor: Colors.transparent,
                                    builder: (context) =>
                                        const CompanySettingsDialog(),
                                  );
                                },
                                theme: currentTheme,
                              ),
                              if (_authService.isAdmin())
                                _buildMenuItem(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: "Admin Dashboard",
                                  subtitle: "Access advanced controls",
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const AdminDashboardScreen()),
                                    );
                                  },
                                  theme: currentTheme,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _buildSectionHeader(String title, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.iconColor.withOpacity(0.7), // Theme text (dimmed)
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    required AppTheme theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme
            .micIdleBackground, // Using mic background as content background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: theme.hoverColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.backgroundColor, // Inner background
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20, color: theme.iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.iconColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.iconColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.iconColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppTheme theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.micIdleBackground.withOpacity(0.8)
            : theme.backgroundColor, // Highlight selected
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected ? Colors.blue : theme.dividerColor,
            width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: theme.hoverColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.1)
                      : theme.micIdleBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon,
                    size: 20,
                    color: isSelected ? Colors.blue : theme.iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.iconColor,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.blue, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
