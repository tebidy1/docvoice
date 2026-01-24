import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/macro_service.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/window_manager_helper.dart';
import '../services/keyboard_service.dart';
import '../models/macro.dart';
import '../models/app_theme.dart';
import '../services/theme_service.dart';
import 'dart:async';
import 'macro_settings_dialog.dart';
import '../widgets/user_profile_header.dart';

class MacroManagerDialog extends StatefulWidget {
  const MacroManagerDialog({super.key});

  @override
  State<MacroManagerDialog> createState() => _MacroManagerDialogState();
}

class _MacroManagerDialogState extends State<MacroManagerDialog> {
  final MacroService _macroService = MacroService();
  List<Macro> _macros = [];
  bool _isLoading = true;
  String _selectedCategory = 'All Macros';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WindowManagerHelper.setOpacity(1.0); // Enforce full visibility
    WindowManagerHelper.setTransparencyLocked(true); // Lock opacity
    _resizeWindow(true);
    _loadMacros();
  }

  @override
  void dispose() {
    WindowManagerHelper.setTransparencyLocked(false); // Unlock opacity
    _resizeWindow(false);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resizeWindow(bool expanded) async {
    if (expanded) {
      await windowManager.setSize(const Size(900, 650));
      await windowManager.center();
    } else {
      await windowManager.setSize(const Size(300, 60));
    }
  }

  Future<void> _loadMacros() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      print("MacroManager: Initializing service...");
      await _macroService.init();
      
      List<Macro> macros;
      print("MacroManager: Fetching macros for category '$_selectedCategory'...");
      
      if (_selectedCategory == 'Favorites') {
        macros = await _macroService.getFavorites();
      } else if (_selectedCategory == 'Most Used') {
        macros = await _macroService.getMostUsed(limit: 50);
      } else if (_selectedCategory == 'All Macros') {
        macros = await _macroService.getAllMacros();
      } else {
        macros = await _macroService.getMacrosByCategory(_selectedCategory);
      }
      
      if (macros.isEmpty && _selectedCategory == 'Favorites') {
        print("MacroManager: Favorites empty, switching to All Macros...");
        _selectedCategory = 'All Macros';
        macros = await _macroService.getAllMacros();
      }
      
      print("MacroManager: Fetched ${macros.length} macros");
      
      if (mounted) {
        setState(() {
          _macros = macros;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("MacroManager: Error loading macros: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _macros = []; // Clear macros on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading macros: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadMacros,
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Macro macro) async {
    await _macroService.toggleFavorite(macro.id);
    await _loadMacros();
  }

  Future<void> _addOrEditMacro({Macro? macro}) async {
    final triggerController = TextEditingController(text: macro?.trigger ?? "");
    final contentController = TextEditingController(text: macro?.content ?? "");
    final aiInstructionController = TextEditingController(text: macro?.aiInstruction ?? "");
    bool isAiMacro = macro?.isAiMacro ?? false;
    String selectedCategory = macro?.category ?? 'General';

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // Semi-transparent dark overlay
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
            backgroundColor: const Color(0xFF1E293B), // Slate 800 - darker, more visible
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              macro == null ? "➕ New Macro" : "✏️ Edit Macro", 
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: triggerController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    cursorColor: Colors.amber,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "Trigger Phrase (e.g. 'Normal Cardio')",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return const [
                        Text('🗂️ General', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('❤️ Cardiology', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('🫁 Pulmonology', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('👶 Pediatrics', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('💊 Prescriptions', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('🧠 Neurology', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text('🍽️ Gastroenterology', style: TextStyle(color: Colors.black87, fontSize: 14)),
                      ];
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "Category",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.category, color: Colors.blue),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'General', child: Text('🗂️ General', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Cardiology', child: Text('❤️ Cardiology', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Pulmonology', child: Text('🫁 Pulmonology', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Pediatrics', child: Text('👶 Pediatrics', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Prescriptions', child: Text('💊 Prescriptions', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Neurology', child: Text('🧠 Neurology', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Gastroenterology', child: Text('🍽️ Gastroenterology', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (value) {
                      setState(() => selectedCategory = value!);
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: contentController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    cursorColor: Colors.amber,
                    maxLines: 5,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: "Content to Insert",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // AI Macro Switch
                  SwitchListTile(
                    title: const Text("AI Smart Macro", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("Use Gemini to fill this template intelligently", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    value: isAiMacro,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) {
                      setState(() => isAiMacro = val);
                    },
                  ),
                  
                  if (isAiMacro) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: aiInstructionController,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      cursorColor: Colors.purpleAccent,
                      maxLines: 2,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: "AI Instruction (Optional)",
                        hintText: "e.g. Summarize symptoms and keep medical terms",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        labelStyle: const TextStyle(color: Colors.purpleAccent),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.purpleAccent),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.purpleAccent, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.psychology, color: Colors.purpleAccent),
                      ),
                    ),
                  ],
                  if (isSaving) ...[
                    const SizedBox(height: 20),
                    const Text(
                      "Saving macro...",
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSaving ? null : () async {
                  if (triggerController.text.isNotEmpty && contentController.text.isNotEmpty) {
                    setState(() => isSaving = true);
                    try {
                      await Future.any([
                        (macro == null) 
                            ? _macroService.addMacro(
                                triggerController.text, 
                                contentController.text,
                                isAiMacro: isAiMacro,
                                aiInstruction: aiInstructionController.text,
                                category: selectedCategory,
                              )
                            : _macroService.updateMacro(
                                macro.id, 
                                triggerController.text, 
                                contentController.text,
                                isAiMacro: isAiMacro,
                                aiInstruction: aiInstructionController.text,
                                category: selectedCategory,
                              ),
                        Future.delayed(const Duration(seconds: 5)).then((_) => throw TimeoutException("Database operation timed out")),
                      ]);

                      if (mounted) Navigator.pop(context);
                      await _loadMacros();
                    } catch (e) {
                      print("MacroDialog: Error saving macro: $e");
                      setState(() => isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.orange),
                    );
                  }
                },
                child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text("Save"),
              ),
            ],
          );
        }
      );
    },
  );
  }

  List<Macro> get _filteredMacros {
    if (_searchQuery.isEmpty) return _macros;
    
    return _macros.where((macro) {
      return macro.trigger.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             macro.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService(),
      builder: (context, currentTheme, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Center(
          child: GestureDetector(
            onPanStart: (details) => windowManager.startDragging(),
            child: Material(
            color: Colors.transparent,
            child: Container(
              width: 900,
              height: 650,
              decoration: BoxDecoration(
                color: currentTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: currentTheme.dividerColor, width: 1),
                boxShadow: currentTheme.shadows,
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: currentTheme.backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.surface),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flash_on, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    // Title column takes remaining space
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Macro Manager',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Manage your templates',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Macro'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.secondary, // Emerald Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _addOrEditMacro(),
                    ),
                    const SizedBox(width: 10),
                    const UserProfileHeader(),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: Colors.grey[400]),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => const MacroSettingsDialog(),
                        );
                      },
                      tooltip: 'Settings',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[400]),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              
              // Two-Pane Layout
              Expanded(
                child: Row(
                  children: [
                    // Left Sidebar - Categories
                    _buildCategoriesSidebar(currentTheme),
                    
                    // Right Panel - Macros
                    Expanded(child: _buildMacrosPanel(currentTheme)),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildCategoriesSidebar(AppTheme theme) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.micIdleBackground.withOpacity(0.5), // Sidebar background matches idle mic bg
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: theme.iconColor.withOpacity(0.7), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Categories',
                  style: TextStyle(
                    color: theme.iconColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildCategoryItem('⭐', 'Favorites', Colors.amber, theme),
                _buildCategoryItem('📚', 'All Macros', Colors.blue, theme),
                _buildCategoryItem('📈', 'Most Used', Colors.green, theme),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: theme.dividerColor),
                ),
                
                _buildCategoryItem('🗂️', 'General', Colors.grey, theme),
                _buildCategoryItem('❤️', 'Cardiology', Colors.red, theme),
                _buildCategoryItem('🫁', 'Pulmonology', Colors.cyan, theme),
                _buildCategoryItem('👶', 'Pediatrics', Colors.pink, theme),
                _buildCategoryItem('💊', 'Prescriptions', Colors.orange, theme),
                _buildCategoryItem('🧠', 'Neurology', Colors.purple, theme),
                _buildCategoryItem('🍽️', 'Gastroenterology', Colors.brown, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String emoji, String name, Color color, AppTheme theme) {
    final isSelected = _selectedCategory == name;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = name;
            _searchQuery = "";
            _searchController.clear();
          });
          _loadMacros();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.transparent, // Amber selection
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.amber : theme.iconColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 14, color: Colors.amber),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacrosPanel(AppTheme theme) {
    return Container(
      color: theme.backgroundColor,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: theme.iconColor),
              decoration: InputDecoration(
                hintText: 'Search macros...',
                hintStyle: TextStyle(color: theme.iconColor.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: theme.iconColor.withOpacity(0.5)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.micIdleBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          
          // Macro List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _filteredMacros.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: theme.iconColor.withOpacity(0.2), size: 60),
                            const SizedBox(height: 16),
                            Text(
                              'No macros found',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _filteredMacros.length,
                        itemBuilder: (context, index) {
                          final macro = _filteredMacros[index];
                          return _buildMacroCard(macro, theme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(Macro macro, AppTheme theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.micIdleBackground, // Card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.transparent, // Clean look
        ),
      ),
      child: Row(
        children: [
          // Favorite Button
          IconButton(
            icon: Icon(
              macro.isFavorite ? Icons.star : Icons.star_border,
              color: macro.isFavorite ? Colors.amber : theme.iconColor.withOpacity(0.6),
            ),
            onPressed: () => _toggleFavorite(macro),
            tooltip: macro.isFavorite ? 'Unfavorite' : 'Favorite',
          ),
          
          // Macro Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  macro.trigger,
                  style: TextStyle(
                    color: theme.iconColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  macro.content.length > 100 ? macro.content.substring(0, 100) + '...' : macro.content,
                  style: TextStyle(color: theme.iconColor.withOpacity(0.5), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    macro.category,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          Row(
            children: [
              // Copy Button
              IconButton(
                icon: Icon(Icons.copy_outlined, color: Colors.grey[500], size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: macro.content));
                  Navigator.of(context).pop();
                  await Future.delayed(const Duration(milliseconds: 200));
                  await windowManager.hide();
                  await Future.delayed(const Duration(milliseconds: 100));
                  final keyboard = KeyboardService();
                  await keyboard.pasteText(macro.content);
                  await windowManager.show();
                },
                tooltip: 'Use',
              ),
              
              // Edit Button
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.grey[500], size: 20),
                onPressed: () => _addOrEditMacro(macro: macro),
                tooltip: 'Edit',
              ),
              
              // Delete Button
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
                onPressed: () async {
                  await _macroService.deleteMacro(macro.id);
                  await _loadMacros();
                },
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
