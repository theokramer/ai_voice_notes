import 'dart:convert';

enum OrganizationSuggestionType {
  move,         // Move note to existing folder
  createFolder, // Create new folder and move notes
  merge,        // Merge similar notes together
  split,        // Split large note into multiple notes
}

/// Represents a single note's organization suggestion (per-note basis)
class NoteOrganizationSuggestion {
  final String noteId;
  final OrganizationSuggestionType type;
  final String? targetFolderId;
  final String? targetFolderName;
  final String? newFolderName;
  final String? newFolderIcon;
  final String reasoning;
  final double confidence; // 0.0 to 1.0
  
  // User override fields
  String? userSelectedFolderId;
  String? userSelectedFolderName;
  bool userModified;
  
  NoteOrganizationSuggestion({
    required this.noteId,
    required this.type,
    this.targetFolderId,
    this.targetFolderName,
    this.newFolderName,
    this.newFolderIcon,
    required this.reasoning,
    required this.confidence,
    this.userSelectedFolderId,
    this.userSelectedFolderName,
    this.userModified = false,
  });

  // Helper to check if this is a high confidence suggestion
  bool get isHighConfidence => confidence >= 0.8;
  
  // Helper to check if this is a low confidence suggestion
  bool get isLowConfidence => confidence < 0.6;
  
  // Helper to check if user needs to take action
  bool get needsUserAction => isLowConfidence && !userModified;
  
  // Get the effective folder ID (user selection or AI suggestion)
  String? get effectiveFolderId => userSelectedFolderId ?? targetFolderId;
  
  // Get the effective folder name (user selection or AI suggestion)
  String? get effectiveFolderName => userSelectedFolderName ?? (targetFolderName ?? newFolderName);
  
  // Check if creating new folder
  // If user selected an existing folder (userSelectedFolderId != null), it's NOT creating a new folder
  bool get isCreatingNewFolder {
    // If user selected an existing folder, definitely not creating new
    if (userModified && userSelectedFolderId != null) {
      return false;
    }
    
    // If user selected a folder name without ID (manually creating new folder)
    if (userModified && userSelectedFolderId == null && userSelectedFolderName != null) {
      return true;
    }
    
    // Otherwise, use the original AI suggestion type
    return type == OrganizationSuggestionType.createFolder;
  }

  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'type': type.name,
      'targetFolderId': targetFolderId,
      'targetFolderName': targetFolderName,
      'newFolderName': newFolderName,
      'newFolderIcon': newFolderIcon,
      'reasoning': reasoning,
      'confidence': confidence,
      'userSelectedFolderId': userSelectedFolderId,
      'userSelectedFolderName': userSelectedFolderName,
      'userModified': userModified,
    };
  }

  factory NoteOrganizationSuggestion.fromJson(Map<String, dynamic> json) {
    return NoteOrganizationSuggestion(
      noteId: json['noteId'],
      type: OrganizationSuggestionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      targetFolderId: json['targetFolderId'],
      targetFolderName: json['targetFolderName'],
      newFolderName: json['newFolderName'],
      newFolderIcon: json['newFolderIcon'],
      reasoning: json['reasoning'],
      confidence: json['confidence'].toDouble(),
      userSelectedFolderId: json['userSelectedFolderId'],
      userSelectedFolderName: json['userSelectedFolderName'],
      userModified: json['userModified'] ?? false,
    );
  }
  
  NoteOrganizationSuggestion copyWith({
    String? userSelectedFolderId,
    String? userSelectedFolderName,
    bool? userModified,
  }) {
    return NoteOrganizationSuggestion(
      noteId: noteId,
      type: type,
      targetFolderId: targetFolderId,
      targetFolderName: targetFolderName,
      newFolderName: newFolderName,
      newFolderIcon: newFolderIcon,
      reasoning: reasoning,
      confidence: confidence,
      userSelectedFolderId: userSelectedFolderId ?? this.userSelectedFolderId,
      userSelectedFolderName: userSelectedFolderName ?? this.userSelectedFolderName,
      userModified: userModified ?? this.userModified,
    );
  }
}

class OrganizationSuggestion {
  final String id;
  final OrganizationSuggestionType type;
  final List<String> noteIds;
  final String? targetFolderId;
  final String? newFolderName;
  final String? newFolderIcon;
  final String reasoning;
  final double confidence; // 0.0 to 1.0
  
  OrganizationSuggestion({
    required this.id,
    required this.type,
    required this.noteIds,
    this.targetFolderId,
    this.newFolderName,
    this.newFolderIcon,
    required this.reasoning,
    required this.confidence,
  });

  // Helper to check if this is a high confidence suggestion
  bool get isHighConfidence => confidence >= 0.8;

  // Helper to get a display title for the suggestion
  String getDisplayTitle() {
    switch (type) {
      case OrganizationSuggestionType.move:
        return 'Move to folder';
      case OrganizationSuggestionType.createFolder:
        return 'Create folder: ${newFolderName ?? "New Folder"}';
      case OrganizationSuggestionType.merge:
        return 'Merge ${noteIds.length} similar notes';
      case OrganizationSuggestionType.split:
        return 'Split into multiple notes';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'noteIds': noteIds,
      'targetFolderId': targetFolderId,
      'newFolderName': newFolderName,
      'newFolderIcon': newFolderIcon,
      'reasoning': reasoning,
      'confidence': confidence,
    };
  }

  factory OrganizationSuggestion.fromJson(Map<String, dynamic> json) {
    return OrganizationSuggestion(
      id: json['id'],
      type: OrganizationSuggestionType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      noteIds: List<String>.from(json['noteIds']),
      targetFolderId: json['targetFolderId'],
      newFolderName: json['newFolderName'],
      newFolderIcon: json['newFolderIcon'],
      reasoning: json['reasoning'],
      confidence: json['confidence'].toDouble(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory OrganizationSuggestion.fromJsonString(String jsonString) =>
      OrganizationSuggestion.fromJson(jsonDecode(jsonString));
}

// Result class for auto-organization
class AutoOrganizationResult {
  final String? folderId;
  final String? folderName;
  final bool createNewFolder;
  final String? suggestedFolderIcon;
  final double confidence;
  final String reasoning;

  AutoOrganizationResult({
    this.folderId,
    this.folderName,
    this.createNewFolder = false,
    this.suggestedFolderIcon,
    required this.confidence,
    required this.reasoning,
  });

  factory AutoOrganizationResult.fromJson(Map<String, dynamic> json) {
    return AutoOrganizationResult(
      folderId: json['folderId'],
      folderName: json['folderName'],
      createNewFolder: json['createNewFolder'] ?? false,
      suggestedFolderIcon: json['suggestedFolderIcon'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      reasoning: json['reasoning'] ?? '',
    );
  }
}

