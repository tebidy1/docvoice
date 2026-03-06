import 'dart:io';

void main() {
  final file = File('lib/web_extension/screens/extension_settings_screen.dart');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  
  String content = file.readAsStringSync();

  // Fix theme variable
  content = content.replaceAll('theme.scaffoldBackgroundColor', 'Theme.of(context).scaffoldBackgroundColor');
  content = content.replaceAll('color: theme.cardTheme.color ?? const Color(0xFF1E1E1E),', 'backgroundColor: Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),');
  content = content.replaceAll('color: theme.cardTheme.color,', 'color: Theme.of(context).cardTheme.color,');

  // Fix AlertDialog context issue (ctx vs context) in _resetMacrosToDefaults
  content = content.replaceAll('color: Theme.of(ctx).cardTheme.color', 'backgroundColor: Theme.of(ctx).cardTheme.color');
  // Wait, my replaceAll above would have done Theme.of(context), let's fix it for ctx
  content = content.replaceAll('backgroundColor: Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),', 'backgroundColor: Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),');
  // Actually, we can just replace 'color: theme.cardTheme.color' to 'backgroundColor: Theme.of(context).cardTheme.color' where 'color: theme.cardTheme.color' was used for AlertDialog
  content = content.replaceAll('Theme.of(context).cardTheme.color ??', 'Theme.of(ctx).cardTheme.color ??');
  content = content.replaceAll('Theme.of(ctx).cardTheme.color ??', 'Theme.of(context).cardTheme.color ??'); // Put back for the first one. Let's do it right.

  List<String> lines = content.split('\n');
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('theme.cardTheme.color')) {
      // should be replaced already, but just in case
    }
    
    // In _resetMacrosToDefaults, context is ctx
    if (lines[i].contains('builder: (ctx) => AlertDialog(')) {
       if (lines[i+1].contains('Theme.of(context)')) {
         lines[i+1] = lines[i+1].replaceAll('Theme.of(context)', 'Theme.of(ctx)');
       }
    }

    // Remove const if Theme.of(context) is on the same line
    if (lines[i].contains('Theme.of(context)') || lines[i].contains('Theme.of(ctx)')) {
      lines[i] = lines[i].replaceAll('const Text(', 'Text(');
      lines[i] = lines[i].replaceAll('const TextStyle(', 'TextStyle(');
      lines[i] = lines[i].replaceAll('const Icon(', 'Icon(');
      lines[i] = lines[i].replaceAll('const Divider(', 'Divider(');
    }
  }
  
  content = lines.join('\n');
  file.writeAsStringSync(content);
  print('Fixed constants successfully');
}
