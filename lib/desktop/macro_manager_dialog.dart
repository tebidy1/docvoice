import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soutnote/services/macro_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:soutnote/core/utils/window_manager_helper.dart';
import 'package:soutnote/services/keyboard_service.dart';
import 'package:soutnote/core/models/macro.dart';
import 'package:soutnote/core/models/app_theme.dart';
import 'package:soutnote/services/theme_service.dart';
import 'package:soutnote/services/department_service.dart';
import 'package:soutnote/core/medical_departments.dart';
import 'dart:async';
import 'macro_settings_dialog.dart';
import 'package:soutnote/shared/widgets/user_profile_header.dart';

// ─── Primary Blue — consistent with login & light theme ───────────────────
const Color _kBlue = Color(0xFF00A5FE);

class MacroManagerDialog extends StatefulWidget {
  const MacroManagerDialog({super.key});

  @override
  State<MacroManagerDialog> createState() => _MacroManagerDialogState();
}

class _MacroManagerDialogState extends State<MacroManagerDialog> {
  final MacroService _macroService = MacroService();

  // ── state ──────────────────────────────────────────────────────────────
  List<Macro> _allMacros = [];   // raw full list
  List<Macro> _macros    = [];   // filtered by selected category
  bool   _isLoading = true;
  String _selectedCategory = 'All Macros';
  String _searchQuery = '';
  String? _userDeptId;           // current user's department id
  final TextEditingController _searchController = TextEditingController();



  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setOpacity(1.0);
    WindowManagerHelper.setTransparencyLocked(true);
    _resizeWindow(true);
    _loadDeptThenMacros();
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false);
    _searchController.dispose();
    // Capture context before dispose invalidates it
    final ctx = context;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WindowManagerHelper.collapseToPill(ctx);
    });
    super.dispose();
  }

  Future<void> _resizeWindow(bool expanded) async {
    if (expanded) {
      await WindowManagerHelper.expandToCustomSizeBottomRight(900, 650);
    }
  }

  // ── load ──────────────────────────────────────────────────────────────
  Future<void> _loadDeptThenMacros() async {
    _userDeptId = DepartmentService().value;
    await _loadMacros();
  }

  Future<void> _loadMacros() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _macroService.init();
      final all = await _macroService.getAllMacros();

      // ─ Apply department filter (same logic as MacroManagerScreen) ─
      final deptId = _userDeptId;
      final deptNameEn = deptId != null
          ? MedicalDepartments.getById(deptId)?.nameEn
          : null;

final filtered = all.where((Macro m) {
        final cats = m.category.split(',').map((e) => e.trim()).toList();
        if (cats.isEmpty || cats.contains('General') || cats.contains('General Practice')) return true;
        if (deptId != null && cats.contains(deptId)) return true;
        if (deptNameEn != null && cats.contains(deptNameEn)) return true;
        return false;
      }).toList();

      _allMacros = all;

      // ─ Now apply category sidebar selection ─
      final macros = _applyCategory(filtered);

      if (mounted) {
        setState(() {
          _macros   = macros;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MacroManager: Error: $e');
      if (mounted) {
        setState(() { _isLoading = false; _macros = []; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading macros: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _loadMacros),
        ));
      }
    }
  }

  List<Macro> _applyCategory(List<Macro> pool) {
    switch (_selectedCategory) {
      case 'Favorites':  return pool.where((m) => m.isFavorite).toList();
      case 'Most Used':
        final sorted = List<Macro>.from(pool);
        sorted.sort((a, b) => (b.usageCount).compareTo(a.usageCount));
        return sorted;
      case 'All Macros': return pool;
      default:
        // Department category — filter by name
        return pool.where((m) {
          final cats = m.category.split(',').map((e) => e.trim()).toList();
          return cats.contains(_selectedCategory);
        }).toList();
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────
  List<Macro> get _filteredMacros {
    if (_searchQuery.isEmpty) return _macros;
    final q = _searchQuery.toLowerCase();
    return _macros.where((m) =>
        m.trigger.toLowerCase().contains(q) ||
        m.content.toLowerCase().contains(q)).toList();
  }

  /// Group _filteredMacros by category string for display — mirrors MacroManagerScreen
  Map<String, List<Macro>> get _grouped {
    final Map<String, List<Macro>> groups = {};
    final favs = _filteredMacros.where((m) => m.isFavorite).toList();
    if (favs.isNotEmpty) groups['Favorites'] = favs;

    for (final m in _filteredMacros) {
      if (m.isFavorite) continue;
      final cats = m.category.split(',').map((e) => e.trim()).toList();
      String displayCat = 'General';
      if (cats.isNotEmpty && cats.first.isNotEmpty) {
        final dept = MedicalDepartments.getById(cats.first);
        displayCat = dept != null ? dept.nameEn : cats.first;
      }
      groups.putIfAbsent(displayCat, () => []).add(m);
    }
    return groups;
  }

  Future<void> _toggleFavorite(Macro macro) async {
    await _macroService.toggleFavorite(macro.id);
    await _loadMacros();
  }

  // ── categories available in sidebar ───────────────────────────────────
  List<String> get _departmentCategories {
    // Get unique categories present in the filtered macros
    final cats = <String>{};
    for (final m in _allMacros) {
      for (final c in m.category.split(',').map((e) => e.trim())) {
        if (c.isNotEmpty && c != 'General' && c != 'General Practice') cats.add(c);
      }
    }
    final result = cats.toList()..sort();
    return result;
  }

  // ── Add / Edit dialog ─────────────────────────────────────────────────
  Future<void> _addOrEditMacro({Macro? macro}) async {
    final triggerCtrl      = TextEditingController(text: macro?.trigger ?? '');
    final contentCtrl      = TextEditingController(text: macro?.content ?? '');
    final aiInstrCtrl      = TextEditingController(text: macro?.aiInstruction ?? '');
    bool isAiMacro         = macro?.isAiMacro ?? false;
    String selectedCategory = macro?.category ?? 'General';

    // Build items from MedicalDepartments
    final deptItems = MedicalDepartments.all.map((d) =>
      DropdownMenuItem(value: d.nameEn, child: Row(
        children: [
          Icon(d.icon, size: 16, color: d.color),
          const SizedBox(width: 8),
          Text(d.nameEn, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ))
    ).toList()
    ..insert(0, const DropdownMenuItem(
      value: 'General',
      child: Row(children: [
        Icon(Icons.folder_outlined, size: 16, color: _kBlue),
        SizedBox(width: 8),
        Text('General', style: TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    ));

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.bolt, color: _kBlue, size: 22),
              const SizedBox(width: 8),
              Text(macro == null ? 'New Macro' : 'Edit Macro',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            ]),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Trigger + Category row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _dlgField(
                      controller: triggerCtrl,
                      label: 'Trigger Name',
                      hint: 'e.g., ⚡ SOAP',
                      icon: Icons.bolt,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: const Color(0xFF1E293B),
                      isExpanded: true,
                      decoration: _dlgDecoration(label: 'Category', icon: Icons.category_outlined),
                      items: deptItems,
                      onChanged: (v) => setDlg(() => selectedCategory = v!),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  // Content / Prompt
                  _dlgField(controller: contentCtrl, label: 'Content / Prompt', hint: 'FORMAT AS: ...', maxLines: 7),
                  const SizedBox(height: 12),

                  // AI Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile(
                      title: const Text('AI Smart Macro', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Use Gemini to fill this template',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: isAiMacro,
                      activeThumbColor: _kBlue,
                      onChanged: (v) => setDlg(() => isAiMacro = v),
                    ),
                  ),

                  if (isAiMacro) ...[
                    const SizedBox(height: 12),
                    _dlgField(
                      controller: aiInstrCtrl,
                      label: 'AI Instruction (Optional)',
                      hint: 'e.g., Keep medical terms, be concise',
                      icon: Icons.psychology_outlined,
                      maxLines: 2,
                    ),
                  ],

                  if (isSaving) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(color: _kBlue),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                onPressed: isSaving ? null : () async {
                  if (triggerCtrl.text.isEmpty || contentCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill Trigger and Content'), backgroundColor: Colors.orange));
                    return;
                  }
                  setDlg(() => isSaving = true);
                  try {
                    await Future.any([
                      macro == null
                        ? _macroService.addMacro(triggerCtrl.text, contentCtrl.text,
                            isAiMacro: isAiMacro, aiInstruction: aiInstrCtrl.text, category: selectedCategory)
                        : _macroService.updateMacro(macro.id, triggerCtrl.text, contentCtrl.text,
                            isAiMacro: isAiMacro, aiInstruction: aiInstrCtrl.text, category: selectedCategory),
                      Future.delayed(const Duration(seconds: 8))
                          .then((_) => throw TimeoutException('Timeout')),
                    ]);
                    if (mounted) Navigator.pop(ctx);
                    await _loadMacros();
                  } catch (e) {
                    setDlg(() => isSaving = false);
                    debugPrint('MacroDialog save error: $e');
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── dialog helpers ────────────────────────────────────────────────────
  InputDecoration _dlgDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      prefixIcon: icon != null ? Icon(icon, color: _kBlue, size: 18) : null,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _dlgField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: _kBlue,
      decoration: _dlgDecoration(label: label, icon: icon).copyWith(hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, _) {
        return Center(
          child: GestureDetector(
            onPanStart: (_) => windowManager.startDragging(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 900,
                height: 650,
                decoration: BoxDecoration(
                  color: currentTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: currentTheme.dividerColor),
                  boxShadow: currentTheme.shadows,
                ),
                child: Column(children: [
                  _buildHeader(context, currentTheme),
                  Expanded(child: Row(children: [
                    _buildSidebar(currentTheme),
                    Expanded(child: _buildMainPanel(currentTheme)),
                  ])),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        const Icon(Icons.bolt, color: _kBlue, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Macro Manager',
              style: TextStyle(color: theme.iconColor, fontWeight: FontWeight.w700, fontSize: 17)),
          Text('Manage your templates',
              style: TextStyle(color: theme.iconColor.withValues(alpha: 0.45), fontSize: 11)),
        ]),
        const Spacer(),
        // + New Macro
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Macro', style: TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () => _addOrEditMacro(),
        ),
        const SizedBox(width: 10),
        const UserProfileHeader(),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: theme.iconColor.withValues(alpha: 0.5), size: 20),
          onPressed: () => showDialog(context: context, builder: (_) => const MacroSettingsDialog()),
          tooltip: 'Settings',
        ),
        IconButton(
          icon: Icon(Icons.close, color: theme.iconColor.withValues(alpha: 0.5), size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ]),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────
  Widget _buildSidebar(AppTheme theme) {
    final deptId = _userDeptId;
    final userDept = deptId != null ? MedicalDepartments.getById(deptId) : null;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.micIdleBackground.withValues(alpha: 0.5),
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(children: [
            Icon(Icons.folder_outlined, color: theme.iconColor.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 8),
            Text('Categories', style: TextStyle(color: theme.iconColor,
                fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),

        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
          // Smart categories
          _sidebarItem('⭐', 'Favorites',  Icons.star_outline,  theme),
          _sidebarItem('📚', 'All Macros', Icons.layers_outlined, theme),
          _sidebarItem('📈', 'Most Used',  Icons.trending_up,    theme),

          // My Department shortcut
          if (userDept != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: theme.dividerColor, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('MY DEPARTMENT', style: TextStyle(
                  color: theme.iconColor.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1.0)),
            ),
            _sidebarDeptItem(userDept, theme),
          ],

          // All department categories found in macros
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: theme.dividerColor, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text('ALL CATEGORIES', style: TextStyle(
                color: theme.iconColor.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1.0)),
          ),
          _sidebarItem('🗂️', 'General', Icons.folder_outlined, theme),
          ..._departmentCategories.map((cat) {
            final dept = MedicalDepartments.all
                .where((d) => d.nameEn == cat)
                .firstOrNull;
            if (dept != null) return _sidebarDeptItem(dept, theme);
            return _sidebarItem('📄', cat, Icons.folder_outlined, theme);
          }),
        ])),
      ]),
    );
  }

  Widget _sidebarItem(String emoji, String name, IconData icon, AppTheme theme) {
    final isSelected = _selectedCategory == name;
    return InkWell(
      onTap: () {
        setState(() { _selectedCategory = name; _searchQuery = ''; _searchController.clear(); });
        _loadMacros();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kBlue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: TextStyle(
            color: isSelected ? _kBlue : theme.iconColor.withValues(alpha: 0.7),
            fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ))),
          if (isSelected) const Icon(Icons.check, size: 13, color: _kBlue),
        ]),
      ),
    );
  }

  Widget _sidebarDeptItem(MedicalDepartment dept, AppTheme theme) {
    final isSelected = _selectedCategory == dept.nameEn;
    return InkWell(
      onTap: () {
        setState(() { _selectedCategory = dept.nameEn; _searchQuery = ''; _searchController.clear(); });
        _loadMacros();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kBlue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(dept.icon, size: 15, color: isSelected ? _kBlue : dept.color.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Text(dept.nameEn, overflow: TextOverflow.ellipsis, style: TextStyle(
            color: isSelected ? _kBlue : theme.iconColor.withValues(alpha: 0.7),
            fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ))),
          if (isSelected) const Icon(Icons.check, size: 13, color: _kBlue),
        ]),
      ),
    );
  }

  // ── Main Panel ────────────────────────────────────────────────────────
  Widget _buildMainPanel(AppTheme theme) {
    return Container(
      color: theme.backgroundColor,
      child: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: theme.iconColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search macros...',
              hintStyle: TextStyle(color: theme.iconColor.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search, color: theme.iconColor.withValues(alpha: 0.4), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: theme.iconColor.withValues(alpha: 0.4), size: 18),
                      onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                  : null,
              filled: true,
              fillColor: theme.micIdleBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // List
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _filteredMacros.isEmpty
              ? _emptyState(theme)
              : _buildGroupedList(theme)),
      ]),
    );
  }

  Widget _emptyState(AppTheme theme) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off, color: theme.iconColor.withValues(alpha: 0.15), size: 56),
      const SizedBox(height: 12),
      Text('No macros found', style: TextStyle(color: theme.iconColor.withValues(alpha: 0.4), fontSize: 14)),
    ]));
  }

  // ── Grouped list — mirrors MacroManagerScreen ─────────────────────────
  Widget _buildGroupedList(AppTheme theme) {
    final groups = _grouped;
    final sortedKeys = groups.keys.toList()..sort((a, b) {
      if (a == 'Favorites') return -1;
      if (b == 'Favorites') return 1;
      return a.compareTo(b);
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: sortedKeys.length,
      itemBuilder: (_, i) {
        final cat = sortedKeys[i];
        final macros = groups[cat]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Section header — identical to MacroManagerScreen
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Row(children: [
              Icon(cat == 'Favorites' ? Icons.star : Icons.folder_open,
                  size: 14, color: _kBlue),
              const SizedBox(width: 6),
              Text(cat.toUpperCase(), style: const TextStyle(
                  color: _kBlue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: theme.dividerColor, height: 1)),
            ]),
          ),
          ...macros.map((m) => _buildMacroCard(m, theme)),
        ]);
      },
    );
  }

  // ── Macro card ────────────────────────────────────────────────────────
  Widget _buildMacroCard(Macro macro, AppTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.micIdleBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        // Favorite button
        Tooltip(
          message: macro.isFavorite ? 'Unfavorite' : 'Favorite',
          child: IconButton(
            icon: Icon(macro.isFavorite ? Icons.star : Icons.star_border,
                color: macro.isFavorite ? _kBlue : theme.iconColor.withValues(alpha: 0.35),
                size: 20),
            onPressed: () => _toggleFavorite(macro),
          ),
        ),

        // Macro info
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(macro.trigger,
                style: TextStyle(color: theme.iconColor, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(macro.content,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.iconColor.withValues(alpha: 0.5), fontSize: 12, height: 1.4)),
            const SizedBox(height: 6),
            // Category badge — blue styled
            _categoryBadge(macro.category),
          ]),
        )),

        // Actions
        Row(children: [
          // Copy & Inject
          Tooltip(message: 'Use & Inject',
            child: IconButton(
              icon: Icon(Icons.copy_outlined, color: theme.iconColor.withValues(alpha: 0.45), size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: macro.content));
                final keyboard = KeyboardService();
                await keyboard.pasteText(macro.content);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied & Injected ✓'), backgroundColor: _kBlue,
                        duration: Duration(seconds: 2)));
                }
              },
            ),
          ),
          // Edit
          Tooltip(message: 'Edit',
            child: IconButton(
              icon: Icon(Icons.edit_outlined, color: theme.iconColor.withValues(alpha: 0.45), size: 18),
              onPressed: () => _addOrEditMacro(macro: macro),
            ),
          ),
          // Delete
          Tooltip(message: 'Delete',
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.withValues(alpha: 0.6), size: 18),
              onPressed: () async {
                final ok = await _confirmDelete(macro.trigger);
                if (ok) { await _macroService.deleteMacro(macro.id); await _loadMacros(); }
              },
            ),
          ),
          const SizedBox(width: 4),
        ]),
      ]),
    );
  }

  Widget _categoryBadge(String category) {
    final cats = category.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final first = cats.isNotEmpty ? cats.first : 'General';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
      ),
      child: Text(first, style: const TextStyle(color: _kBlue, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<bool> _confirmDelete(String triggerName) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Macro?', style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '$triggerName'?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }
}
