import 'package:flutter/material.dart';

class DesktopBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;
  final List<BottomNavItem> items;

  const DesktopBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = currentIndex == index;
          final color = isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.5);
          
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap != null ? () {
                  debugPrint('Bottom nav tapped: $index');
                  onTap!(index);
                } : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: color, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const BottomNavItem({
    required this.icon,
    required this.label,
    this.onTap,
  });
}