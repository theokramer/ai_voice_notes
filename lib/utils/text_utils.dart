import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TextUtils {
  /// Builds a TextSpan with highlighted search matches
  static TextSpan buildHighlightedText(
    String text,
    String query, {
    TextStyle? baseStyle,
    Color? highlightColor,
  }) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final color = highlightColor ?? AppTheme.primary;
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle?.copyWith(
          backgroundColor: color.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  /// Gets a snippet of text around a search match
  static String getMatchSnippet(String text, String query, {int contextLength = 80}) {
    if (query.isEmpty) return text;

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) return text;

    final start = (index - contextLength / 2).clamp(0, text.length).toInt();
    final end = (index + query.length + contextLength / 2).clamp(0, text.length).toInt();

    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';

    return snippet;
  }
}

