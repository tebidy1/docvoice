import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/admin_dashboard_screen.dart';
import '../../../screens/secure_pairing_screen.dart';
import '../../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../services/macro_service.dart';
import '../../services/websocket_service.dart';
import '../../../models/app_theme.dart' as global_theme;
import '../../../services/theme_service.dart';
import '../auth/qr_scanner_screen.dart';
import 'company_settings_screen.dart';
import 'macro_manager_screen.dart';
import '../../../core/medical_departments.dart';
import '../../../services/department_service.dart';
import '../../../services/medical_department_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = "Not Connected";
  Color _statusColor = Colors.grey;
  String _sttEnginePref = 'gemini_oneshot';

  // A/B Testing: Oracle Medical (default) vs Whisper Generic
  bool _useOracleWhisperModel = false; // false = Oracle Medical, true = Whisper Generic

  Map<String, dynamic>? _currentUser;
  bool _isFetchingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
    
    // Listen for department changes
    DepartmentService().addListener(_onDepartmentChanged);
  }

  @override
  void dispose() {
    DepartmentService().removeListener(_onDepartmentChanged);
    super.dispose();
  }

  void _onDepartmentChanged() {
    if (mounted) setState(() {});
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text("Log Out?", style: TextStyle(color: colorScheme.onSurface)),
          content: Text(
            "Are you sure you want to log out?",
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
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
        );
      },
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
          await prefs.setString(
              'groq_api_key', companySettings['groq_api_key'] ?? '');
        }
        if (companySettings.containsKey('gemini_api_key')) {
          await prefs.setString(
              'gemini_api_key', companySettings['gemini_api_key'] ?? '');
        }
        if (companySettings.containsKey('groq_model_pref')) {
          await prefs.setString('groq_model',
              companySettings['groq_model_pref'] ?? 'whisper-large-v3-turbo');
        }
      }
    } catch (e) {
      print("Failed to load company settings: $e");
    }

    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";
      _sttEnginePref = prefs.getString('stt_engine_pref') ?? 'gemini_oneshot';
      _useOracleWhisperModel = prefs.getBool('oracle_use_whisper_model') ?? true;
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
        title:
            const Text("Reset Macros?", style: TextStyle(color: Colors.white)),
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
    return SingleChildScrollView(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings",
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // --- Profile Section (Moved to Top as per standard UX) ---
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
                          title: Text(_currentUser?['name'] ?? "Guest User",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              _currentUser?['email'] ?? "Not logged in",
                              style: const TextStyle(fontSize: 12)),
                        ),
                        const Divider(height: 1),
                        // Department Selection
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (MedicalDepartments.getById(DepartmentService().value)?.color ?? Colors.grey).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              MedicalDepartments.getById(DepartmentService().value)?.icon ?? Icons.local_hospital,
                              color: MedicalDepartments.getById(DepartmentService().value)?.color ?? Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: const Text("Medical Department", 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            MedicalDepartments.getById(DepartmentService().value)?.nameEn ?? "Tap to select specialty",
                            style: TextStyle(
                              fontSize: 12,
                              color: DepartmentService().value == null ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: _showDepartmentPicker,
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
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.devices,
                              color: Colors.blueAccent, size: 20),
                          title: const Text("Link New Device",
                              style: TextStyle(
                                  color: Colors.blueAccent, fontSize: 14)),
                          subtitle: const Text(
                              "Generate QR for another phone to scan",
                              style: TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SecurePairingScreen()),
                            );
                          },
                          dense: true,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.qr_code_scanner,
                              color: Colors.greenAccent, size: 20),
                          title: const Text("Scan QR to Authorize",
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 14)),
                          subtitle: const Text(
                              "Authorize Chrome Extension or Desktop login",
                              style: TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const QrScannerScreen()),
                            );
                          },
                          dense: true,
                        ),
                        if (_currentUser?['role']?.toString().toLowerCase() ==
                                'admin' ||
                            _currentUser?['role']?.toString().toLowerCase() ==
                                'company_manager') ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.business,
                                color: Colors.amberAccent, size: 20),
                            title: const Text("Company Settings",
                                style: TextStyle(
                                    color: Colors.amberAccent, fontSize: 14)),
                            subtitle: const Text(
                                "Manage per-company AI settings",
                                style: TextStyle(fontSize: 11)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CompanySettingsScreen()),
                              );
                            },
                            dense: true,
                          ),
                          if (_currentUser?['role']?.toString().toLowerCase() ==
                              'admin') ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings,
                                  color: Colors.purpleAccent, size: 20),
                              title: const Text("Admin Dashboard",
                                  style: TextStyle(
                                      color: Colors.purpleAccent,
                                      fontSize: 14)),
                              subtitle: const Text("Access advanced controls",
                                  style: TextStyle(fontSize: 11)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminDashboardScreen()),
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

            _buildSectionHeader(context, "Appearance"),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ValueListenableBuilder<global_theme.AppTheme>(
                  valueListenable: ThemeService(),
                  builder: (context, currentTheme, child) {
                    return Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text("Native Light"),
                          value: global_theme.AppTheme.lightNative.id,
                          groupValue: currentTheme.id,
                          activeColor: AppTheme.accent,
                          onChanged: (val) {
                            if (val != null) ThemeService().setTheme(global_theme.AppTheme.lightNative);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text("Slate Dark"),
                          value: global_theme.AppTheme.slateDark.id,
                          groupValue: currentTheme.id,
                          activeColor: AppTheme.accent,
                          onChanged: (val) {
                            if (val != null) ThemeService().setTheme(global_theme.AppTheme.slateDark);
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text("Dark Onyx"),
                          value: global_theme.AppTheme.darkOnyx.id,
                          groupValue: currentTheme.id,
                          activeColor: AppTheme.accent,
                          onChanged: (val) {
                            if (val != null) ThemeService().setTheme(global_theme.AppTheme.darkOnyx);
                          },
                        ),
                      ],
                    );
                  },
                ),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.link),
                        label: Text(_isLoading
                            ? "Connecting..."
                            : "Connect to Desktop"),
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

            _buildSectionHeader(context, "Speech-to-Text Engine"),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text("High-Speed Dictation (Cloud)"),
                      subtitle: const Text("Lightning-fast processing via cloud servers."),
                      value: 'groq',
                      groupValue: _sttEnginePref,
                      activeColor: AppTheme.accent,
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _sttEnginePref = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('stt_engine_pref', val);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text("Offline Draft Mode (Built-in)"),
                      subtitle: const Text("Basic transcription using device's internal engine."),
                      value: 'native',
                      groupValue: _sttEnginePref,
                      activeColor: AppTheme.accent,
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _sttEnginePref = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('stt_engine_pref', val);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text("Specialized Medical Dictation"),
                      subtitle: const Text("Cloud-based engine trained on complex medical terminology."),
                      value: 'oracle_live',
                      groupValue: _sttEnginePref,
                      activeColor: Colors.orange,
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _sttEnginePref = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('stt_engine_pref', val);
                        }
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text("G£¿ Smart Magic Flow (Recommended)",
                          style: TextStyle(color: Colors.amber)),
                      subtitle: const Text("Max speed! Audio maps directly to final formatted note. No intermediate step."),
                      value: 'gemini_oneshot',
                      groupValue: _sttEnginePref,
                      activeColor: Colors.amber,
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() => _sttEnginePref = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('stt_engine_pref', val);
                        }
                      },
                    ),
                    // A/B Testing Toggle GÇö only visible when Oracle is selected
                    if (_sttEnginePref == 'oracle_live') ...
                      [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.science_outlined, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _useOracleWhisperModel
                                          ? 'Engine: Ultra-Fast General'
                                          : 'Engine: Deep Medical Focus',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      _useOracleWhisperModel
                                          ? 'Prioritizes speed and general vocabulary'
                                          : 'Prioritizes complex clinical terminology',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                    // Info block for One-Shot mode
                    if (_sttEnginePref == 'gemini_oneshot') ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Records audio and applies your template in a single, lightning-fast step for ultimate speed and accuracy. Ideal for fast, high-quality clinical notes.',
                                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(context, "AI Brain & Macros"),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.psychology, color: AppTheme.accent),
                ),
                title: const Text("Macro Manager"),
                subtitle: const Text("Manage custom templates"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MacroManagerScreen()));
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.restore, color: Colors.orange),
                ),
                title: const Text("Reset to Default Macros"),
                subtitle: const Text("Replace all with 8 medical templates"),
                trailing:
                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                onTap: _resetMacrosToDefaults,
              ),
            ),

            const SizedBox(height: 24),

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
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  void _showDepartmentPicker() {
    String searchQuery = '';
    
    // Ensure departments are loaded from API
    MedicalDepartmentService().loadDepartments();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredDepts = MedicalDepartments.all.where((dept) {
              final q = searchQuery.toLowerCase();
              return dept.nameEn.toLowerCase().contains(q) || 
                     dept.nameAr.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital, color: AppTheme.accent),
                          const SizedBox(width: 12),
                          Text("Select Department", 
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search specialties in English or Arabic...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // List
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredDepts.length,
                        itemBuilder: (context, index) {
                          final dept = filteredDepts[index];
                          final isSelected = DepartmentService().value == dept.id;
                          
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: dept.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(dept.icon, color: dept.color, size: 24),
                            ),
                            title: Text(dept.nameEn, 
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppTheme.accent : null,
                              )
                            ),
                            subtitle: Text(dept.nameAr, 
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.grey.shade600,
                                fontFamily: 'Cairo', // Assuming an Arabic font is available
                              )
                            ),
                            trailing: isSelected 
                                ? const Icon(Icons.check_circle, color: AppTheme.accent)
                                : null,
                            onTap: () {
                              DepartmentService().setDepartment(dept.id);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

