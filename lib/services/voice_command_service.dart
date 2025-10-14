import 'package:flutter/foundation.dart';
import '../models/folder.dart';

/// Types of voice commands that can be detected
enum VoiceCommandType {
  folder, // Save to specific folder
  append, // Append to last created note
  createFolder, // Create new folder and save note there
}

/// Result of voice command detection
class VoiceCommand {
  final VoiceCommandType type;
  final String originalKeyword; // The actual keyword detected
  final String? folderId; // For folder commands
  final String? folderName; // For folder commands (existing or to be created)
  final String? newFolderName; // For createFolder commands - the name to create
  
  VoiceCommand({
    required this.type,
    required this.originalKeyword,
    this.folderId,
    this.folderName,
    this.newFolderName,
  });
  
  @override
  String toString() {
    return 'VoiceCommand(type: $type, keyword: "$originalKeyword", folder: $folderName, newFolder: $newFolderName)';
  }
}

/// Service for detecting and processing voice commands in transcriptions
class VoiceCommandService {
  // Multi-language keywords for "append to last note" command
  static const List<String> _appendKeywords = [
    // English
    'addition',
    'append',
    'continue',
    'add to last',
    'add to previous',
    'adding to last',
    'continue last note',
    'add to last note',
    
    // German
    'ergänzung',
    'hinzufügen',
    'weiter',
    'fortsetzen',
    'an letzte notiz',
    'zu letzter notiz',
    'letzte notiz weiter',
    
    // Spanish
    'añadir',
    'continuar',
    'agregar',
    'añadir a última',
    'añadir a última nota',
    'continuar última nota',
    
    // French
    'ajouter',
    'continuer',
    'ajout',
    'ajouter à dernière',
    'ajouter à dernière note',
    'continuer dernière note',
  ];
  
  // Multi-language keywords for "create new folder" command
  static const List<String> _createFolderKeywords = [
    // English
    'new',
    'new folder',
    'create folder',
    'create',
    
    // German
    'neu',
    'neue',
    'neuer',
    'neuer ordner',
    'neue ordner',
    'ordner',
    
    // Spanish
    'nuevo',
    'nueva',
    'nueva carpeta',
    'nuevo carpeta',
    'crear carpeta',
    'carpeta',
    
    // French
    'nouveau',
    'nouvelle',
    'nouveau dossier',
    'nouvelle dossier',
    'créer dossier',
    'créer',
    'dossier',
  ];
  
  /// Detect voice command from transcription text
  /// Returns VoiceCommand if a command is detected, null otherwise
  /// 
  /// Logic:
  /// 1. Extract first sentence (up to first punctuation: . ! ?)
  /// 2. Check if starts with "New {FolderName}" pattern to create folder
  /// 3. Check if first word(s) match any append keywords
  /// 4. Check if first word(s) match any existing folder names
  /// 5. If no match, return null (treat as normal content)
  static VoiceCommand? detectCommand(String transcription, List<Folder> folders) {
    if (transcription.trim().isEmpty) return null;
    
    debugPrint('🔍 Voice command detection for: "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
    
    // Extract first sentence (everything before . ! ? or end of string)
    final firstSentenceMatch = RegExp(r'^[^.!?]+').firstMatch(transcription);
    if (firstSentenceMatch == null) return null;
    
    final firstSentence = firstSentenceMatch.group(0)!.trim();
    if (firstSentence.isEmpty) return null;
    
    // Normalize for comparison: lowercase, remove extra spaces
    final normalized = firstSentence.toLowerCase().trim();
    debugPrint('🔍 First sentence: "$firstSentence"');
    debugPrint('🔍 Normalized: "$normalized"');
    
    // 1. Check for "New {FolderName}" pattern first (highest priority)
    // Sort keywords by length (longest first) to match multi-word commands before single words
    final sortedCreateKeywords = List<String>.from(_createFolderKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final keyword in sortedCreateKeywords) {
      // Check if starts with "new" keyword followed by a space and folder name
      if (_startsWithKeyword(normalized, keyword)) {
        // Extract the folder name after "new"
        final folderName = _extractFolderNameAfterNew(firstSentence, keyword);
        if (folderName != null && folderName.isNotEmpty) {
          debugPrint('🎤 Voice command detected: CREATE FOLDER "$folderName" ("$keyword")');
          return VoiceCommand(
            type: VoiceCommandType.createFolder,
            originalKeyword: _extractOriginalKeyword(firstSentence, '$keyword $folderName'),
            newFolderName: folderName,
          );
        }
      }
    }
    
    // 2. Check for append commands (high priority)
    // Sort keywords by length (longest first) to match multi-word commands before single words
    final sortedAppendKeywords = List<String>.from(_appendKeywords)
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final keyword in sortedAppendKeywords) {
      if (_matchesKeyword(normalized, keyword)) {
        debugPrint('🎤 Voice command detected: APPEND ("$keyword")');
        return VoiceCommand(
          type: VoiceCommandType.append,
          originalKeyword: _extractOriginalKeyword(firstSentence, keyword),
        );
      }
    }
    
    // 2. Check for folder name match (dynamic, matches any existing folder)
    // Try matching from longest folder name to shortest (to handle multi-word folders)
    final sortedFolders = List<Folder>.from(folders)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    
    for (final folder in sortedFolders) {
      // Skip system folders (Unorganized)
      if (folder.isSystem) continue;
      
      final folderNameNormalized = folder.name.toLowerCase().trim();
      
      if (_matchesKeyword(normalized, folderNameNormalized)) {
        debugPrint('🎤 Voice command detected: FOLDER "${folder.name}" (matched "$folderNameNormalized")');
        return VoiceCommand(
          type: VoiceCommandType.folder,
          originalKeyword: _extractOriginalKeyword(firstSentence, folderNameNormalized),
          folderId: folder.id,
          folderName: folder.name,
        );
      }
    }
    
    // No command detected
    return null;
  }
  
  /// Check if normalized text starts with the keyword (with flexible punctuation/spacing)
  /// Handles variations like "todo", "todo.", "to-do", "to do"
  static bool _matchesKeyword(String normalizedText, String keyword) {
    // Remove common punctuation and extra spaces for comparison
    final cleanText = normalizedText
        .replaceAll(RegExp(r'[,.:;!?-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanKeyword = keyword
        .replaceAll(RegExp(r'[,.:;!?-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Check if text starts with keyword (followed by space or end of string)
    if (cleanText == cleanKeyword) return true;
    if (cleanText.startsWith('$cleanKeyword ')) return true;
    
    return false;
  }
  
  /// Check if normalized text starts with keyword (for "New" command)
  static bool _startsWithKeyword(String normalizedText, String keyword) {
    final cleanText = normalizedText
        .replaceAll(RegExp(r'[,.:;!?-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final cleanKeyword = keyword
        .replaceAll(RegExp(r'[,.:;!?-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Must be followed by space (there should be a folder name after)
    return cleanText.startsWith('$cleanKeyword ');
  }
  
  /// Extract folder name after "New" keyword
  /// Example: "New Shopping" -> "Shopping"
  /// Example: "Neu Einkaufen" -> "Einkaufen"
  /// Example: "Create folder Books" -> "Books"
  /// Example: "Neuer Ordner Arbeit" -> "Arbeit"
  static String? _extractFolderNameAfterNew(String firstSentence, String keyword) {
    // Clean the text
    final cleanText = firstSentence
        .replaceAll(RegExp(r'[,.:;!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    final cleanTextLower = cleanText.toLowerCase();
    final keywordLower = keyword.toLowerCase();
    
    // Check if text starts with keyword
    if (!cleanTextLower.startsWith('$keywordLower ')) {
      return null;
    }
    
    // Find where the keyword ends in the original text (case-insensitive)
    // We need to preserve the original case for the folder name
    final keywordWordCount = keywordLower.split(' ').length;
    final textWords = cleanText.split(' ');
    
    // Skip the keyword words
    if (textWords.length <= keywordWordCount) {
      return null; // No folder name after keyword
    }
    
    // Get the first word after the keyword as folder name
    final folderName = textWords[keywordWordCount];
    
    if (folderName.isEmpty) return null;
    
    // Capitalize first letter if not already
    return folderName[0].toUpperCase() + folderName.substring(1);
  }
  
  /// Extract the original keyword as it appeared in the text (preserving case)
  static String _extractOriginalKeyword(String firstSentence, String keyword) {
    // Try to find the keyword in the original text, preserving case
    final words = firstSentence.split(RegExp(r'\s+'));
    final keywordWords = keyword.split(RegExp(r'\s+'));
    
    // Single word keyword
    if (keywordWords.length == 1) {
      if (words.isNotEmpty) {
        // Remove trailing punctuation from first word
        return words.first.replaceAll(RegExp(r'[,.:;!?-]+$'), '');
      }
    }
    
    // Multi-word keyword
    if (words.length >= keywordWords.length) {
      final extractedWords = words.take(keywordWords.length).toList();
      // Remove trailing punctuation from last word
      if (extractedWords.isNotEmpty) {
        extractedWords[extractedWords.length - 1] = 
            extractedWords.last.replaceAll(RegExp(r'[,.:;!?-]+$'), '');
      }
      return extractedWords.join(' ');
    }
    
    return firstSentence;
  }
  
  /// Extract content after the command keyword
  /// Returns the transcription without the command, ready for beautification
  static String extractContentAfterCommand(String transcription, VoiceCommand command) {
    if (transcription.trim().isEmpty) return '';
    
    // Find the original keyword in the text
    final keywordLength = command.originalKeyword.length;
    
    // Remove the keyword from the start
    String content = transcription;
    
    // Case-insensitive search for the keyword at the start
    final lowerTranscription = transcription.toLowerCase();
    final lowerKeyword = command.originalKeyword.toLowerCase();
    
    if (lowerTranscription.startsWith(lowerKeyword)) {
      content = transcription.substring(keywordLength).trim();
      
      // Remove leading punctuation (., :, -, etc.)
      content = content.replaceFirst(RegExp(r'^[,.:;!?\-\s]+'), '').trim();
    }
    
    return content;
  }
  
  /// Get user-friendly description of the command for feedback messages
  static String getCommandDescription(VoiceCommand command) {
    switch (command.type) {
      case VoiceCommandType.folder:
        return 'Saved to ${command.folderName}';
      case VoiceCommandType.append:
        return 'Added to previous note';
      case VoiceCommandType.createFolder:
        return 'Created folder "${command.newFolderName}"';
    }
  }
}

