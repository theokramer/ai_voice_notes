import 'package:flutter_quill/quill_delta.dart';

class MarkdownToDeltaConverter {
  static Delta convert(String markdown) {
    final delta = Delta();
    
    if (markdown.isEmpty) {
      return delta..insert('\n');
    }
    
    // Simple conversion - treats markdown as plain text and parses basic syntax
    final lines = markdown.split('\n');
    
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      
      // Check for headers
      if (line.startsWith('### ')) {
        delta.insert(line.substring(4));
        delta.insert('\n', {'header': 3});
      } else if (line.startsWith('## ')) {
        delta.insert(line.substring(3));
        delta.insert('\n', {'header': 2});
      } else if (line.startsWith('# ')) {
        delta.insert(line.substring(2));
        delta.insert('\n', {'header': 1});
      }
      // Check for bullets
      else if (line.startsWith('- ')) {
        delta.insert(line.substring(2));
        delta.insert('\n', {'list': 'bullet'});
      }
      // Check for numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^\d+\.\s').firstMatch(line);
        delta.insert(line.substring(match!.end));
        delta.insert('\n', {'list': 'ordered'});
      }
      // Regular text with potential bold/italic
      else {
        _parseInlineFormatting(line, delta);
        delta.insert('\n');
      }
    }
    
    return delta;
  }
  
  static void _parseInlineFormatting(String text, Delta delta) {
    if (text.isEmpty) return;
    
    // Parse bold **text** and italic *text*
    final patterns = [
      {'pattern': RegExp(r'\*\*(.*?)\*\*'), 'attr': 'bold'},
      {'pattern': RegExp(r'\*(.*?)\*'), 'attr': 'italic'},
    ];
    
    var remaining = text;
    
    while (remaining.isNotEmpty) {
      int? nearestIndex;
      RegExpMatch? nearestMatch;
      String? nearestAttr;
      
      // Find the nearest formatting pattern
      for (final p in patterns) {
        final pattern = p['pattern'] as RegExp;
        final match = pattern.firstMatch(remaining);
        
        if (match != null) {
          if (nearestIndex == null || match.start < nearestIndex) {
            nearestIndex = match.start;
            nearestMatch = match;
            nearestAttr = p['attr'] as String;
          }
        }
      }
      
      if (nearestMatch != null && nearestAttr != null) {
        // Add text before the match
        if (nearestMatch.start > 0) {
          delta.insert(remaining.substring(0, nearestMatch.start));
        }
        
        // Add formatted text
        final formattedText = nearestMatch.group(1)!;
        delta.insert(formattedText, {nearestAttr: true});
        
        // Continue with remaining text
        remaining = remaining.substring(nearestMatch.end);
      } else {
        // No more formatting found, add remaining text
        delta.insert(remaining);
        break;
      }
    }
  }
}

