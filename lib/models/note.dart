import 'dart:convert';

class SearchMatch {
  final String headlineId;
  final String headlineTitle;
  final String entryId;
  final String entryText;
  final int matchStartIndex;
  final int matchEndIndex;

  SearchMatch({
    required this.headlineId,
    required this.headlineTitle,
    required this.entryId,
    required this.entryText,
    required this.matchStartIndex,
    required this.matchEndIndex,
  });
}

class Note {
  final String id;
  final String name;
  final String icon;
  final List<Headline> headlines;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
  final List<String> tags;
  final bool isPinned;

  Note({
    required this.id,
    required this.name,
    required this.icon,
    required this.headlines,
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
    this.tags = const [],
    this.isPinned = false,
  });

  // Cached computation: total number of entries across all headlines
  int get totalEntries {
    return headlines.fold<int>(
      0,
      (sum, headline) => sum + headline.entries.length,
    );
  }

  // Cached computation: get the most recent entry text
  String? get latestEntryText {
    if (headlines.isEmpty) return null;
    
    TextEntry? latestEntry;
    DateTime? latestTime;

    for (final headline in headlines) {
      if (headline.entries.isEmpty) continue;
      
      final entry = headline.entries.last;
      if (latestTime == null || entry.createdAt.isAfter(latestTime)) {
        latestEntry = entry;
        latestTime = entry.createdAt;
      }
    }

    return latestEntry?.text;
  }

  Note copyWith({
    String? id,
    String? name,
    String? icon,
    List<Headline>? headlines,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    List<String>? tags,
    bool? isPinned,
  }) {
    return Note(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      headlines: headlines ?? this.headlines,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'headlines': headlines.map((h) => h.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'tags': tags,
      'isPinned': isPinned,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      headlines: (json['headlines'] as List)
          .map((h) => Headline.fromJson(h))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'])
          : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      isPinned: json['isPinned'] ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Note.fromJsonString(String jsonString) =>
      Note.fromJson(jsonDecode(jsonString));
}

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

  Headline copyWith({
    String? id,
    String? title,
    List<TextEntry>? entries,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return Headline(
      id: id ?? this.id,
      title: title ?? this.title,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

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

