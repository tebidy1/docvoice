import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../desktop/qr_pairing_dialog.dart';

import '../models/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_server.dart';
import '../services/theme_service.dart';
import '../utils/window_manager_helper.dart';
import 'admin_dashboard_screen.dart';
import 'company_settings_dialog.dart';
import '../core/medical_departments.dart';
import '../services/department_service.dart';
import '../services/medical_department_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String _localIp = "Loading...";
  String _sttEnginePref = 'groq';
  bool _useOracleWhisperModel = false;
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
    
    DepartmentService().addListener(_onDepartmentChanged);
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false);
    _resizeWindow(false);
    DepartmentService().removeListener(_onDepartmentChanged);
    super.dispose();
  }

  void _onDepartmentChanged() {
    if (mounted) setState(() {});
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
        _sttEnginePref = prefs.getString('stt_engine_pref') ?? 'gemini_oneshot';
        _useOracleWhisperModel = prefs.getBool('oracle_use_whisper_model') ?? true;
      });
    }
  }

  Future<void> _fetchIp() async {
    final ip = await ConnectivityServer.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  Future<void> _resizeWindow(bool expanded) async {
    await windowManager.setResizable(true);
    if (expanded) {
      await WindowManagerHelper.expandToCustomSizeBottomRight(500, 600);
    } else {
      // Defer collapse AFTER the widget is fully removed from the tree
      // to avoid layout overflow while the dialog is still rendering.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Do NOT collapse if a logout is in progress — the login screen
        // will be shown at full size and we must not shrink behind it.
        if (WindowManagerHelper.isLoggingOut) return;

        try {
          await windowManager.setSize(const Size(350, 56));
          await windowManager.setAlwaysOnTop(true);
          await windowManager.setResizable(false);

          // Re-position to right-center after collapsing
          final display = await screenRetriever.getPrimaryDisplay();
          final screenSize = display.size;
          const w = 350.0;
          const h = 56.0;
          final x = screenSize.width - w - 20;
          final y = screenSize.height - h - 80;
          await windowManager.setPosition(Offset(x, y));
        } catch (e) {
          print('Error collapsing settings window: $e');
        }
      });
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
                            
                            _buildMenuItem(
                              icon: MedicalDepartments.getById(DepartmentService().value)?.icon ?? Icons.local_hospital,
                              label: "Medical Department",
                              subtitle: MedicalDepartments.getById(DepartmentService().value)?.nameEn ?? "Tap to select specialty",
                              onTap: () => _showDepartmentPicker(currentTheme),
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


                            const SizedBox(height: 16),
                            _buildSectionHeader("Speech-to-Text Engine", currentTheme),
                            _buildSttItem(
                              title: "High-Speed Dictation (Cloud)",
                              value: 'groq',
                              theme: currentTheme,
                            ),
                            _buildSttItem(
                              title: "Offline Draft Mode (Built-in)",
                              value: 'native',
                              theme: currentTheme,
                            ),
                            _buildSttItem(
                              title: "Specialized Medical Dictation",
                              value: 'oracle_live',
                              theme: currentTheme,
                            ),
                            _buildSttItem(
                              title: "✨ Smart Magic Flow (Recommended)",
                              subtitle: "Skip transcription! Audio + Template → Final Note in 1 step.",
                              value: 'gemini_oneshot',
                              theme: currentTheme,
                            ),
                            if (_sttEnginePref == 'oracle_live') ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.science_outlined, size: 20, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _useOracleWhisperModel ? 'Engine: Ultra-Fast General' : 'Engine: Deep Medical Focus',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: currentTheme.iconColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _useOracleWhisperModel ? 'Prioritizes speed and general vocabulary' : 'Prioritizes complex clinical terminology',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: currentTheme.iconColor.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _useOracleWhisperModel,
                                      activeColor: Colors.orange,
                                      onChanged: (val) async {
                                        setState(() => _useOracleWhisperModel = val);
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.setBool('oracle_use_whisper_model', val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_sttEnginePref == 'gemini_oneshot') ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Records audio and applies your template in a single, lightning-fast step for ultimate speed and accuracy. No intermediate typing required.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: currentTheme.iconColor.withOpacity(0.65),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

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

  Widget _buildSttItem({
    required String title,
    String? subtitle,
    required String value,
    required AppTheme theme,
  }) {
    final isSelected = _sttEnginePref == value;
    final primaryColor = value == 'oracle_live'
        ? Colors.orange
        : value == 'gemini_oneshot'
            ? Colors.amber
            : Colors.blue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.micIdleBackground.withOpacity(0.8)
            : theme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected ? primaryColor : theme.dividerColor,
            width: isSelected ? 2 : 1),
      ),
      child: RadioListTile<String>(
        title: Text(title, style: TextStyle(color: theme.iconColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(color: theme.iconColor.withOpacity(0.6), fontSize: 12))
            : null,
        value: value,
        groupValue: _sttEnginePref,
        activeColor: primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onChanged: (val) async {
          if (val != null) {
            setState(() => _sttEnginePref = val);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('stt_engine_pref', val);
          }
        },
      ),
    );
  }

  void _showDepartmentPicker(AppTheme theme) {
    String searchQuery = '';
    
    // Ensure departments are loaded from API
    MedicalDepartmentService().loadDepartments();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredDepts = MedicalDepartments.all.where((dept) {
              final q = searchQuery.toLowerCase();
              return dept.nameEn.toLowerCase().contains(q) || 
                     dept.nameAr.contains(q);
            }).toList();

            return Dialog(
              backgroundColor: theme.backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 400,
                height: 500,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_hospital, color: theme.iconColor),
                        const SizedBox(width: 12),
                        Text("Select Department", 
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: theme.iconColor,
                          )
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: theme.iconColor.withOpacity(0.5),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      style: TextStyle(color: theme.iconColor),
                      decoration: InputDecoration(
                        hintText: "Search specialties...",
                        hintStyle: TextStyle(color: theme.iconColor.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: theme.iconColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: theme.micIdleBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDepts.length,
                        itemBuilder: (context, index) {
                          final dept = filteredDepts[index];
                          final isSelected = DepartmentService().value == dept.id;
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                DepartmentService().setDepartment(dept.id);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: theme.hoverColor,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: dept.color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(dept.icon, color: dept.color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(dept.nameEn, 
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? Colors.blue : theme.iconColor,
                                            )
                                          ),
                                          Text(dept.nameAr, 
                                            style: TextStyle(
                                              fontSize: 13, 
                                              color: theme.iconColor.withOpacity(0.6),
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected) 
                                      const Icon(Icons.check_circle, color: Colors.blue)
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
