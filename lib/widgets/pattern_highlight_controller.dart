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
    List<TextSpan> children = [];
    String text = value.text;
    TextStyle parentStyle = style ?? const TextStyle();
    
    // Combine all matches
    List<Map<String, dynamic>> allMatches = [];
    
    patternStyles.forEach((regex, matchStyle) {
      regex.allMatches(text).forEach((match) {
        allMatches.add({
          'start': match.start,
          'end': match.end,
          'style': matchStyle,
        });
      });
    });

    // Sort by start position
    allMatches.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    // Resolve overlaps (keep first found)
    List<Map<String, dynamic>> finalMatches = [];
    int lastEnd = 0;
    
    for (var match in allMatches) {
      if ((match['start'] as int) >= lastEnd) {
        finalMatches.add(match);
        lastEnd = (match['end'] as int);
      }
    }
    
    int currentIndex = 0;
    for (var match in finalMatches) {
        if ((match['start'] as int) > currentIndex) {
            children.add(TextSpan(text: text.substring(currentIndex, match['start'] as int), style: parentStyle));
        }
        
        children.add(TextSpan(
            text: text.substring(match['start'] as int, match['end'] as int),
            style: parentStyle.merge(match['style'] as TextStyle),
        ));
        
        currentIndex = (match['end'] as int);
    }
    
    if (currentIndex < text.length) {
        children.add(TextSpan(text: text.substring(currentIndex), style: parentStyle));
    }

    return TextSpan(style: parentStyle, children: children);
  }
}
