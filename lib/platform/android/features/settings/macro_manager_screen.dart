import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/macro_service.dart';
import '../../../../core/entities/macro.dart';
import '../../../../../core/medical_departments.dart';
import '../../../../../core/services/department_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'macro_editor_screen.dart';

class MacroManagerScreen extends StatefulWidget {
  const MacroManagerScreen({super.key});

  @override
  State<MacroManagerScreen> createState() => _MacroManagerScreenState();
}

class _MacroManagerScreenState extends State<MacroManagerScreen> {
  final MacroService _service = MacroService();
  List<Macro> _macros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMacros();
  }

  // Helper to parse CSV categories
  List<String> _getCategories(Macro m) {
    if (m.category.isEmpty) return [];
    return m.category
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _loadMacros() async {
    setState(() => _isLoading = true);
    final allData = await _service.getMacros();

    final prefs = await SharedPreferences.getInstance();
    final deptId = DepartmentService().value ?? prefs.getString('specialty');
    final deptNameEn = deptId != null
        ? MedicalDepartments.getById(deptId)?.nameEn
        : 'General Practice';

    final filteredData = allData.where((m) {
      final cats = _getCategories(m);
      if (cats.isEmpty) return true; // uncategorized are general?
      if (cats.contains('General') || cats.contains('General Practice'))
        return true;
      if (deptId != null && cats.contains(deptId)) return true;
      if (deptNameEn != null && cats.contains(deptNameEn))
        return true; // legacy support
      return false;
    }).toList();

    setState(() {
      _macros = filteredData;
      _isLoading = false;
    });
  }

  Future<void> _navigateToEditor([Macro? macro]) async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MacroEditorScreen(macro: macro)));

    // If result is true, it means we saved something, so refresh.
    if (result == true) {
      _loadMacros();
    }
  }

  Future<void> _toggleFavorite(Macro macro) async {
    macro.isFavorite = !macro.isFavorite;
    await _service.updateMacro(macro.id, macro.trigger, macro.content,
        isAiMacro: macro.isAiMacro,
        aiInstruction: macro.aiInstruction,
        category: macro.category);
    _loadMacros();
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MobileAppTheme.surface,
        title:
            const Text("Reset Macros?", style: TextStyle(color: Colors.white)),
        content: const Text(
            "This will delete ALL current macros and restore the new KSA templates.\n\nAre you sure?",
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
      await _service.resetToDefaults();
      _loadMacros();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Restored KSA Default Macros 🇸🇦 ✅"),
            backgroundColor: MobileAppTheme.successGreen));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Group Macros
    final Map<String, List<Macro>> grouped = {};

    // Always add Favorites section first if there are any
    final favorites = _macros.where((m) => m.isFavorite == true).toList();
    if (favorites.isNotEmpty) {
      grouped['Most Used (Favorites)'] = favorites;
    }

    // Group the rest by department/category
    for (var m in _macros) {
      if (m.isFavorite == true) continue;

      final cats = _getCategories(m);
      if (cats.isEmpty) {
        if (!grouped.containsKey('General')) grouped['General'] = [];
        grouped['General']!.add(m);
        continue;
      }

      // We group them under the first category they have for display purposes
      // Wait, if they are filtered to the user's dept, we can just put them under "Templates"
      String displayCat = 'Templates';
      if (cats.isNotEmpty) {
        // Try to show a nice name
        final firstCat = cats.first;
        final dept = MedicalDepartments.getById(firstCat);
        displayCat = dept != null ? dept.nameEn : firstCat;
      }

      if (!grouped.containsKey(displayCat)) {
        grouped[displayCat] = [];
      }
      grouped[displayCat]!.add(m);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Most Used (Favorites)') return -1;
        if (b == 'Most Used (Favorites)') return 1;
        return a.compareTo(b);
      });

    return Scaffold(
      backgroundColor: MobileAppTheme.background,
      appBar: AppBar(
        title: Text("Macro Manager",
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: MobileAppTheme.background,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white70),
            tooltip: 'Reset to Defaults',
            onPressed: _confirmReset,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditor(),
        backgroundColor: MobileAppTheme.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _macros.isEmpty
              ? Center(
                  child: Text("No macros yet. Tap + to add one.",
                      style: GoogleFonts.inter(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, sectionIndex) {
                    final category = sortedKeys[sectionIndex];
                    final macrosInSection = grouped[category]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Row(
                            children: [
                              Icon(
                                  category == 'Most Used (Favorites)'
                                      ? Icons.star
                                      : Icons.folder_open,
                                  size: 16,
                                  color: MobileAppTheme.accent),
                              const SizedBox(width: 8),
                              Text(category.toUpperCase(),
                                  style: GoogleFonts.inter(
                                      color: MobileAppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0)),
                              const SizedBox(width: 8),
                              Expanded(child: Divider(color: Colors.white12)),
                            ],
                          ),
                        ),

                        // Macros in this section
                        ...macrosInSection.map((m) {
                          return Dismissible(
                            key: Key("${m.id}_$category"),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: MobileAppTheme.recordRed,
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                        backgroundColor: MobileAppTheme.surface,
                                        title: const Text("Delete Macro?",
                                            style:
                                                TextStyle(color: Colors.white)),
                                        content: Text(
                                            "Are you sure you want to delete '${m.trigger}'?",
                                            style: TextStyle(
                                                color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text("Cancel")),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text("Delete",
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ));
                            },
                            onDismissed: (_) async {
                              await _service.deleteMacro(m.id);
                              _loadMacros();
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              color: MobileAppTheme.surface,
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                      m.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: m.isFavorite
                                          ? Colors.amber
                                          : Colors.white30),
                                  onPressed: () async {
                                    setState(() {
                                      m.isFavorite = !m.isFavorite;
                                    });
                                    await _service.toggleFavorite(m.id);
                                    _loadMacros();
                                  },
                                ),
                                title: Text(m.trigger,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(m.content.replaceAll('\n', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.white54)),
                                trailing: const Icon(Icons.edit,
                                    color: Colors.white30, size: 20),
                                onTap: () => _navigateToEditor(m),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
    );
  }
}
