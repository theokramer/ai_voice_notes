import 'dart:convert';

// Simplified Note model - single content field instead of headlines/entries
class Note {
  final String id;
  final String name;
  final String icon;
  final String content; // Single plain text field - replaces headlines/entries
  final String? rawTranscription; // Original Whisper transcription (unmodified)
  final String? beautifiedContent; // AI-improved/summarized version (deprecated, use summary instead)
  final String? summary; // AI-generated concise summary of the transcription
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
  final bool isPinned;
  final String? folderId; // null = Unorganized folder
  final bool aiOrganized; // true if AI placed it in a folder
  final bool aiBeautified; // true if AI structured the content
  final String? detectedLanguage; // Language code detected by Whisper (e.g., 'en', 'de', 'es')

  Note({
    required this.id,
    required this.name,
    required this.icon,
    required this.content,
    this.rawTranscription,
    this.beautifiedContent,
    this.summary,
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
    this.isPinned = false,
    this.folderId,
    this.aiOrganized = false,
    this.aiBeautified = false,
    this.detectedLanguage,
  });

  // Helper to get a preview of the content (first 150 characters)
  String get contentPreview {
    if (content.isEmpty) return '';
    
    // Try to extract plain text if it's Quill JSON Delta
    String plainText = content;
    try {
      final json = jsonDecode(content);
      if (json is List) {
        // It's Quill Delta format
        final buffer = StringBuffer();
        for (final op in json) {
          if (op is Map && op.containsKey('insert')) {
            final data = op['insert'];
            if (data is String) {
              buffer.write(data);
            }
          }
        }
        plainText = buffer.toString();
      } else if (json is Map && json.containsKey('ops')) {
        // Delta wrapped in an object with 'ops' key
        final ops = json['ops'];
        if (ops is List) {
          final buffer = StringBuffer();
          for (final op in ops) {
            if (op is Map && op.containsKey('insert')) {
              final data = op['insert'];
              if (data is String) {
                buffer.write(data);
              }
            }
          }
          plainText = buffer.toString();
        }
      }
    } catch (e) {
      // Not JSON, use as-is (plain text or markdown)
      // But ensure it's actually text and not malformed JSON
      if (content.trim().startsWith('[') || content.trim().startsWith('{')) {
        // Looks like JSON but failed to parse
        // Try to extract any visible text between quotes
        final textPattern = RegExp(r'"insert"\s*:\s*"([^"]*)"');
        final matches = textPattern.allMatches(content);
        if (matches.isNotEmpty) {
          final buffer = StringBuffer();
          for (final match in matches) {
            if (match.group(1) != null) {
              buffer.write(match.group(1));
            }
          }
          plainText = buffer.toString();
        } else {
          // If that fails, return a safe fallback
          return 'Unable to display content';
        }
      }
    }
    
    // Clean markdown syntax and truncate
    final cleaned = plainText
        .replaceAll(RegExp(r'#+\s*'), '') // Remove markdown headers
        .replaceAll(RegExp(r'\\n'), ' ') // Replace escaped newlines
        .replaceAll('\n', ' ') // Replace newlines with spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
    
    return cleaned.length > 150 
        ? '${cleaned.substring(0, 150)}...' 
        : cleaned;
  }

  Note copyWith({
    String? id,
    String? name,
    String? icon,
    String? content,
    String? rawTranscription,
    String? beautifiedContent,
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    bool? isPinned,
    String? folderId,
    bool? aiOrganized,
    bool? aiBeautified,
    String? detectedLanguage,
  }) {
    return Note(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      content: content ?? this.content,
      rawTranscription: rawTranscription ?? this.rawTranscription,
      beautifiedContent: beautifiedContent ?? this.beautifiedContent,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isPinned: isPinned ?? this.isPinned,
      folderId: folderId ?? this.folderId,
      aiOrganized: aiOrganized ?? this.aiOrganized,
      aiBeautified: aiBeautified ?? this.aiBeautified,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'content': content,
      'rawTranscription': rawTranscription,
      'beautifiedContent': beautifiedContent,
      'summary': summary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'isPinned': isPinned,
      'folderId': folderId,
      'aiOrganized': aiOrganized,
      'aiBeautified': aiBeautified,
      'detectedLanguage': detectedLanguage,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    // Migration: Convert old headline/entry format to new content format
    String content;
    if (json.containsKey('content')) {
      content = json['content'] as String;
    } else if (json.containsKey('headlines')) {
      // Migrate from old format
      content = _convertHeadlinesToContent(json['headlines']);
    } else {
      content = '';
    }

    return Note(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      content: content,
      rawTranscription: json['rawTranscription'] as String?,
      beautifiedContent: json['beautifiedContent'] as String?,
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'])
          : null,
      // Tags removed - ignore if present in old data
      isPinned: json['isPinned'] ?? false,
      folderId: json['folderId'],
      aiOrganized: json['aiOrganized'] ?? false,
      aiBeautified: json['aiBeautified'] ?? false,
      detectedLanguage: json['detectedLanguage'],
    );
  }

  // Helper to migrate old headlines/entries format to new content format
  static String _convertHeadlinesToContent(dynamic headlines) {
    if (headlines is! List) return '';
    
    final buffer = StringBuffer();
    for (final headline in headlines) {
      if (headline is! Map) continue;
      
      final title = headline['title'] as String?;
      if (title != null && title.isNotEmpty) {
        buffer.writeln('## $title');
        buffer.writeln();
      }
      
      final entries = headline['entries'];
      if (entries is List) {
        for (final entry in entries) {
          if (entry is! Map) continue;
          final text = entry['text'] as String?;
          if (text != null && text.isNotEmpty) {
            buffer.writeln(text);
            buffer.writeln();
          }
        }
      }
    }
    
    return buffer.toString().trim();
  }

  String toJsonString() => jsonEncode(toJson());

  factory Note.fromJsonString(String jsonString) =>
      Note.fromJson(jsonDecode(jsonString));
}

// Legacy classes kept for backward compatibility during migration
// These are not used in new code but help with data migration
class Headline {
  final String id;
  final String title;
  final List<TextEntry> entries;
  final DateTime createdAt;
  final bool isPinned;

  Headline({
    required this.id,
    required this.title,
    required this.entries,
    required this.createdAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'entries': entries.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
    };
  }

  factory Headline.fromJson(Map<String, dynamic> json) {
    return Headline(
      id: json['id'],
      title: json['title'],
      entries:
          (json['entries'] as List).map((e) => TextEntry.fromJson(e)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
      isPinned: json['isPinned'] ?? false,
    );
  }
}

class TextEntry {
  final String id;
  final String text;
  final DateTime createdAt;

  TextEntry({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TextEntry.fromJson(Map<String, dynamic> json) {
    return TextEntry(
      id: json['id'],
      text: json['text'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

