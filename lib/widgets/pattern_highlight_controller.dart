import 'package:flutter/material.dart';

/// A custom TextEditingController that highlights specific regex patterns.
/// Used to visually distinguish "Not Reported" or placeholder text.
class PatternHighlightController extends TextEditingController {
  final Map<RegExp, TextStyle> patternStyles;

  PatternHighlightController({
    String? text,
    required this.patternStyles,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final String text = value.text;
    
    // Valid styles to use
    final TextStyle parentStyle = style ?? const TextStyle();
    
    final List<Match> allMatches = [];
    for (var entry in patternStyles.entries) {
      allMatches.addAll(entry.key.allMatches(text));
    }
    
    // Sort matches by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    int currentIndex = 0;
    
    for (final match in allMatches) {
      // 1. Add non-matching text before this match
      if (match.start > currentIndex) {
        children.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: parentStyle,
        ));
      }
      
      // 2. Add matching text with specific style
      // Find which pattern this match belongs to (inefficient but safe for small counts)
      TextStyle? matchStyle;
      for (var entry in patternStyles.entries) {
        if (entry.key.pattern == (match.pattern as RegExp).pattern) {
          matchStyle = entry.value;
          break;
        }
      }
      
      children.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: parentStyle.merge(matchStyle),
      ));
      
      currentIndex = match.end;
    }
    
    // 3. Add remaining text
    if (currentIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(currentIndex),
        style: parentStyle,
      ));
    }
    
    return TextSpan(style: parentStyle, children: children);
  }
}
