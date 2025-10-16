import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/folder.dart';

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
    'de': ['add to last note', 'append to last note', 'addition', 'append'],
    'fr': ['add to last note', 'append to last note', 'addition', 'append'],
    'es': ['add to last note', 'append to last note', 'addition', 'append'],
  };
  
  static const Map<String, List<String>> _newFolderKeywords = {
    'en': ['new folder', 'new', 'create folder'],
    'de': ['new folder', 'new', 'create folder'],
    'fr': ['new folder', 'new', 'create folder'],
    'es': ['new folder', 'new', 'create folder'],
  };
  
  static const Map<String, List<String>> _folderKeywords = {
    'en': ['folder', 'in folder', 'to folder'],
    'de': ['folder', 'in folder', 'to folder'],
    'fr': ['folder', 'in folder', 'to folder'],
    'es': ['folder', 'in folder', 'to folder'],
  };
  
  static const Map<String, List<String>> _titleKeywords = {
    'en': ['note with title', 'title', 'with title'],
    'de': ['note with title', 'title', 'with title'],
    'fr': ['note with title', 'title', 'with title'],
    'es': ['note with title', 'title', 'with title'],
  };
  
  /// Detect voice commands from transcription text using hybrid approach
  /// Returns VoiceCommandResult with all detected commands and remaining content
  static Future<VoiceCommandResult> detectCommand(String transcription, List<Folder> folders, {String? apiKey}) async {
    if (transcription.trim().isEmpty) {
      return VoiceCommandResult(commands: [], remainingContent: transcription);
    }
    
    debugPrint('🔍 Voice command detection for: "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
    
    // STAGE 1: Try hard-coded patterns first (fast & reliable)
    final hardCodedResult = _detectWithHardCodedPatterns(transcription);
    if (hardCodedResult != null && hardCodedResult.hasCommands) {
      debugPrint('✅ Hard-coded pattern matched: ${hardCodedResult.commands.length} command(s)');
      return hardCodedResult;
    }
    
    // STAGE 2: Try AI detection if API key available
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final aiResult = await _detectCommandWithAI(transcription, folders, apiKey);
        if (aiResult.hasCommands) {
          debugPrint('🤖 AI detected ${aiResult.commands.length} command(s)');
          return aiResult;
        }
      } catch (e) {
        debugPrint('⚠️ AI command detection failed: $e');
      }
    }
    
    // STAGE 3: Fallback to old keyword detection
    return _detectCommandWithKeywords(transcription, folders);
  }
  
  /// Fast hard-coded pattern detection for main languages (EN, DE, ES, FR)
  static VoiceCommandResult? _detectWithHardCodedPatterns(String transcription) {
    final normalized = transcription.trim();
    
    // APPEND patterns (must be at start)
    final appendPatterns = [
      // English
      RegExp(r'^(addition|append|add to last note|add to previous note)[,.\s]+(.+)', caseSensitive: false),
      // German
      RegExp(r'^(ergänzung|hinzufügen|zur letzten notiz|nachtrag)[,.\s]+(.+)', caseSensitive: false),
      // Spanish
      RegExp(r'^(agregar|añadir|agregar a última nota|adición)[,.\s]+(.+)', caseSensitive: false),
      // French
      RegExp(r'^(ajouter|ajout|ajouter à dernière note)[,.\s]+(.+)', caseSensitive: false),
    ];
    
    // FOLDER patterns
    final folderPatterns = [
      // English
      RegExp(r'^(folder|in folder|to folder|new folder|new)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // German
      RegExp(r'^(ordner|in ordner|neuer ordner|mappe)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // Spanish
      RegExp(r'^(carpeta|en carpeta|nueva carpeta)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // French
      RegExp(r'^(dossier|dans dossier|nouveau dossier)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
    ];
    
    // TITLE patterns
    final titlePatterns = [
      // English
      RegExp(r'^(title|with title|note with title)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // German
      RegExp(r'^(titel|mit titel|notiz mit titel|überschrift)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // Spanish
      RegExp(r'^(título|con título|nota con título)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
      // French
      RegExp(r'^(titre|avec titre|note avec titre)\s+([a-zA-ZÀ-ÿ\s]+?)[,.\s]+(.+)', caseSensitive: false),
    ];
    
    // Check APPEND patterns first (highest priority)
    for (final pattern in appendPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final content = match.group(2)?.trim() ?? '';
        if (content.isNotEmpty) {
          debugPrint('🎯 Hard-coded APPEND pattern matched: "${match.group(1)}"');
          return VoiceCommandResult(
            commands: [
              VoiceCommand(
                type: VoiceCommandType.append,
                originalKeyword: match.group(1) ?? '',
                confidence: 1.0,
              ),
            ],
            remainingContent: content,
          );
        }
      }
    }
    
    // Check FOLDER patterns
    for (final pattern in folderPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final folderName = match.group(2)?.trim() ?? '';
        final content = match.group(3)?.trim() ?? '';
        if (folderName.isNotEmpty) {
          debugPrint('🎯 Hard-coded FOLDER pattern matched: "${match.group(1)}" -> "$folderName"');
          return VoiceCommandResult(
            commands: [
              VoiceCommand(
                type: VoiceCommandType.folder,
                originalKeyword: match.group(1) ?? '',
                folderName: folderName,
                confidence: 1.0,
              ),
            ],
            remainingContent: content,
          );
        }
      }
    }
    
    // Check TITLE patterns
    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final title = match.group(2)?.trim() ?? '';
        final content = match.group(3)?.trim() ?? '';
        if (title.isNotEmpty) {
          debugPrint('🎯 Hard-coded TITLE pattern matched: "${match.group(1)}" -> "$title"');
          return VoiceCommandResult(
            commands: [
              VoiceCommand(
                type: VoiceCommandType.setTitle,
                originalKeyword: match.group(1) ?? '',
                noteTitle: title,
                confidence: 1.0,
              ),
            ],
            remainingContent: content,
          );
        }
      }
    }
    
    // No hard-coded pattern matched
    return null;
  }
  
  /// AI-based command detection using OpenAI with multilingual support
  static Future<VoiceCommandResult> _detectCommandWithAI(String transcription, List<Folder> folders, String apiKey) async {
    // Build folder names list for context
    final folderNames = folders.where((f) => !f.isSystem).map((f) => f.name).join(', ');
    
    final prompt = '''
You are a multilingual voice command detector for a note-taking app. Analyze the transcription and detect voice commands in ANY language the user speaks.

AVAILABLE FOLDERS: $folderNames

COMMAND TYPES TO DETECT:

1. APPEND - Add content to the last created note
   Recognize ALL variations of "add/append" in any language:
   - English: "addition", "append", "add to last note", "add to previous note", "addendum"
   - German: "ergänzung", "hinzufügen", "zur letzten notiz", "nachtrag", "zusatz"
   - Spanish: "agregar", "añadir", "agregar a última nota", "adición", "complemento"
   - French: "ajouter", "ajout", "ajouter à dernière note", "complément", "supplément"
   - Japanese: "追加" (tsuika), "付け足し" (tsuketa-shi), "最後のノートに追加", "補足"
   - Chinese: "添加", "补充", "追加到最后一条笔记", "增补"
   - Arabic: "إضافة", "أضف إلى آخر ملاحظة", "تكميل", "إلحاق"
   - And ANY other language variation meaning "add/append"

2. FOLDER - Save to an existing folder (will create if doesn't exist)
   Recognize ALL variations of "folder/save to" in any language:
   - English: "folder [name]", "in folder [name]", "to folder [name]", "new [name]", "new folder [name]", "save to [name]"
   - German: "ordner [name]", "in ordner [name]", "neuer ordner [name]", "speichern in [name]", "mappe [name]"
   - Spanish: "carpeta [name]", "en carpeta [name]", "nueva carpeta [name]", "guardar en [name]", "directorio [name]"
   - French: "dossier [name]", "dans dossier [name]", "nouveau dossier [name]", "sauver dans [name]", "répertoire [name]"
   - Japanese: "フォルダ [name]", "[name]フォルダ", "新しいフォルダ [name]", "[name]に保存"
   - Chinese: "文件夹 [name]", "[name]文件夹", "新文件夹 [name]", "保存到[name]"
   - Arabic: "مجلد [name]", "في مجلد [name]", "مجلد جديد [name]", "حفظ في [name]"
   - And ANY other language variation meaning "folder/save to"

3. SET_TITLE - Set custom title for the note
   Recognize ALL variations of "title/set title" in any language:
   - English: "note with title [title]", "title [title]", "with title [title]", "call it [title]", "name it [title]"
   - German: "notiz mit titel [title]", "titel [title]", "mit titel [title]", "nennen [title]", "überschrift [title]"
   - Spanish: "nota con título [title]", "título [title]", "con título [title]", "llamar [title]", "nombrar [title]"
   - French: "note avec titre [title]", "titre [title]", "avec titre [title]", "appeler [title]", "nommer [title]"
   - Japanese: "タイトル [title]", "[title]というタイトル", "[title]と名付ける", "見出し [title]"
   - Chinese: "标题 [title]", "[title]标题", "命名为[title]", "题目 [title]"
   - Arabic: "عنوان [title]", "باسم [title]", "اسم [title]", "مسمى [title]"
   - And ANY other language variation meaning "title/set title"

CRITICAL RULES:
1. Only detect commands if confidence > 0.8 (high certainty it's intentional)
2. Commands typically appear at the START of transcription
3. Support natural variations and speech recognition errors (e.g., "Neue Journaling" = "new Journaling")
4. **IMPORTANT**: Recognize ALL synonyms, variations, and natural ways users express these commands in their language. Be flexible and understand semantic meaning, not just exact keywords.
5. Can detect MULTIPLE commands in one transcription (e.g., "new note with title Meeting in folder Work")
6. Extract remaining content after ALL commands
7. If text doesn't clearly match patterns, return NO commands (avoid false positives)
8. Be smart: "get together" is NOT "new", but "neue Tagebuch" or "new Journaling" IS a command
9. **FOLDER AUTO-CREATION**: All folder commands will automatically create the folder if it doesn't exist
10. **TITLE EXTRACTION**: When detecting title command, extract the COMPLETE title text (can be 2-10 words). Remove the title AND the command keyword from remainingContent. The title should be the phrase immediately after "title" keyword until a natural pause or next command.

11. **FOLDER EXTRACTION**: When detecting folder command, extract the COMPLETE folder name (can be 2-10 words). Remove the folder name AND the command keyword from remainingContent. The folder name should be the phrase immediately after "folder" keyword until a natural pause or next command.

12. **NATURAL PAUSE DETECTION**: Stop extracting title/folder names at natural pauses like:
   - Commas: "title grocery list, and today I went shopping" → title: "grocery list"
   - Leading commas: "title, grocery list and today I went shopping" → title: "grocery list"
   - Conjunctions: "folder learning and development then I read about..." → folder: "learning and development"
   - Next command keywords: "title meeting notes in folder work" → title: "meeting notes", folder: "work"
   - Sentence boundaries: "title weekly report. Today I completed..." → title: "weekly report"

COMBINED COMMAND EXAMPLES:
- "New note with title Meeting Notes in folder Work and here are my notes..."
  → Commands: [FOLDER("Work"), SET_TITLE("Meeting Notes")], Content: "and here are my notes..."
  
- "Title Morning Thoughts in folder Journal today was a good day"
  → Commands: [SET_TITLE("Morning Thoughts"), FOLDER("Journal")], Content: "today was a good day"

- "New Journaling I am very happy today"
  → Commands: [FOLDER("Journaling")], Content: "I am very happy today"

- "Title I love potatoes and today I went shopping"
  → Commands: [SET_TITLE("I love potatoes")], Content: "and today I went shopping"

- "title grocery list for the week and today I went shopping"
  → Commands: [SET_TITLE("grocery list for the week")], Content: "and today I went shopping"

- "folder learning and development then I read about new technologies"
  → Commands: [FOLDER("learning and development")], Content: "then I read about new technologies"

- "title meeting notes with John in folder work today we discussed the project"
  → Commands: [SET_TITLE("meeting notes with John"), FOLDER("work")], Content: "today we discussed the project"

- "title, grocery list and today I went shopping"
  → Commands: [SET_TITLE("grocery list")], Content: "today I went shopping"

- "title grocery list folder bananas and today I went shopping"
  → Commands: [SET_TITLE("grocery list"), FOLDER("bananas")], Content: "and today I went shopping"

MULTILINGUAL EXAMPLES:
- "addition, I need to buy milk" (English append)
  → Commands: [APPEND], Content: "I need to buy milk"

- "append to last note, meeting was productive" (English append)
  → Commands: [APPEND], Content: "meeting was productive"

- "Hinzufügen, ich heiße Klaus" (German append: "Add, my name is Klaus")
  → Commands: [APPEND], Content: "ich heiße Klaus"

- "Ergänzung. Heute war ein guter Tag" (German append: "Addition. Today was a good day")
  → Commands: [APPEND], Content: "Heute war ein guter Tag"

- "agregar a última nota, necesito comprar leche" (Spanish append)
  → Commands: [APPEND], Content: "necesito comprar leche"

- "ajouter à dernière note, rendez-vous demain" (French append)
  → Commands: [APPEND], Content: "rendez-vous demain"

- "folder work, today I had a meeting" (English folder)
  → Commands: [FOLDER("work")], Content: "today I had a meeting"

- "new folder personal, my thoughts about life" (English folder)
  → Commands: [FOLDER("personal")], Content: "my thoughts about life"

- "Ordner Arbeit, heute hatte ich ein Meeting" (German folder: "Folder work, today I had a meeting")
  → Commands: [FOLDER("Arbeit")], Content: "heute hatte ich ein Meeting"

- "neuer Ordner persönlich, meine Gedanken über das Leben" (German folder)
  → Commands: [FOLDER("persönlich")], Content: "meine Gedanken über das Leben"

- "carpeta trabajo, reunión con el equipo" (Spanish folder)
  → Commands: [FOLDER("trabajo")], Content: "reunión con el equipo"

- "nouveau dossier personnel, mes pensées sur la vie" (French folder)
  → Commands: [FOLDER("personnel")], Content: "mes pensées sur la vie"

- "title meeting notes, discussed the project" (English title)
  → Commands: [SET_TITLE("meeting notes")], Content: "discussed the project"

- "with title grocery list, need milk and bread" (English title)
  → Commands: [SET_TITLE("grocery list")], Content: "need milk and bread"

- "Titel Einkaufsliste, ich brauche Milch und Brot" (German title: "Title shopping list, I need milk and bread")
  → Commands: [SET_TITLE("Einkaufsliste")], Content: "ich brauche Milch und Brot"

- "mit Titel Besprechungsnotizen, Projekt besprochen" (German title)
  → Commands: [SET_TITLE("Besprechungsnotizen")], Content: "Projekt besprochen"

- "título lista de compras, necesito leche y pan" (Spanish title)
  → Commands: [SET_TITLE("lista de compras")], Content: "necesito leche y pan"

- "avec titre notes de réunion, projet discuté" (French title)
  → Commands: [SET_TITLE("notes de réunion")], Content: "projet discuté"

- "フォルダ 仕事 今日は会議がありました" (Japanese: "folder work today I had a meeting")
  → Commands: [FOLDER("仕事")], Content: "今日は会議がありました"

- "标题 购物清单 今天去买菜" (Chinese: "title shopping list today go shopping")
  → Commands: [SET_TITLE("购物清单")], Content: "今天去买菜"

- "مجلد العمل اليوم كان اجتماع" (Arabic: "folder work today was a meeting")
  → Commands: [FOLDER("العمل")], Content: "اليوم كان اجتماع"

- "addition 今天天气很好" (Mixed: English command + Chinese content)
  → Commands: [APPEND], Content: "今天天气很好"

⚠️ CRITICAL: The extracted title/folder names should NEVER appear in the remainingContent!

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
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',  // Use gpt-4o for better command detection
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,  // Low temperature for consistent detection
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI API failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final responseText = (data['choices'][0]['message']['content'] as String).trim();
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
    
    // Helper to extract name after keyword (handles various separators and multi-word names)
    String? extractNameAfterKeyword(String text, String keyword) {
      final afterKeyword = text.substring(keyword.length).trim();
      
      // Clean up leading punctuation (commas, colons, etc.)
      final cleanedAfterKeyword = afterKeyword.replaceAll(RegExp(r'^[,:\s]+'), '').trim();
      
      // Try different separators first
      if (cleanedAfterKeyword.contains(':')) {
        return cleanedAfterKeyword.substring(0, cleanedAfterKeyword.indexOf(':')).trim();
      }
      
      // Split into words for analysis
      final words = cleanedAfterKeyword.split(RegExp(r'\s+'));
      if (words.isEmpty) return null;
      
      // Enhanced stop words for natural pause detection
      final stopWords = [
        // Conjunctions
        'in', 'im', 'und', 'and', 'et', 'y', 'with', 'mit', 'avec', 'con',
        'then', 'dann', 'puis', 'entonces', 'also', 'auch', 'aussi', 'también',
        'but', 'aber', 'mais', 'pero', 'however', 'jedoch', 'cependant', 'sin embargo',
        // Command keywords - CRITICAL for chained commands
        'folder', 'ordner', 'dossier', 'carpeta', 'title', 'titel', 'titre', 'título',
        'new', 'neu', 'nouveau', 'nuevo', 'append', 'hinzufügen', 'ajouter', 'añadir',
        'in folder', 'in ordner', 'dans dossier', 'en carpeta',
        'to folder', 'zu ordner', 'au dossier', 'a carpeta',
        // Sentence boundaries
        'today', 'heute', 'aujourd\'hui', 'hoy', 'yesterday', 'gestern', 'hier', 'ayer',
        'tomorrow', 'morgen', 'demain', 'mañana', 'now', 'jetzt', 'maintenant', 'ahora',
        // Common transition words
        'so', 'also', 'daher', 'donc', 'por lo tanto', 'therefore', 'deshalb', 'donc', 'por tanto',
        'next', 'nächste', 'suivant', 'siguiente', 'finally', 'schließlich', 'enfin', 'finalmente'
      ];
      
      final nameWords = <String>[];
      final maxWords = 10; // Reasonable limit for title/folder names
      
      for (int i = 0; i < words.length && i < maxWords; i++) {
        final word = words[i].toLowerCase();
        
        // Stop at natural pauses
        if (stopWords.contains(word)) {
          break;
        }
        
        // Stop at punctuation that indicates sentence boundary
        if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
          // Include the word but remove punctuation
          final cleanWord = word.replaceAll(RegExp(r'[.!?]+$'), '');
          if (cleanWord.isNotEmpty) {
            nameWords.add(words[i].replaceAll(RegExp(r'[.!?]+$'), ''));
          }
          break;
        }
        
        // Stop at commas
        if (word.endsWith(',')) {
          final cleanWord = word.replaceAll(',', '');
          if (cleanWord.isNotEmpty) {
            nameWords.add(words[i].replaceAll(',', ''));
          }
          break;
        }
        
        nameWords.add(words[i]);
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
    
    // Check for folder commands (including "new" keywords) - but only if no title command was found
    // OR if we need to check for chained commands
    for (final langKeywords in _newFolderKeywords.values) {
      for (final keyword in langKeywords) {
        if (normalized.contains(keyword.toLowerCase())) {
          final keywordIndex = normalized.indexOf(keyword.toLowerCase());
          
          // Check if this keyword appears AFTER any existing commands
          bool isAfterExistingCommand = false;
          for (final existingCmd in commands) {
            final existingIndex = normalized.indexOf(existingCmd.originalKeyword.toLowerCase());
            if (keywordIndex > existingIndex) {
              isAfterExistingCommand = true;
              break;
            }
          }
          
          // Only process if it's after existing commands or no commands exist yet
          if (isAfterExistingCommand || commands.isEmpty) {
            final folderName = extractNameAfterKeyword(transcription.substring(keywordIndex), keyword);
            
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
    }
    
    // Check for folder assignment commands (without "new") - but only if no title command was found
    // OR if we need to check for chained commands
    if (commands.isEmpty || commands.any((cmd) => cmd.type == VoiceCommandType.setTitle)) {
      for (final langKeywords in _folderKeywords.values) {
        for (final keyword in langKeywords) {
          if (normalized.contains(keyword.toLowerCase())) {
            final keywordIndex = normalized.indexOf(keyword.toLowerCase());
            
            // Check if this keyword appears AFTER any existing commands
            bool isAfterExistingCommand = false;
            for (final existingCmd in commands) {
              final existingIndex = normalized.indexOf(existingCmd.originalKeyword.toLowerCase());
              if (keywordIndex > existingIndex) {
                isAfterExistingCommand = true;
                break;
              }
            }
            
            // Only process if it's after existing commands or no commands exist yet
            if (isAfterExistingCommand || commands.isEmpty) {
              final folderName = extractNameAfterKeyword(transcription.substring(keywordIndex), keyword);
              
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
    }
    
    // Extract remaining content by removing ALL detected command keywords and their values
    if (commands.isNotEmpty) {
      remainingContent = transcription;
      
      debugPrint('🧹 Starting content removal from: "$remainingContent"');
      debugPrint('   Commands to remove: ${commands.map((c) => '${c.originalKeyword} ${c.type == VoiceCommandType.setTitle ? c.noteTitle : c.folderName}').join(', ')}');
      
      // Process commands in reverse order to maintain correct indices
      final sortedCommands = List<VoiceCommand>.from(commands);
      sortedCommands.sort((a, b) {
        // Sort by position in transcription (if we can determine it)
        final aIndex = transcription.toLowerCase().indexOf(a.originalKeyword.toLowerCase());
        final bIndex = transcription.toLowerCase().indexOf(b.originalKeyword.toLowerCase());
        return bIndex.compareTo(aIndex); // Reverse order
      });
      
      for (final command in sortedCommands) {
        String? textToRemove;
        
        switch (command.type) {
          case VoiceCommandType.setTitle:
            if (command.noteTitle != null) {
              // Remove "title [title]" pattern - handle various separators
              textToRemove = '${command.originalKeyword} ${command.noteTitle}';
            }
            break;
            
          case VoiceCommandType.folder:
            if (command.folderName != null) {
              // Remove "folder [name]" or "new [name]" pattern - handle various separators
              textToRemove = '${command.originalKeyword} ${command.folderName}';
            }
            break;
            
          case VoiceCommandType.append:
            // Remove just the append keyword
            textToRemove = command.originalKeyword;
            break;
        }
        
        if (textToRemove != null) {
          final beforeRemoval = remainingContent;
          
          // Try multiple removal patterns to handle variations in punctuation and spacing
          final patterns = [
            // Pattern 1: Exact match with spaces
            RegExp(RegExp.escape(textToRemove), caseSensitive: false),
            
            // Pattern 2: With optional commas around the value
            RegExp('${RegExp.escape(command.originalKeyword)}\\s*,?\\s*${RegExp.escape(command.type == VoiceCommandType.setTitle ? command.noteTitle! : command.folderName!)}\\s*,?', caseSensitive: false),
            
            // Pattern 3: With any punctuation/spaces between keyword and value
            RegExp('${RegExp.escape(command.originalKeyword)}[,\\s]+${RegExp.escape(command.type == VoiceCommandType.setTitle ? command.noteTitle! : command.folderName!)}[,\\s]*', caseSensitive: false),
            
            // Pattern 4: More flexible - keyword followed by any non-word chars, then value
            RegExp('${RegExp.escape(command.originalKeyword)}[^a-zA-Z0-9]*${RegExp.escape(command.type == VoiceCommandType.setTitle ? command.noteTitle! : command.folderName!)}[^a-zA-Z0-9]*', caseSensitive: false),
            
            // Pattern 5: Handle "in folder" pattern specifically
            if (command.type == VoiceCommandType.folder && command.originalKeyword == 'folder')
              RegExp('in\\s+${RegExp.escape(command.folderName!)}[,\\s]*', caseSensitive: false),
            
            // Pattern 6: Handle "in folder" with commas
            if (command.type == VoiceCommandType.folder && command.originalKeyword == 'folder')
              RegExp('in\\s*,?\\s*${RegExp.escape(command.folderName!)}[,\\s]*', caseSensitive: false),
            
            // Pattern 7: Handle case where "in" might be left behind
            if (command.type == VoiceCommandType.folder)
              RegExp('in\\s*,?\\s*${RegExp.escape(command.folderName!)}[,\\s]*', caseSensitive: false),
          ];
          
          bool removed = false;
          for (final pattern in patterns.whereType<RegExp>()) {
            if (remainingContent.contains(pattern)) {
              remainingContent = remainingContent.replaceFirst(pattern, ' ').trim();
              removed = true;
              debugPrint('🧹 Removed command text with pattern: "$textToRemove"');
              debugPrint('   Before: "$beforeRemoval"');
              debugPrint('   After: "$remainingContent"');
              break;
            }
          }
          
          if (!removed) {
            debugPrint('⚠️ Failed to remove command text: "$textToRemove"');
            debugPrint('   Content: "$remainingContent"');
          }
        }
      }
      
      // Final cleanup - remove any remaining command-related patterns and extra spaces
      remainingContent = remainingContent
          .replaceAll(RegExp(r'^[,.\s]+'), '') // Remove leading punctuation and spaces
          .replaceAll(RegExp(r'^(and|und|et|y|then|dann|puis|entonces|also|auch|aussi|también)\s+'), '') // Remove leading conjunctions
          .replaceAll(RegExp(r'\s+(and|und|et|y|then|dann|puis|entonces|also|auch|aussi|también)\s+'), ' ') // Remove middle conjunctions
          .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single space
          .trim();
      
      // Additional cleanup for leftover command words
      remainingContent = remainingContent
          .replaceAll(RegExp(r'^(in|im|dans|en|zu|au|a)\s+'), '') // Remove leading prepositions
          .replaceAll(RegExp(r'\s+(in|im|dans|en|zu|au|a)\s+'), ' ') // Remove middle prepositions
          .replaceAll(RegExp(r'^[.,\s]+'), '') // Remove any remaining leading punctuation
          .trim();
      
      debugPrint('🧹 Final cleaned content: "$remainingContent"');
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

