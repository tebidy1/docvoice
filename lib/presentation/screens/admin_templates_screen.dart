import 'package:flutter/material.dart';
import '../../mobile_app/services/macro_service.dart';
import '../../core/medical_departments.dart';

class AdminTemplatesScreen extends StatefulWidget {
  const AdminTemplatesScreen({super.key});

  @override
  State<AdminTemplatesScreen> createState() => _AdminTemplatesScreenState();
}

class _AdminTemplatesScreenState extends State<AdminTemplatesScreen> {
  final MacroService _macroService = MacroService();
  List<MacroModel> _allMacros = [];
  bool _isLoading = true;
  MedicalDepartment? _selectedDepartment;

  // For global search in the whole database dialog
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final macros = await _macroService.getMacros();
      // Deduplicate by unique id/trigger to avoid visual duplicates from API cache
      final seen = <String>{};
      final unique = macros.where((m) {
        final key = '${m.id}_${m.trigger}';
        return seen.add(key);
      }).toList();
      if (mounted) {
        setState(() {
          _allMacros = unique;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load templates: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to parse categories CSV
  List<String> _getCategories(MacroModel macro) {
    if (macro.category.isEmpty) return [];
    return macro.category
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _isAssignedToSelected(MacroModel macro) {
    if (_selectedDepartment == null) return false;
    final cats = _getCategories(macro);
    // If it's literally assigned to this department ID
    if (cats.contains(_selectedDepartment!.id)) return true;
    // Check if it's assigned to the English name as a fallback (legacy mapping)
    if (cats.contains(_selectedDepartment!.nameEn)) return true;
    return false;
  }

  Future<void> _toggleAssignment(MacroModel macro, bool assign) async {
    if (_selectedDepartment == null) return;

    // Optimistic UI update
    setState(() {
      final cats = _getCategories(macro);
      if (assign) {
        if (!cats.contains(_selectedDepartment!.id)) {
          cats.add(_selectedDepartment!.id);
        }
      } else {
        cats.remove(_selectedDepartment!.id);
        cats.remove(
            _selectedDepartment!.nameEn); // remove legacy mapping if exists
      }
      macro.category = cats.join(',');
    });

    try {
      await _macroService.updateMacro(macro);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save assignment: $e'),
              backgroundColor: Colors.red),
        );
        _loadData(); // revert
      }
    }
  }

  void _openManageAllMacros() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ManageAllMacrosDialog(
        macros: _allMacros,
        onMacroDeleted: (macro) async {
          setState(() => _isLoading = true);
          Navigator.pop(
              context); // Close dialog briefly to reload, or update in place
          try {
            if (macro.id != null) {
              await _macroService.deleteMacro(macro.id!);
              await _loadData();
              if (mounted) _openManageAllMacros(); // Reopen
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to delete: $e'),
                  backgroundColor: Colors.red));
              setState(() => _isLoading = false);
            }
          }
        },
        onMacroEdited: (macro) async {
          Navigator.pop(context); // Close master dialog
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _TemplateEditDialog(macro: macro),
          );
          if (result == true) {
            await _loadData();
          }
          if (mounted) _openManageAllMacros(); // Reopen master list
        },
        onMacroAdded: () async {
          Navigator.pop(context); // Close master dialog
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const _TemplateEditDialog(macro: null),
          );
          if (result == true) {
            await _loadData();
          }
          if (mounted) _openManageAllMacros(); // Reopen master list
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<MacroModel> availableMacros = [];
    List<MacroModel> assignedMacros = [];

    if (_selectedDepartment != null) {
      for (var m in _allMacros) {
        if (_isAssignedToSelected(m)) {
          assignedMacros.add(m);
        } else {
          availableMacros.add(m);
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Department Template Mapping',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('Select a department, then assign/remove templates',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _openManageAllMacros,
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 18),
              label: const Text('Templates Library',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT PANEL: Departments
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(right: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFF0F172A),
                  child: const Text('DEPARTMENTS',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.5)),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: MedicalDepartments.all.length,
                          itemBuilder: (context, index) {
                            final dept = MedicalDepartments.all[index];
                            final isSelected =
                                _selectedDepartment?.id == dept.id;
                            final count = _allMacros.where((m) {
                              final cats = _getCategories(m);
                              return cats.contains(dept.id) ||
                                  cats.contains(dept.nameEn);
                            }).length;

                            return ListTile(
                              dense: true,
                              leading: Icon(dept.icon,
                                  color: isSelected
                                      ? Colors.blue[300]
                                      : Colors.white38,
                                  size: 18),
                              title: Text(dept.nameEn,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  )),
                              trailing: count > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.white12,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('$count',
                                          style: TextStyle(
                                              color: isSelected
                                                  ? Colors.blue[300]
                                                  : Colors.grey,
                                              fontSize: 11)),
                                    )
                                  : null,
                              selected: isSelected,
                              selectedTileColor: Colors.blue.withOpacity(0.1),
                              onTap: () =>
                                  setState(() => _selectedDepartment = dept),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // RIGHT PANEL: Columns
          Expanded(
            child: _selectedDepartment == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                            'Select a department to manage its templates',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          Expanded(
                            child: _buildMacroColumn(
                              title: 'AVAILABLE TEMPLATES',
                              macros: availableMacros,
                              isAssigned: false,
                              onTap: (m) => _toggleAssignment(m, true),
                            ),
                          ),
                          const VerticalDivider(
                              color: Colors.white12, width: 1),
                          Expanded(
                            child: _buildMacroColumn(
                              title:
                                  'ASSIGNED TO ${_selectedDepartment!.nameEn.toUpperCase()}',
                              macros: assignedMacros,
                              isAssigned: true,
                              onTap: (m) => _toggleAssignment(m, false),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroColumn({
    required String title,
    required List<MacroModel> macros,
    required bool isAssigned,
    required Function(MacroModel) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: isAssigned ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      color: isAssigned ? Colors.blue[300] : Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              Text('${macros.length}',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: macros.isEmpty
              ? Center(
                  child: Text(
                      isAssigned
                          ? 'No templates assigned'
                          : 'No available templates',
                      style: const TextStyle(color: Colors.white24)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: macros.length,
                  itemBuilder: (context, index) {
                    final macro = macros[index];
                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: isAssigned
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => onTap(macro),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                  isAssigned
                                      ? Icons.remove_circle_outline
                                      : Icons.add_circle_outline,
                                  color: isAssigned
                                      ? Colors.red[300]
                                      : Colors.green[300],
                                  size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(macro.trigger,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      macro.content,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// =========================================================================
// DIALOGS FOR GLOBAL MACRO MANAGEMENT
// =========================================================================

class _ManageAllMacrosDialog extends StatefulWidget {
  final List<MacroModel> macros;
  final Function(MacroModel) onMacroDeleted;
  final Function(MacroModel) onMacroEdited;
  final VoidCallback onMacroAdded;

  const _ManageAllMacrosDialog({
    required this.macros,
    required this.onMacroDeleted,
    required this.onMacroEdited,
    required this.onMacroAdded,
  });

  @override
  State<_ManageAllMacrosDialog> createState() => _ManageAllMacrosDialogState();
}

class _ManageAllMacrosDialogState extends State<_ManageAllMacrosDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.macros
        .where((m) =>
            m.trigger.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            m.content.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Global Templates Database',
              style: TextStyle(color: Colors.white)),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: widget.onMacroAdded,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('New Template',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No templates found',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final macro = filtered[index];
                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(macro.trigger,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              macro.content.replaceAll('\n', ' '),
                              style: TextStyle(color: Colors.grey[400]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => widget.onMacroEdited(macro),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _confirmDelete(macro),
                                  tooltip: 'Delete',
                                ),
                              ],
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
  }

  void _confirmDelete(MacroModel macro) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Template',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete "${macro.trigger}"? This will remove it from all assigned departments.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.onMacroDeleted(macro);
    }
  }
}

// =========================================================================
// CREATE / EDIT TEMPLATE DIALOG
// =========================================================================

class _TemplateEditDialog extends StatefulWidget {
  final MacroModel? macro;
  const _TemplateEditDialog({this.macro});

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.macro?.trigger ?? '');
    _contentController =
        TextEditingController(text: widget.macro?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final macroService = MacroService();

    try {
      final macro = MacroModel(
        id: widget.macro?.id,
        trigger: _titleController.text.trim(),
        content: _contentController.text.trim(),
        // Keep existing category (the CV string) if editing, otherwise empty string means assigned to no department initially
        category: widget.macro?.category ?? '',
        isAiMacro: true,
        isFavorite: widget.macro?.isFavorite ?? false,
        usageCount: widget.macro?.usageCount ?? 0,
      );

      if (widget.macro == null) {
        await macroService
            .addMacro(macro); // Let service generate ID or hit API
      } else {
        await macroService.updateMacro(macro);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Template saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving template: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
          widget.macro == null ? 'Create New Template' : 'Edit Template',
          style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Title / Shortcut',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: To assign this template to a department, save it first, then use the template mapper panel.',
                style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Template Content',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF0F172A),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
