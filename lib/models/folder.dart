import 'dart:convert';

class Folder {
  final String id;
  final String name;
  final String icon;
  final String? colorHex;
  final bool isSystem; // true for "Unorganized"
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool aiCreated; // true if AI created this folder
  int noteCount; // cached for performance, mutable for updates

  Folder({
    required this.id,
    required this.name,
    required this.icon,
    this.colorHex,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    this.aiCreated = false,
    this.noteCount = 0,
  });

  Folder copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? aiCreated,
    int? noteCount,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aiCreated: aiCreated ?? this.aiCreated,
      noteCount: noteCount ?? this.noteCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorHex': colorHex,
      'isSystem': isSystem,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'aiCreated': aiCreated,
      'noteCount': noteCount,
    };
  }

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      colorHex: json['colorHex'],
      isSystem: json['isSystem'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      aiCreated: json['aiCreated'] ?? false,
      noteCount: json['noteCount'] ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Folder.fromJsonString(String jsonString) =>
      Folder.fromJson(jsonDecode(jsonString));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

