import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MarkdownSyntaxTextEditingController extends TextEditingController {
  
  // Define styles
  final TextStyle normalStyle;
  final TextStyle boldStyle;
  final TextStyle headerStyle;
  final TextStyle subHeaderStyle;
  final TextStyle bulletStyle;
  final TextStyle mutedStyle;

  MarkdownSyntaxTextEditingController({
    String? text,
    TextStyle? style,
  }) : 
    normalStyle = style ?? const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
    boldStyle = (style ?? const TextStyle(fontSize: 16, height: 1.6)).copyWith(fontWeight: FontWeight.bold),
    headerStyle = (style ?? const TextStyle(fontSize: 16, height: 1.6)).copyWith(fontSize: 20, fontWeight: FontWeight.bold, height: 2.0),
    subHeaderStyle = (style ?? const TextStyle(fontSize: 16, height: 1.6)).copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.8),
    bulletStyle = (style ?? const TextStyle(fontSize: 16, height: 1.6)).copyWith(color: Colors.blueGrey[700]),
    mutedStyle = (style ?? const TextStyle(fontSize: 16, height: 1.6)).copyWith(color: Colors.grey[400]),
    super(text: text);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<TextSpan> children = [];
    final text = value.text;
    
    // Split into lines to handle headers and lists easily
    // Note: We need to preserve newlines for the text to remain editable correctly
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final lineWithNewline = isLastLine ? line : '$line\n';
      
      children.add(_parseLine(lineWithNewline));
    }

    return TextSpan(style: style, children: children);
  }

  TextSpan _parseLine(String line) {
    // 1. Headers
    if (line.trim().startsWith('# ')) {
        return TextSpan(children: [
           TextSpan(text: '# ', style: const TextStyle(color: Colors.transparent, fontSize: 0)), // Hide hash
           TextSpan(text: line.substring(2), style: headerStyle),
        ]);
    }
    if (line.trim().startsWith('## ')) {
        return TextSpan(children: [
           TextSpan(text: '## ', style: const TextStyle(color: Colors.transparent, fontSize: 0)), // Hide hashes
           TextSpan(text: line.substring(3), style: subHeaderStyle),
        ]);
    }
    
    // 2. Horizontal Rules
    if (line.trim() == '---' || line.trim() == '***') {
       return TextSpan(text: '___________________________________\n', style: mutedStyle.copyWith(color: Colors.grey[300]));
    }

    // 3. List Items
    if (line.trim().startsWith('* ')) {
       // Replace asterisk with bullet visually by hiding regex match? No, can't change text.
       // Style the asterisk to look like a bullet (large dot)
       return TextSpan(children: [
         TextSpan(text: '• ', style: bulletStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 20)), // Visual trick
         _parseInlineStyles(line.substring(2), style: normalStyle),
       ]);
    }
    
    // Handle 'Bold Headers' (lines starting and ending with **)
    if (line.trim().startsWith('**') && line.trim().endsWith('**') && line.length < 60) {
      // Remove the ** for the visual style
       final content = line.trim().substring(2, line.trim().length - 2);
       return TextSpan(children: [
          const TextSpan(text: '**', style: TextStyle(color: Colors.transparent, fontSize: 0)),
          TextSpan(text: content, style: subHeaderStyle), // Style as subheader
          const TextSpan(text: '**\n', style: TextStyle(color: Colors.transparent, fontSize: 0)),
       ]);
    }

    // 4. Normal Line (with inline bold parsing)
    return _parseInlineStyles(line, style: normalStyle);
  }

  TextSpan _parseInlineStyles(String text, {required TextStyle style}) {
    final List<TextSpan> spans = [];
    final regex = RegExp(r'(\*\*)(.*?)(\*\*)'); // Group 1: **, Group 2: content, Group 3: **
    
    int currentIndex = 0;
    
    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start), style: style));
      }
      
      // Group 1: Marker ** (Hide it)
      spans.add(const TextSpan(text: '**', style: TextStyle(color: Colors.transparent, fontSize: 0.1)));
      
      // Group 2: Content (Bold it)
      spans.add(TextSpan(
        text: match.group(2), 
        style: style.copyWith(fontWeight: FontWeight.bold, color: Colors.indigo[900])
      ));
      
      // Group 3: Marker ** (Hide it)
      spans.add(const TextSpan(text: '**', style: TextStyle(color: Colors.transparent, fontSize: 0.1)));
      
      currentIndex = match.end;
    }
    
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex), style: style));
    }
    
    return TextSpan(children: spans);
  }
}
