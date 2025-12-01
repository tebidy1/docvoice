import 'package:flutter/material.dart';
import '../models/macro.dart';
import '../services/macro_service.dart';

class MacroExplorerDialog extends StatefulWidget {
  const MacroExplorerDialog({super.key});

  @override
  State<MacroExplorerDialog> createState() => _MacroExplorerDialogState();
}

class _MacroExplorerDialogState extends State<MacroExplorerDialog> {
  final _macroService = MacroService();
  String _selectedCategory = 'Favorites';
  Macro? _previewMacro;
  List<Macro> _macros = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMacros();
  }

  Future<void> _loadMacros() async {
    setState(() => _isLoading = true);
    
    List<Macro> macros;
    if (_selectedCategory == 'Favorites') {
      macros = await _macroService.getFavorites();
    } else if (_selectedCategory == 'Most Used') {
      macros = await _macroService.getMostUsed(limit: 20);
    } else {
      macros = await _macroService.getMacrosByCategory(_selectedCategory);
    }
    
    setState(() {
      _macros = macros;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        height: 650,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A2A2A),
              const Color(0xFF1A1A1A),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            // Left Sidebar - Categories (25%)
            _buildCategoriesSidebar(),
            
            // Right Grid - Macros (75%)
            Expanded(
              child: Stack(
                children: [
                  _buildMacroGrid(),
                  
                  // Preview Drawer
                  if (_previewMacro != null)
                    _buildPreviewDrawer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSidebar() {
    return Container(
      width: 225,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.folder, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Categories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Categories List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildCategoryItem('⭐', 'Favorites', Colors.amber),
                _buildCategoryItem('📈', 'Most Used', Colors.green),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white10),
                ),
                
                _buildCategoryItem('🗂️', 'General', Colors.grey),
                _buildCategoryItem('❤️', 'Cardiology', Colors.red),
                _buildCategoryItem('🫁', 'Pulmonology', Colors.cyan),
                _buildCategoryItem('👶', 'Pediatrics', Colors.pink),
                _buildCategoryItem('💊', 'Prescriptions', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String emoji, String name, Color color) {
    final isSelected = _selectedCategory == name;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = name;
            _previewMacro = null;
          });
          _loadMacros();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }
    
    if (_macros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.white.withOpacity(0.3), size: 60),
            const SizedBox(height: 16),
            Text(
              'No templates in this category',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _macros.length,
      itemBuilder: (context, index) {
        final macro = _macros[index];
        return _buildMacroCard(macro);
      },
    );
  }

  Widget _buildMacroCard(Macro macro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF333333),
            const Color(0xFF252525),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Macro Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (macro.isFavorite)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.star, color: Colors.amber, size: 16),
                      ),
                    Expanded(
                      child: Text(
                        macro.trigger,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  macro.content.substring(0, macro.content.length > 80 ? 80 : macro.content.length) + '...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Actions
          Row(
            children: [
              // Preview Button
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                onPressed: () {
                  setState(() {
                    _previewMacro = macro;
                  });
                },
                tooltip: 'Preview',
              ),
              
              // Use Button
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Use'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.of(context).pop(macro);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewDrawer() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 350,
      child: Material(
        elevation: 10,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF141414),
              ],
            ),
            border: Border(
              left: BorderSide(color: Colors.blue.withOpacity(0.5), width: 2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        setState(() => _previewMacro = null);
                      },
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _previewMacro!.trigger,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _previewMacro!.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Apply This Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(_previewMacro);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
