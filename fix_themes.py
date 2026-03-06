import os
import glob
import re

directory = r'e:\d\DOCVOICE-ORG\docvoice\lib\web_extension\screens'
files = glob.glob(os.path.join(directory, '*.dart'))

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replacements for hardcoded theme references
    content = content.replace('AppTheme.background', 'Theme.of(context).scaffoldBackgroundColor')
    content = content.replace('AppTheme.surface', 'Theme.of(context).colorScheme.surface')
    content = content.replace('AppTheme.primary', 'Theme.of(context).colorScheme.primary')
    content = content.replace('AppTheme.accent', 'Theme.of(context).colorScheme.secondary')
    content = content.replace('AppTheme.recordRed', 'Theme.of(context).colorScheme.error')
    content = content.replace('AppTheme.successGreen', 'Colors.green')
    content = content.replace('AppTheme.success', 'Colors.green')
    content = content.replace('AppTheme.draftYellow', 'Colors.orange')
    content = content.replace('AppTheme.draft', 'Colors.orange')

    # Remove the import of mobile_app/core/theme.dart
    content = re.sub(r'import\s+\'(\.\./)+mobile_app/core/theme\.dart\';', '', content)

    # Some hardcoded text colors
    content = content.replace('color: Colors.white70', 'color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)')
    content = content.replace('color: Colors.white54', 'color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.54)')
    content = content.replace('color: Colors.white30', 'color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3)')
    # Be careful with replacing 'color: Colors.white', it might break things, but we'll try to replace obvious ones
    content = content.replace('color: Colors.white)', 'color: Theme.of(context).textTheme.bodyLarge?.color)')
    content = content.replace('color: Colors.white,', 'color: Theme.of(context).textTheme.bodyLarge?.color,')

    # Background of bottom nav bar and cards hardcoded to 1E1E1E or similar
    content = content.replace('const Color(0xFF1E1E1E)', 'Theme.of(context).colorScheme.surface')
    content = content.replace('Color(0xFF1E1E1E)', 'Theme.of(context).colorScheme.surface')
    content = content.replace('Colors.grey[900]', 'Theme.of(context).colorScheme.surface')
    content = content.replace('Colors.grey.shade900', 'Theme.of(context).colorScheme.surface')

    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('Done fixing themes!')
