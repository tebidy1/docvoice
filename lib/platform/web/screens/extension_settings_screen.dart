// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import '../../../presentation/screens/admin_dashboard_screen.dart';
import '../../../presentation/screens/secure_pairing_screen.dart';
import '../../android/features/settings/company_settings_screen.dart';
import '../../android/features/settings/macro_manager_screen.dart';

// Services & Core
import '../../../data/services/auth_service.dart';
import '../../android/core/theme.dart';
import '../../android/services/macro_service.dart';
import '../../android/services/websocket_service.dart';
import '../../../core/medical_departments.dart';
import '../../../core/services/department_service.dart';
import '../../../core/services/medical_department_service.dart';
import 'package:soutnote/core/entities/app_theme.dart' as global_theme;
import '../../../core/services/theme_service.dart';

class ExtensionSettingsScreen extends StatefulWidget {
  const ExtensionSettingsScreen({super.key});

  @override
  State<ExtensionSettingsScreen> createState() =>
      _ExtensionSettingsScreenState();
}

class _ExtensionSettingsScreenState extends State<ExtensionSettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = "Not Connected";
  Color _statusColor = Colors.grey;


  bool _useOracleWhisperModel = false;

  Map<String, dynamic>? _currentUser;
  bool _isFetchingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
    DepartmentService().addListener(_onDepartmentChanged);
  }

  @override
  void dispose() {
    _ipController.dispose();
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
      builder: (context) => AlertDialog(
        backgroundColor:
            Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),
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
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load from company settings if possible (optional sync)
    // ... logic omitted for brevity in Extension context unless explicitly needed,
    // but we load server IP
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";

      _useOracleWhisperModel =
          prefs.getBool('oracle_use_whisper_model') ?? true;
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
          _statusColor = MobileAppTheme.successGreen;
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
        backgroundColor:
            Theme.of(ctx).cardTheme.color ?? const Color(0xFF1E1E1E),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              color: Theme.of(context).cardTheme.color,
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
                                MobileAppTheme.primary.withValues(alpha: 0.2),
                            child: Text(
                                _currentUser?['name'] != null
                                    ? (_currentUser!['name'] as String)[0]
                                        .toUpperCase()
                                    : "?",
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(_currentUser?['name'] ?? "Guest User",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          subtitle: Text(
                              _currentUser?['email'] ?? "Not logged in",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withValues(alpha: 0.7))),
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.12)),
                        // Department Selection
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (MedicalDepartments.getById(
                                              DepartmentService().value)
                                          ?.color ??
                                      Colors.grey)
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              MedicalDepartments.getById(
                                          DepartmentService().value)
                                      ?.icon ??
                                  Icons.local_hospital,
                              color: MedicalDepartments.getById(
                                          DepartmentService().value)
                                      ?.color ??
                                  Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: Text("Medical Department",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          subtitle: Text(
                            MedicalDepartments.getById(
                                        DepartmentService().value)
                                    ?.nameEn ??
                                "Tap to select specialty",
                            style: TextStyle(
                              fontSize: 12,
                              color: DepartmentService().value == null
                                  ? Colors.redAccent
                                  : Colors.white54,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_drop_down,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.54)),
                          onTap: _showDepartmentPicker,
                          dense: true,
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.12)),
                        ListTile(
                          leading: const Icon(Icons.logout,
                              color: Colors.redAccent, size: 20),
                          title: const Text("Log Out",
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 14)),
                          onTap: _handleLogout,
                          dense: true,
                        ),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.12)),
                        ListTile(
                          leading: const Icon(Icons.devices,
                              color: Colors.blueAccent, size: 20),
                          title: const Text("Link New Device",
                              style: TextStyle(
                                  color: Colors.blueAccent, fontSize: 14)),
                          subtitle: Text("Generate QR for mobile to scan",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.54))),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SecurePairingScreen()),
                            );
                          },
                          dense: true,
                        ),

                        // Admin / Company
                        if (_currentUser?['role']?.toString().toLowerCase() ==
                                'admin' ||
                            _currentUser?['role']?.toString().toLowerCase() ==
                                'company_manager') ...[
                          Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.12)),
                          ListTile(
                            leading: const Icon(Icons.business,
                                color: Colors.amberAccent, size: 20),
                            title: const Text("Company Settings",
                                style: TextStyle(
                                    color: Colors.amberAccent, fontSize: 14)),
                            subtitle: Text("Manage per-company AI settings",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withValues(alpha: 0.54))),
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
                            Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.12)),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings,
                                  color: Colors.purpleAccent, size: 20),
                              title: const Text("Admin Dashboard",
                                  style: TextStyle(
                                      color: Colors.purpleAccent,
                                      fontSize: 14)),
                              subtitle: Text("Access advanced controls",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withValues(alpha: 0.54))),
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

            // --- Appearance ---
            _buildSectionHeader(context, "Appearance"),
            Card(
              color: Theme.of(context).cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ValueListenableBuilder<global_theme.ThemePreset>(
                  valueListenable: ThemeService(),
                  builder: (context, currentTheme, child) {
                    return Column(
                      children: [
                        RadioListTile<String>(
                          title: Text("Native Light",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          value: global_theme.ThemePreset.lightNative.id,
                          groupValue: currentTheme.id,
                          activeColor: MobileAppTheme.accent,
                          onChanged: (val) {
                            if (val != null)
                              ThemeService().setTheme(
                                  global_theme.ThemePreset.lightNative);
                          },
                        ),
                        RadioListTile<String>(
                          title: Text("Slate Dark",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          value: global_theme.ThemePreset.slateDark.id,
                          groupValue: currentTheme.id,
                          activeColor: MobileAppTheme.accent,
                          onChanged: (val) {
                            if (val != null)
                              ThemeService()
                                  .setTheme(global_theme.ThemePreset.slateDark);
                          },
                        ),
                        RadioListTile<String>(
                          title: Text("Dark Onyx",
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                          value: global_theme.ThemePreset.darkOnyx.id,
                          groupValue: currentTheme.id,
                          activeColor: MobileAppTheme.accent,
                          onChanged: (val) {
                            if (val != null)
                              ThemeService()
                                  .setTheme(global_theme.ThemePreset.darkOnyx);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Server Configuration ---
            _buildSectionHeader(context, "Server Configuration"),
            Card(
              color: Theme.of(context).cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: "Desktop IP Address",
                        hintText: "e.g. 192.168.1.105",
                        prefixIcon: Icon(Icons.computer,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7)),
                        labelStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7)),
                        hintStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.3)),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.24))),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary)),
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
                          backgroundColor: MobileAppTheme.primary,
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
              color: Theme.of(context).cardTheme.color,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: Icon(Icons.psychology,
                      color: Theme.of(context).colorScheme.secondary),
                ),
                title: Text("Macro Manager",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text("Manage custom templates",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.54))),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.3)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MacroManagerScreen()));
                },
              ),
            ),
            Card(
              color: Theme.of(context).cardTheme.color,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.restore, color: Colors.orange),
                ),
                title: Text("Reset to Default Macros",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text("Replace all with 8 medical templates",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.54))),
                trailing:
                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                onTap: _resetMacrosToDefaults,
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(context, "About"),
            Card(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                title: Text("ScribeFlow Extension",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text("Version 1.0.0",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.54))),
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
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: MobileAppTheme.primary, letterSpacing: 1.2),
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
      backgroundColor: MobileAppTheme.surface,
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
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital,
                              color: MobileAppTheme.accent),
                          const SizedBox(width: 12),
                          Text("Select Department",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search specialties...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: MobileAppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
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
                          final isSelected =
                              DepartmentService().value == dept.id;

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: dept.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child:
                                  Icon(dept.icon, color: dept.color, size: 24),
                            ),
                            title: Text(dept.nameEn,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? MobileAppTheme.accent
                                      : Colors.white,
                                )),
                            subtitle: Text(dept.nameAr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white54,
                                  fontFamily:
                                      'Cairo', // Assuming an Arabic font is available
                                )),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: MobileAppTheme.accent)
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
