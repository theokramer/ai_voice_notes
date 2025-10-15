import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/folder.dart';
import '../services/openai_service.dart';

/// Types of voice commands that can be detected
enum VoiceCommandType {
  folder, // Save to specific folder (will create if doesn't exist)
  append, // Append to last created note
  setTitle, // Set custom title for note
}

/// Result of voice command detection
class VoiceCommand {
  final VoiceCommandType type;
  final String originalKeyword; // The actual keyword detected
  final String? folderId; // For folder commands
  final String? folderName; // For folder commands (existing or to be created)
  final String? noteTitle; // For setTitle commands
  final double confidence; // Confidence score (0.0-1.0)
  final String? remainingContent; // Content after command extraction
  
  VoiceCommand({
    required this.type,
    required this.originalKeyword,
    this.folderId,
    this.folderName,
    this.noteTitle,
    this.confidence = 1.0,
    this.remainingContent,
  });
  
  @override
  String toString() {
    return 'VoiceCommand(type: $type, keyword: "$originalKeyword", folder: $folderName, title: $noteTitle, confidence: $confidence)';
  }
}

/// Result of detecting multiple voice commands in a transcription
class VoiceCommandResult {
  final List<VoiceCommand> commands; // All detected commands
  final String remainingContent; // Content after all commands extracted
  final bool hasCommands; // True if any commands detected
  
  VoiceCommandResult({
    required this.commands,
    required this.remainingContent,
  }) : hasCommands = commands.isNotEmpty;
  
  // Get the first command of a specific type
  VoiceCommand? getCommand(VoiceCommandType type) {
    try {
      return commands.firstWhere((cmd) => cmd.type == type);
    } catch (e) {
      return null;
    }
  }
  
  // Check if has command of specific type
  bool hasCommandType(VoiceCommandType type) {
    return commands.any((cmd) => cmd.type == type);
  }
  
  @override
  String toString() {
    return 'VoiceCommandResult(commands: ${commands.length}, content: "${remainingContent.substring(0, remainingContent.length > 50 ? 50 : remainingContent.length)}...")';
  }
}

/// Service for detecting and processing voice commands in transcriptions
class VoiceCommandService {
  // Multilingual keywords for fallback detection
  static const Map<String, List<String>> _appendKeywords = {
    'en': ['add to last note', 'append to last note', 'addition', 'append'],
    'de': ['füge zu letzter notiz hinzu', 'zur letzten notiz', 'ergänzung', 'hinzufügen'],
    'fr': ['ajouter à la dernière note', 'ajout', 'ajouter'],
    'es': ['agregar a la última nota', 'añadir a la última', 'adición'],
  };
  
  static const Map<String, List<String>> _newFolderKeywords = {
    'en': ['new folder', 'new', 'create folder'],
    'de': ['neuer ordner', 'neu', 'neue', 'ordner erstellen'],
    'fr': ['nouveau dossier', 'nouvelle', 'créer dossier'],
    'es': ['nueva carpeta', 'nuevo', 'crear carpeta'],
  };
  
  static const Map<String, List<String>> _folderKeywords = {
    'en': ['folder', 'in folder', 'to folder'],
    'de': ['ordner', 'in ordner', 'zu ordner'],
    'fr': ['dossier', 'dans dossier', 'au dossier'],
    'es': ['carpeta', 'en carpeta', 'a carpeta'],
  };
  
  static const Map<String, List<String>> _titleKeywords = {
    'en': ['note with title', 'title', 'with title'],
    'de': ['notiz mit titel', 'titel', 'mit titel'],
    'fr': ['note avec titre', 'titre', 'avec titre'],
    'es': ['nota con título', 'título', 'con título'],
  };
  
  /// Detect voice commands from transcription text using AI
  /// Returns VoiceCommandResult with all detected commands and remaining content
  static Future<VoiceCommandResult> detectCommand(String transcription, List<Folder> folders, {String? apiKey}) async {
    if (transcription.trim().isEmpty) {
      return VoiceCommandResult(commands: [], remainingContent: transcription);
    }
    
    debugPrint('🔍 Voice command detection for: "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
    
    // First try AI detection if API key is available
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final aiResult = await _detectCommandWithAI(transcription, folders, apiKey);
        if (aiResult.hasCommands) {
          debugPrint('🤖 AI detected ${aiResult.commands.length} command(s): $aiResult');
          return aiResult;
        }
      } catch (e) {
        debugPrint('⚠️ AI command detection failed: $e');
      }
    }
    
    // Fallback to keyword-based detection
    return _detectCommandWithKeywords(transcription, folders);
  }
  
  /// AI-based command detection using OpenAI with multilingual support
  static Future<VoiceCommandResult> _detectCommandWithAI(String transcription, List<Folder> folders, String apiKey) async {
    final openAIService = OpenAIService(apiKey: apiKey);
    
    // Build folder names list for context
    final folderNames = folders.where((f) => !f.isSystem).map((f) => f.name).join(', ');
    
    final prompt = '''
You are a multilingual voice command detector for a note-taking app. Analyze the transcription and detect voice commands in German, English, French, or Spanish.

AVAILABLE FOLDERS: $folderNames

COMMAND TYPES TO DETECT:

1. APPEND - Add content to the last created note
   English: "add to last note", "append to last note", "addition"
   German: "füge zu letzter notiz hinzu", "zur letzten notiz", "ergänzung"
   French: "ajouter à la dernière note", "ajout"
   Spanish: "agregar a la última nota", "añadir a la última", "adición"

2. FOLDER - Save to an existing folder (will create if doesn't exist)
   English: "folder [name]", "in folder [name]", "to folder [name]", "new [name]", "new folder [name]"
   German: "ordner [name]", "in ordner [name]", "neu [name]", "neue [name]", "neuer ordner [name]"
   French: "dossier [name]", "dans dossier [name]", "nouvelle [name]", "nouveau dossier [name]"
   Spanish: "carpeta [name]", "en carpeta [name]", "nuevo [name]", "nueva carpeta [name]"

3. SET_TITLE - Set custom title for the note
   English: "note with title [title]", "title [title]", "with title [title]"
   German: "notiz mit titel [title]", "titel [title]", "mit titel [title]"
   French: "note avec titre [title]", "titre [title]", "avec titre [title]"
   Spanish: "nota con título [title]", "título [title]", "con título [title]"

CRITICAL RULES:
1. Only detect commands if confidence > 0.8 (high certainty it's intentional)
2. Commands typically appear at the START of transcription
3. Support natural variations and speech recognition errors (e.g., "Neue Journaling" = "new Journaling")
4. Can detect MULTIPLE commands in one transcription (e.g., "new note with title Meeting in folder Work")
5. Extract remaining content after ALL commands
6. If text doesn't clearly match patterns, return NO commands (avoid false positives)
7. Be smart: "get together" is NOT "new", but "neue Tagebuch" or "new Journaling" IS a command
8. **FOLDER AUTO-CREATION**: All folder commands will automatically create the folder if it doesn't exist
9. **TITLE EXTRACTION**: When detecting title command, extract ONLY the title text (not the whole sentence). Remove the title AND the command keyword from remainingContent. The title should be the phrase immediately after "title" keyword, NOT the entire transcription.

COMBINED COMMAND EXAMPLES:
- "New note with title Meeting Notes in folder Work and here are my notes..."
  → Commands: [FOLDER("Work"), SET_TITLE("Meeting Notes")], Content: "and here are my notes..."
  
- "Titel Morgengedanken in Ordner Tagebuch heute war ein guter Tag"
  → Commands: [SET_TITLE("Morgengedanken"), FOLDER("Tagebuch")], Content: "heute war ein guter Tag"

- "Neu Journaling ich bin heute sehr glücklich"
  → Commands: [FOLDER("Journaling")], Content: "ich bin heute sehr glücklich"

- "Title I love potatoes and today I went shopping"
  → Commands: [SET_TITLE("I love potatoes")], Content: "and today I went shopping"
  ⚠️ Title is ONLY "I love potatoes" - do NOT include the rest in the title!

NON-COMMAND EXAMPLES (should return NO commands):
- "I need to get together with John tomorrow" → NO commands (normal note)
- "Today I went to a new restaurant" → NO commands (not a folder command)
- "My title at work changed" → NO commands (talking about job title)

Return JSON ONLY (no markdown):
{
  "commands": [
    {
      "type": "append|folder|setTitle",
      "confidence": 0.95,
      "folderName": "name of folder (for folder type)",
      "noteTitle": "title text (for setTitle type)"
    }
  ],
  "remainingContent": "content after removing all command keywords",
  "isCommand": true
}

If NO commands detected:
{
  "commands": [],
  "remainingContent": "$transcription",
  "isCommand": false
}

TRANSCRIPTION TO ANALYZE:
"$transcription"
''';
  
    try {
      final response = await openAIService.chatCompletion(
        message: prompt,
        history: [],
        notes: [],
      );
      
      // Parse AI response
      final responseText = response.text.trim();
      debugPrint('🤖 AI response: $responseText');
      
      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.substring(jsonStr.indexOf('```json') + 7);
        jsonStr = jsonStr.substring(0, jsonStr.indexOf('```'));
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.substring(jsonStr.indexOf('```') + 3);
        jsonStr = jsonStr.substring(0, jsonStr.indexOf('```'));
      }
      jsonStr = jsonStr.trim();
      
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final isCommand = jsonData['isCommand'] as bool? ?? false;
      final remainingContent = jsonData['remainingContent'] as String? ?? transcription;
      
      if (!isCommand || jsonData['commands'] == null) {
        return VoiceCommandResult(
          commands: [],
          remainingContent: remainingContent,
        );
      }
      
      final commandsList = jsonData['commands'] as List;
      final commands = <VoiceCommand>[];
      
      for (final cmdData in commandsList) {
        final typeStr = cmdData['type'] as String?;
        final confidence = (cmdData['confidence'] as num?)?.toDouble() ?? 1.0;
        
        // Skip low confidence commands
        if (confidence < 0.8) continue;
        
        VoiceCommandType? commandType;
        VoiceCommand? command;
        
        switch (typeStr) {
          case 'append':
            commandType = VoiceCommandType.append;
            command = VoiceCommand(
              type: commandType,
              originalKeyword: 'append',
              confidence: confidence,
            );
            break;
            
          case 'setTitle':
            final noteTitle = cmdData['noteTitle'] as String?;
            if (noteTitle != null && noteTitle.isNotEmpty) {
              commandType = VoiceCommandType.setTitle;
              command = VoiceCommand(
                type: commandType,
                originalKeyword: 'title',
                noteTitle: noteTitle,
                confidence: confidence,
              );
            }
            break;
            
          case 'folder':
            final folderName = cmdData['folderName'] as String?;
            if (folderName != null && folderName.isNotEmpty) {
              // Always use folder command type - backend will handle creation if needed
              commandType = VoiceCommandType.folder;
              command = VoiceCommand(
                type: commandType,
                originalKeyword: 'folder',
                folderName: folderName, // Pass folder name directly
                confidence: confidence,
              );
            }
            break;
        }
        
        if (command != null) {
          commands.add(command);
        }
      }
      
      return VoiceCommandResult(
        commands: commands,
        remainingContent: remainingContent,
      );
      
    } catch (e) {
      debugPrint('❌ AI command detection error: $e');
      return VoiceCommandResult(
        commands: [],
        remainingContent: transcription,
      );
    }
  }
  
  /// Fallback keyword-based command detection with multilingual support
  static VoiceCommandResult _detectCommandWithKeywords(String transcription, List<Folder> folders) {
    if (transcription.trim().isEmpty) {
      return VoiceCommandResult(commands: [], remainingContent: transcription);
    }
    
    final normalized = transcription.toLowerCase().trim();
    final commands = <VoiceCommand>[];
    String remainingContent = transcription;
    
    // Helper to extract name after keyword (handles various separators)
    String? extractNameAfterKeyword(String text, String keyword) {
      final afterKeyword = text.substring(keyword.length).trim();
      
      // Try different separators
      if (afterKeyword.contains(':')) {
        return afterKeyword.substring(0, afterKeyword.indexOf(':')).trim();
      }
      
      // Take first 1-3 words as name
      final words = afterKeyword.split(RegExp(r'\s+'));
      if (words.isEmpty) return null;
      
      // Look for common stopping words
      final stopWords = ['in', 'im', 'und', 'and', 'et', 'y', 'with', 'mit', 'avec', 'con'];
      final nameWords = <String>[];
      for (final word in words.take(3)) {
        if (stopWords.contains(word.toLowerCase())) break;
        nameWords.add(word);
      }
      
      return nameWords.isEmpty ? null : nameWords.join(' ');
    }
    
    // Check for append commands (highest priority - very specific)
    for (final langKeywords in _appendKeywords.values) {
      for (final keyword in langKeywords) {
        if (normalized.startsWith(keyword.toLowerCase())) {
          commands.add(VoiceCommand(
            type: VoiceCommandType.append,
            originalKeyword: keyword,
            confidence: 0.9,
          ));
          remainingContent = transcription.substring(keyword.length).trim();
          
          // Remove colon if present at start
          if (remainingContent.startsWith(':')) {
            remainingContent = remainingContent.substring(1).trim();
          }
          
          return VoiceCommandResult(
            commands: commands,
            remainingContent: remainingContent,
          );
        }
      }
    }
    
    // Check for title commands
    for (final langKeywords in _titleKeywords.values) {
      for (final keyword in langKeywords) {
        if (normalized.contains(keyword.toLowerCase())) {
          final keywordIndex = normalized.indexOf(keyword.toLowerCase());
          
          // Extract title (until next command keyword or end of reasonable title length)
          String? title = extractNameAfterKeyword(transcription.substring(keywordIndex), keyword);
          
          if (title != null && title.isNotEmpty) {
            commands.add(VoiceCommand(
              type: VoiceCommandType.setTitle,
              originalKeyword: keyword,
              noteTitle: title,
              confidence: 0.85,
            ));
            
            // Continue checking for more commands after this one
            break;
          }
        }
      }
    }
    
    // Check for folder commands (including "new" keywords)
    for (final langKeywords in _newFolderKeywords.values) {
      for (final keyword in langKeywords) {
        if (normalized.startsWith(keyword.toLowerCase())) {
          final folderName = extractNameAfterKeyword(transcription, keyword);
          
          if (folderName != null && folderName.isNotEmpty && folderName.toLowerCase() != 'folder') {
            // Always use folder command type - backend will handle creation if needed
            commands.add(VoiceCommand(
              type: VoiceCommandType.folder,
              originalKeyword: keyword,
              folderName: folderName,
              confidence: 0.9,
            ));
            break;
          }
        }
      }
    }
    
    // Check for folder assignment commands (without "new")
    if (commands.isEmpty) {
      for (final langKeywords in _folderKeywords.values) {
        for (final keyword in langKeywords) {
          if (normalized.startsWith(keyword.toLowerCase())) {
            final folderName = extractNameAfterKeyword(transcription, keyword);
            
            if (folderName != null && folderName.isNotEmpty) {
              // Always use folder command type - backend will handle creation if needed
              commands.add(VoiceCommand(
                type: VoiceCommandType.folder,
                originalKeyword: keyword,
                folderName: folderName,
                confidence: 0.9,
              ));
              break;
            }
          }
        }
      }
    }
    
    // Extract remaining content by removing detected command keywords
    if (commands.isNotEmpty) {
      // Simple approach: look for colon or common separators
      if (transcription.contains(':')) {
        final colonIndex = transcription.indexOf(':');
        remainingContent = transcription.substring(colonIndex + 1).trim();
      } else {
        // Remove first command's keywords and extracted names
        final firstCmd = commands.first;
        if (firstCmd.type == VoiceCommandType.folder) {
          final folderNameToRemove = firstCmd.folderName ?? '';
          // Try to find and remove the folder name from the start
          final pattern = RegExp('${RegExp.escape(firstCmd.originalKeyword)}\\s+${RegExp.escape(folderNameToRemove)}', caseSensitive: false);
          remainingContent = transcription.replaceFirst(pattern, '').trim();
        }
      }
    }
    
    return VoiceCommandResult(
      commands: commands,
      remainingContent: remainingContent.isEmpty ? transcription : remainingContent,
    );
  }
  
  /// Get user-friendly description of the command for feedback messages
  static String getCommandDescription(VoiceCommand command) {
    switch (command.type) {
      case VoiceCommandType.folder:
        return 'Saved to ${command.folderName}';
      case VoiceCommandType.append:
        return 'Added to previous note';
      case VoiceCommandType.setTitle:
        return 'Title set to "${command.noteTitle}"';
    }
  }
  
  /// Get combined description for multiple commands
  static String getCommandsDescription(List<VoiceCommand> commands) {
    if (commands.isEmpty) return '';
    if (commands.length == 1) return getCommandDescription(commands.first);
    
    final descriptions = commands.map((cmd) => getCommandDescription(cmd)).toList();
    return descriptions.join(', ');
  }
}

