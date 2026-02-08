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

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String _localIp = "Loading...";
  String _groqModelPref = "whisper-large-v3"; // Default
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _groqKeyController = TextEditingController();

  // Track initial values to determine if changes occurred
  String _initialGeminiKey = "";
  String _initialGroqKey = "";
  bool _isGeminiKeyChanged = false;
  bool _isGroqKeyChanged = false;

  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setTransparencyLocked(true);
    _fetchIp();
    _loadSettings();
    _resizeWindow(true);

    // Add Listeners
    _geminiKeyController.addListener(_checkGeminiChanges);
    _groqKeyController.addListener(_checkGroqChanges);
  }

  void _checkGeminiChanges() {
    setState(() {
      _isGeminiKeyChanged = _geminiKeyController.text != _initialGeminiKey;
    });
  }

  void _checkGroqChanges() {
    setState(() {
      _isGroqKeyChanged = _groqKeyController.text != _initialGroqKey;
    });
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
      setState(() {
        _groqModelPref =
            prefs.getString('groq_model_pref') ?? "whisper-large-v3";
        _geminiKeyController.text = prefs.getString('gemini_api_key') ?? "";
        _groqKeyController.text = prefs.getString('groq_api_key') ?? "";

        // Update initial values
        _initialGeminiKey = _geminiKeyController.text;
        _initialGroqKey = _groqKeyController.text;
        _isGeminiKeyChanged = false;
        _isGroqKeyChanged = false;
      });
    }
  }

  Future<void> _saveBackendSettings(Map<String, dynamic> newSettings) async {
    try {
      await _authService.updateCompanySettings(newSettings);
    } catch (e) {
      print("Failed to save company settings: $e");
    }
  }

  Future<void> _fetchIp() async {
    final ip = await ConnectivityServer.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false);
    _geminiKeyController.removeListener(_checkGeminiChanges);
    _groqKeyController.removeListener(_checkGroqChanges);
    _geminiKeyController.dispose();
    _groqKeyController.dispose();
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
                            _buildSectionHeader(
                                "AI Configuration", currentTheme),
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: currentTheme.micIdleBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: currentTheme.dividerColor),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Groq API Key",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: currentTheme.iconColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _groqKeyController,
                                    decoration: InputDecoration(
                                      hintText: "Enter your Groq API Key",
                                      hintStyle: TextStyle(
                                          color: currentTheme.iconColor
                                              .withOpacity(0.5)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: currentTheme.dividerColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: currentTheme.dividerColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                      ),
                                      filled: true,
                                      fillColor: currentTheme.backgroundColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.save,
                                            size: 20,
                                            color: _isGroqKeyChanged
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey),
                                        onPressed: !_isGroqKeyChanged
                                            ? null
                                            : () async {
                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                final newKey =
                                                    _groqKeyController.text
                                                        .trim();
                                                await prefs.setString(
                                                    'groq_api_key', newKey);

                                                // Sync to backend
                                                await _saveBackendSettings(
                                                    {'groq_api_key': newKey});

                                                setState(() {
                                                  _initialGroqKey = newKey;
                                                  _isGroqKeyChanged = false;
                                                });

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Groq Key Saved")),
                                                  );
                                                }
                                              },
                                      ),
                                    ),
                                    style: TextStyle(
                                        color: currentTheme.iconColor),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Gemini API Key",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: currentTheme.iconColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _geminiKeyController,
                                    decoration: InputDecoration(
                                      hintText: "Enter your Gemini API Key",
                                      hintStyle: TextStyle(
                                          color: currentTheme.iconColor
                                              .withOpacity(0.5)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: currentTheme.dividerColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color: currentTheme.dividerColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                      ),
                                      filled: true,
                                      fillColor: currentTheme.backgroundColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.save,
                                            size: 20,
                                            color: _isGeminiKeyChanged
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey),
                                        onPressed: !_isGeminiKeyChanged
                                            ? null
                                            : () async {
                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                final newKey =
                                                    _geminiKeyController.text
                                                        .trim();
                                                await prefs.setString(
                                                    'gemini_api_key', newKey);

                                                // Sync to backend
                                                await _saveBackendSettings(
                                                    {'gemini_api_key': newKey});

                                                setState(() {
                                                  _initialGeminiKey = newKey;
                                                  _isGeminiKeyChanged = false;
                                                });

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "API Key Saved")),
                                                  );
                                                }
                                              },
                                      ),
                                    ),
                                    style: TextStyle(
                                        color: currentTheme.iconColor),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Leave empty to use default key",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: currentTheme.iconColor
                                            .withOpacity(0.6)),
                                  ),
                                  const SizedBox(height: 16),

                                  // Explicit Save Button
                                  if (_isGeminiKeyChanged || _isGroqKeyChanged)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.save, size: 18),
                                        label: const Text("Save Changes"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        onPressed: () async {
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          final Map<String, dynamic> syncData =
                                              {};

                                          if (_isGroqKeyChanged) {
                                            final newGroqKey =
                                                _groqKeyController.text.trim();
                                            await prefs.setString(
                                                'groq_api_key', newGroqKey);
                                            syncData['groq_api_key'] =
                                                newGroqKey;
                                            setState(() {
                                              _initialGroqKey = newGroqKey;
                                              _isGroqKeyChanged = false;
                                            });
                                          }

                                          if (_isGeminiKeyChanged) {
                                            final newGeminiKey =
                                                _geminiKeyController.text
                                                    .trim();
                                            await prefs.setString(
                                                'gemini_api_key', newGeminiKey);
                                            syncData['gemini_api_key'] =
                                                newGeminiKey;
                                            setState(() {
                                              _initialGeminiKey = newGeminiKey;
                                              _isGeminiKeyChanged = false;
                                            });
                                          }

                                          if (syncData.isNotEmpty) {
                                            await _saveBackendSettings(
                                                syncData);
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    "Settings Saved Successfully"),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),

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
                            _buildSectionHeader(
                                "Transcription Precision", currentTheme),
                            _buildThemeItem(
                              icon: Icons.speed,
                              label: "Turbo (Fastest)",
                              isSelected:
                                  _groqModelPref == 'whisper-large-v3-turbo',
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString('groq_model_pref',
                                    'whisper-large-v3-turbo');
                                await _saveBackendSettings({
                                  'groq_model_pref': 'whisper-large-v3-turbo'
                                });
                                setState(() =>
                                    _groqModelPref = 'whisper-large-v3-turbo');
                              },
                              theme: currentTheme,
                            ),
                            _buildThemeItem(
                              icon: Icons.psychology_alt,
                              label: "High Precision (Slower)",
                              isSelected: _groqModelPref == 'whisper-large-v3',
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                    'groq_model_pref', 'whisper-large-v3');
                                await _saveBackendSettings(
                                    {'groq_model_pref': 'whisper-large-v3'});
                                setState(
                                    () => _groqModelPref = 'whisper-large-v3');
                              },
                              theme: currentTheme,
                            ),

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

                            const SizedBox(height: 16),
                            _buildSectionHeader("Administration", currentTheme),
                            _buildMenuItem(
                              icon: Icons.admin_panel_settings_outlined,
                              label: "Admin Dashboard",
                              subtitle: "Access advanced controls",
                              onTap: () {
                                // We need to pop first to close the dialog window logic
                                // But popping triggers dispose() -> shrink window.
                                // Then pushing Admin Dashboard might need the window to be proper size?
                                // AdminDashboard usually runs full screen (or normal window).
                                // If we shrink on dispose, AdminDashboard might open in small window?
                                // Wait, AdminDashboard should probably set its own preference or use the current window state.
                                // Let's assume standard behavior for now.
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
