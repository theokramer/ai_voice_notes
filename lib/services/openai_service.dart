import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_quill/quill_delta.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/app_language.dart';
import '../models/organization_suggestion.dart';
import '../feature_updates/ai_chat_overlay.dart';

/// Result from audio transcription including detected language
class TranscriptionResult {
  final String text;
  final String? detectedLanguage; // ISO 639-1 language code (e.g., 'en', 'de', 'es')

  TranscriptionResult({
    required this.text,
    this.detectedLanguage,
  });
}

class OpenAIService {
  final String apiKey;

  OpenAIService({required this.apiKey});

  /// Transcribe audio file to text using Whisper API
  /// 
  /// If [language] is provided, it hints Whisper for better accuracy.
  /// If omitted, Whisper automatically detects the language.
  /// Returns both the transcribed text and detected language code.
  Future<TranscriptionResult> transcribeAudio(String audioPath, {AppLanguage? language}) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = 'whisper-1';
      
      // Use verbose_json to get language detection info
      request.fields['response_format'] = 'verbose_json';
      
      // Add language parameter if provided for better transcription accuracy
      // If not provided, Whisper will automatically detect the language
      if (language != null) {
        request.fields['language'] = language.code;
        debugPrint('🎤 Transcribing with language hint: ${language.code}');
      } else {
        debugPrint('🎤 Transcribing with automatic language detection');
      }
      
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final text = data['text'] ?? '';
        final detectedLang = data['language'] as String?; // Whisper returns detected language
        
        debugPrint('✅ Transcription complete: ${text.length} chars, detected language: $detectedLang');
        
        return TranscriptionResult(
          text: text,
          detectedLanguage: detectedLang,
        );
      } else {
        throw Exception('Transcription failed: $responseBody');
      }
    } catch (e) {
      throw Exception('Error transcribing audio: $e');
    }
  }

  /// Generate a concise, well-structured summary from transcription (GPT-4o for quality)
  /// Creates a beautiful summary with key points, main ideas, and action items
  /// Returns structured plain text optimized for custom UI rendering
  Future<String> generateSummary(String transcription, {String? detectedLanguage}) async {
    try {
      // Get language name from ISO code for clearer instructions
      String? languageName;
      if (detectedLanguage != null) {
        final langMap = {
          'en': 'English',
          'de': 'German',
          'es': 'Spanish',
          'fr': 'French',
          'it': 'Italian',
          'pt': 'Portuguese',
          'nl': 'Dutch',
          'pl': 'Polish',
          'ru': 'Russian',
          'ja': 'Japanese',
          'zh': 'Chinese',
          'ko': 'Korean',
          'ar': 'Arabic',
        };
        languageName = langMap[detectedLanguage];
      }
      
      final prompt = '''You are an expert at creating concise, insightful summaries. Create a BEAUTIFUL, WELL-STRUCTURED summary that captures the essence of this note.

INPUT TRANSCRIPTION:
"$transcription"

🚨 CRITICAL RULE - LANGUAGE PRESERVATION:
${languageName != null ? 'The user spoke in $languageName (detected: $detectedLanguage). You MUST respond in $languageName ONLY.' : 'DETECT the language of the input text above and respond in THE EXACT SAME LANGUAGE.'}
- German input → German output
- English input → English output  
- Spanish input → Spanish output
DO NOT TRANSLATE. DO NOT SWITCH LANGUAGES.

🚨 CRITICAL RULE - STRUCTURED FORMAT:
Output in a SPECIFIC structure using these section markers:

[MAIN_TOPIC]
A single clear sentence describing what this note is about.

[KEY_POINTS]
- First key point or main idea
- Second key point or main idea
- Third key point or main idea
(Include 2-5 key points, each on a new line starting with -)

[ACTION_ITEMS]
- Action item 1
- Action item 2
(ONLY include this section if there are clear action items, todos, or things to do. Otherwise OMIT this section entirely.)

[CONTEXT]
Any additional important context, dates, people mentioned, or relevant details that provide understanding.
(ONLY include if there's meaningful context. Otherwise OMIT this section.)

SUMMARY REQUIREMENTS:
✓ 30-50% of original length (concise but comprehensive)
✓ Extract the most important information
✓ Remove filler words and redundancy
✓ Clear, direct language
✓ Preserve all important details, names, dates, numbers
✓ Each section must be clearly marked with [SECTION_NAME]
✓ Use plain text, no markdown (no **, no ##, no bullets except - for lists)

EXAMPLES:

Input: "So today I had a meeting with Sarah about the Q3 project. Um, she mentioned we need to finalize the budget by Friday. Also, we should schedule a follow-up next week to review the timeline."

Output:
[MAIN_TOPIC]
Meeting with Sarah about Q3 project budget and timeline.

[KEY_POINTS]
- Budget needs to be finalized by Friday
- Follow-up meeting required next week
- Discussion focused on project timeline review

[ACTION_ITEMS]
- Finalize Q3 project budget by Friday
- Schedule follow-up meeting for next week

[CONTEXT]
Meeting participants: Sarah. Timeline review is the main focus for the follow-up.

---

Input: "I've been thinking about learning to play guitar. There's this song I really love and I want to be able to play it someday."

Output:
[MAIN_TOPIC]
Interest in learning to play guitar to perform a favorite song.

[KEY_POINTS]
- Desire to learn guitar
- Motivated by a specific song
- Long-term personal goal

[CONTEXT]
Personal aspiration, no immediate timeline mentioned.

Return ONLY the structured summary with clear section markers. No explanations. No translations.''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o', // Use GPT-4o for high-quality summaries
          'messages': [
            {'role': 'system', 'content': 'You are a summary expert that creates concise, well-structured summaries using specific section markers. You NEVER translate or change the language of the input text. You always preserve the original language.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3, // Balanced for quality and consistency
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        debugPrint('Summary generation failed: ${response.body}');
        throw Exception('Failed to generate summary');
      }
    } catch (e) {
      debugPrint('Error generating summary: $e');
      throw Exception('Error generating summary: $e');
    }
  }

  /// Beautify raw transcription into structured note (GPT-4o for quality)
  /// Outputs clean plain text without any markdown formatting
  /// If detectedLanguage is provided (from Whisper), uses it to ensure language preservation
  Future<String> beautifyTranscription(String rawText, {String? detectedLanguage}) async {
    try {
      // Get language name from ISO code for clearer instructions
      String? languageName;
      if (detectedLanguage != null) {
        final langMap = {
          'en': 'English',
          'de': 'German',
          'es': 'Spanish',
          'fr': 'French',
          'it': 'Italian',
          'pt': 'Portuguese',
          'nl': 'Dutch',
          'pl': 'Polish',
          'ru': 'Russian',
          'ja': 'Japanese',
          'zh': 'Chinese',
          'ko': 'Korean',
          'ar': 'Arabic',
        };
        languageName = langMap[detectedLanguage];
      }
      
      final prompt = '''You are an expert note summarizer. Create a detailed, well-structured summary that improves readability while keeping the EXACT same language.

INPUT TEXT:
"$rawText"

🚨 CRITICAL RULE - LANGUAGE PRESERVATION:
${languageName != null ? 'The user spoke in $languageName (detected: $detectedLanguage). You MUST respond in $languageName ONLY.' : 'DETECT the language of the input text above and respond in THE EXACT SAME LANGUAGE.'}
- German input → German output
- English input → English output  
- Spanish input → Spanish output
- French input → French output
${languageName != null ? '\nCONFIRMED LANGUAGE: $languageName - DO NOT USE ANY OTHER LANGUAGE.' : ''}

DO NOT TRANSLATE. DO NOT SWITCH LANGUAGES. SAME LANGUAGE IN = SAME LANGUAGE OUT.

🚨 CRITICAL RULE - PLAIN TEXT ONLY:
Output PLAIN TEXT with NO markdown syntax or formatting characters.
- NO headings with ## or #
- NO bold with ** or __
- NO italics with * or _
- NO bullet points with - or *
- NO numbered lists with 1. 2. 3.
- NO blockquotes with >
- NO code blocks with ``` or `

Summary instructions:
- Remove filler words (um, uh, ah, so, well, like, you know, etc.)
- Fix self-corrections (keep only the corrected version)
- Organize into clear paragraphs by topic
- Add blank lines between different topics/sections
- Use proper capitalization and punctuation
- Make it flow naturally like written text, not spoken rambling
- Preserve ALL important information and details
- Structure with logical flow (introduction → main points → conclusion if applicable)
- If the input is a list of items, organize them clearly
- If the input is a story or explanation, make it coherent and well-structured

Examples of CORRECT behavior:
✓ Input (German): "Ähm, also heute war ein guter Tag. Ich meine, ich habe viel geschafft, weißt du."
  Output (German): "Mein Tag\n\nHeute war ein guter Tag. Ich habe viel geschafft."

✓ Input (English): "So um, I need to buy like milk and, uh, eggs and bread, you know."
  Output (English): "Shopping List\n\nI need to buy milk, eggs, and bread."

✓ Input (English): "Today I had a meeting with John. We discussed the project. Actually no, we discussed two projects. The first one is about..."
  Output (English): "Meeting with John\n\nToday I had a meeting with John where we discussed two projects. The first one is about..."

Examples of WRONG behavior:
✗ Output: "## My Day" ← NO! Don't use ##
✗ Output: "- milk" ← NO! Don't use -
✗ Output: "**important**" ← NO! Don't use **

Return ONLY the clean, detailed summary in PLAIN TEXT in the SAME language as input. No markdown. No explanations. No translations.''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o', // Use GPT-4o for better quality
          'messages': [
            {'role': 'system', 'content': 'You are a plain text formatter that NEVER uses markdown syntax or formatting characters. You only output clean, readable plain text while preserving the original language. NEVER translate or change the language of the input text.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.05, // Extremely low to ensure strict language preservation
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      } else {
        debugPrint('Beautification failed: ${response.body}');
        // Fallback: return raw text if beautification fails
        return rawText;
      }
    } catch (e) {
      debugPrint('Error beautifying transcription: $e');
      // Fallback: return raw text
      return rawText;
    }
  }

  /// Auto-organize a note with context awareness (GPT-4o-mini for speed)
  Future<AutoOrganizationResult> autoOrganizeNote({
    required Note note,
    required List<Folder> folders,
    required List<Note> recentNotes, // Last 5 notes for context
  }) async {
    try {
      // Build context from recent notes
      final recentContext = recentNotes.take(5).map((n) {
        return 'Note "${n.name}" in folder: ${n.folderId ?? "Unorganized"}';
      }).join('\n');

      // Build list of available folders
      final foldersList = folders.where((f) => !f.isSystem).map((f) {
        return '${f.id}|${f.name}|${f.icon}';
      }).join('\n');

      final prompt = '''Organize this note into the most appropriate folder.

NOTE TO ORGANIZE:
Name: "${note.name}"
Content preview: "${note.content.length > 200 ? note.content.substring(0, 200) : note.content}..."

RECENT CONTEXT (last notes recorded):
$recentContext

AVAILABLE FOLDERS (format: id|name|icon):
$foldersList

RULES:
1. If recent notes suggest a pattern (e.g., multiple notes about same topic), use same folder
2. STRONGLY prefer using existing folders, even if not perfect match (confidence > 0.7)
3. If no good match AND content is distinct new topic, suggest creating new folder
4. Only suggest new folder if confidence > 0.9 AND folder name is GENERIC and BROAD
5. Ask: "Could 10+ other future notes fit in this folder?" If no, don't create it
6. If uncertain (confidence < 0.7), return "Unorganized"
7. CRITICAL: ALWAYS use GENERIC, UNIVERSAL folder names - ignore user's previous specific patterns
8. AVOID time references (Weekly, Daily, Monthly) - remove them and use generic category
9. AVOID specific contexts - use broad categories that work for many notes

EXAMPLES OF CORRECT GENERIC NAMES:
✓ "Personal Thoughts" (not "Personal Reflections" or "Weekly Journal")
✓ "Work" (not "Work Notes" or "Office Updates")
✓ "Ideas" (not "Creative Ideas" or "Brainstorming")
✓ "Learning" (not "Study Notes" or "Course Material")
✓ "Planning" (not "Weekly Planning" or "Task Lists")

WRONG - TOO SPECIFIC:
✗ "Voting Experiences", "Grocery Shopping", "Meeting Notes Tuesday"

Return JSON (do NOT include icon - it will be auto-selected):
{
  "action": "use_existing" | "create_new" | "unorganized",
  "folderId": "id from list" | null,
  "folderName": "existing name" | "new folder name",
  "confidence": 0.0-1.0,
  "reasoning": "brief explanation"
}''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini', // Use mini for speed
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.2, // Low temperature for consistency
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'] as String;
        
        // Remove markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
          content = content.substring(7);
        } else if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        content = content.trim();
        
        try {
          final result = jsonDecode(content);
          final action = result['action'] as String;
          
          if (action == 'create_new') {
            return AutoOrganizationResult(
              createNewFolder: true,
              folderName: result['folderName'],
              suggestedFolderIcon: null, // Will use smart emoji selection
              confidence: (result['confidence'] ?? 0.8).toDouble(),
              reasoning: result['reasoning'] ?? '',
            );
          } else if (action == 'use_existing') {
            return AutoOrganizationResult(
              folderId: result['folderId'],
              folderName: result['folderName'],
              confidence: (result['confidence'] ?? 0.9).toDouble(),
              reasoning: result['reasoning'] ?? '',
            );
          } else {
            // Unorganized
            return AutoOrganizationResult(
              confidence: (result['confidence'] ?? 0.5).toDouble(),
              reasoning: result['reasoning'] ?? 'Uncertain classification',
            );
          }
        } catch (e) {
          debugPrint('Failed to parse auto-organize response: $e');
          return AutoOrganizationResult(
            confidence: 0.0,
            reasoning: 'Parse error',
          );
        }
      } else {
        throw Exception('Auto-organize request failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in auto-organize: $e');
      return AutoOrganizationResult(
        confidence: 0.0,
        reasoning: 'Error: $e',
      );
    }
  }

  /// Generate per-note organization suggestions (GPT-4o for quality)
  /// Returns one suggestion for EVERY note
  Future<List<NoteOrganizationSuggestion>> generatePerNoteOrganizationSuggestions({
    required List<Note> unorganizedNotes,
    required List<Folder> folders,
  }) async {
    try {
      if (unorganizedNotes.isEmpty) return [];

      // Build note summaries
      final notesSummary = unorganizedNotes.take(30).map((n) {
        final preview = n.content.length > 150 
            ? n.content.substring(0, 150) 
            : n.content;
        return '${n.id}|"${n.name}"|$preview...';
      }).join('\n');

      // Build folder list
      final foldersList = folders.where((f) => !f.isSystem).map((f) {
        return '${f.id}|${f.name}|${f.icon}';
      }).join('\n');

      final prompt = '''Analyze EVERY note and provide EXACTLY ONE suggestion for EACH note.

UNORGANIZED NOTES (format: id|name|preview):
$notesSummary

EXISTING FOLDERS (format: id|name|icon):
$foldersList

CRITICAL: You MUST return exactly ${unorganizedNotes.length} suggestions, ONE for EACH note listed above.

For each note, decide:
1. MOVE to existing folder (use targetFolderId and targetFolderName) - PREFER THIS
2. CREATE new folder (use newFolderName ONLY, icon will be auto-selected) - ONLY if confidence > 0.9
3. If UNCERTAIN (confidence < 0.6), still provide best guess but mark confidence low

FOLDER CREATION RULES (EXTREMELY IMPORTANT):
- STRONGLY prefer using existing folders, even if not perfect match
- Only suggest NEW folder if confidence > 0.9 AND folder name is GENERIC AND broad
- Ask yourself: "Could 10+ OTHER FUTURE notes reasonably fit in this folder?"
- CRITICAL: ALWAYS use GENERIC, UNIVERSAL names - IGNORE user's previous specific patterns
- AVOID time references (Weekly, Daily, Monthly) - remove them, use generic category only
- PREFER: "Personal Thoughts", "Work", "Ideas", "Learning", "Planning", "Health", "Finance"
- AVOID: overly specific contexts, time periods, or one-time events

CORRECT GENERIC NAMES:
✓ "Personal Thoughts" (not "Reflections", "Weekly Journal", "Daily Thoughts")
✓ "Work" (not "Work Notes", "Office Tasks", "Project Updates")
✓ "Planning" (not "Weekly Planning", "Task Lists", "Goal Setting")
✓ "Learning" (not "Study Notes", "Course Material")

WRONG - TOO SPECIFIC:
❌ "Reflections" → Too narrow, use "Personal Thoughts"
❌ "Voting Experiences" → One-time event, use "Personal Thoughts"
❌ "Grocery Shopping" → Too specific, use "Daily Tasks" or existing folder
❌ "Weekly Planning" → Has time reference, use "Planning"
❌ "Project X Notes" → Too specific, use "Work"

CORRECT EXAMPLES:
✓ "Personal Thoughts" (covers reflections, journal, diary, musings)
✓ "Work" (covers all work-related content)
✓ "Ideas" (covers brainstorming, concepts, thoughts)
✓ "Learning" (covers study notes, new knowledge, courses)

BATCH CONSOLIDATION (CRITICAL):
You are processing these ${unorganizedNotes.length} notes SEQUENTIALLY, not in parallel.
- When you suggest creating a new folder for note 1, CHECK if notes 2, 3, etc. could fit there too
- If note 2 could fit in the new folder you just suggested for note 1, PUT IT THERE
- DO NOT create "Reflections" for note 1 and "Journal" for note 2 - use ONE name like "Personal Thoughts"
- Before finalizing, REVIEW ALL your suggestions: if you created multiple new folders with similar meanings (like "Journal", "Reflections", "Diary", "Personal Notes"), CONSOLIDATE them into ONE folder with the most generic name

WRONG (creating similar folders):
❌ Note 1: create "Reflections" folder
❌ Note 2: create "Journal" folder
❌ Note 3: create "Diary" folder

CORRECT (consolidating to one generic folder):
✓ Note 1: create "Personal Thoughts" folder
✓ Note 2: use "Personal Thoughts" folder (same as note 1)
✓ Note 3: use "Personal Thoughts" folder (same as note 1)

Return JSON array with EXACTLY ${unorganizedNotes.length} objects (do NOT include icon - it will be auto-selected):
[
  {
    "noteId": "note id from list above",
    "type": "move" | "create_folder",
    "targetFolderId": "existing folder id" | null,
    "targetFolderName": "existing folder name" | null,
    "newFolderName": "name for new folder" | null,
    "reasoning": "brief explanation (1 sentence)",
    "confidence": 0.0-1.0
  }
]

Guidelines:
- High confidence (>0.8): Clear match to existing folder or obvious new generic category
- Medium confidence (0.6-0.8): Reasonable match but not perfect
- Low confidence (<0.6): Uncertain, needs user review
- ONLY suggest new folders when NO existing folder is remotely suitable AND name is generic
- Group similar topics in this batch together by suggesting SAME new folder name (exact match)''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o', // Use GPT-4o for better analysis
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 3000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'] as String;
        
        // Remove markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
          content = content.substring(7);
        } else if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        content = content.trim();
        
        debugPrint('Cleaned AI response for parsing (${content.length} chars)');
        
        try {
          final suggestions = jsonDecode(content) as List;
          debugPrint('Parsed ${suggestions.length} suggestions for ${unorganizedNotes.length} notes');
          
          return suggestions.map((s) {
            final typeStr = s['type'] as String;
            OrganizationSuggestionType type;
            switch (typeStr) {
              case 'create_folder':
                type = OrganizationSuggestionType.createFolder;
                break;
              default:
                type = OrganizationSuggestionType.move;
            }

            return NoteOrganizationSuggestion(
              noteId: s['noteId'],
              type: type,
              targetFolderId: s['targetFolderId'],
              targetFolderName: s['targetFolderName'],
              newFolderName: s['newFolderName'],
              newFolderIcon: null, // Will use smart emoji selection
              reasoning: s['reasoning'] ?? '',
              confidence: (s['confidence'] ?? 0.5).toDouble(),
            );
          }).toList();
        } catch (e) {
          debugPrint('Failed to parse per-note suggestions: $e');
          return [];
        }
      } else {
        throw Exception('Per-note suggestions request failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error generating per-note suggestions: $e');
      return [];
    }
  }

  /// Generate tags for a note
  Future<List<String>> generateTags(Note note) async {
    try {
      if (note.content.isEmpty) return [];

      // Limit text length to avoid token issues
      final textToAnalyze = note.content.length > 1000 
          ? note.content.substring(0, 1000) 
          : note.content;

      final prompt = 'Generate 3-5 keyword tags (1-2 words) for: "$textToAnalyze"\nJSON array: ["tag1","tag2",...]';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'] as String;
        
        // Remove markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
          content = content.substring(7);
        } else if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        content = content.trim();
        
        try {
          final tags = List<String>.from(jsonDecode(content));
          return tags.take(5).toList();
        } catch (e) {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Generate a short, descriptive title from note content (GPT-4o-mini for speed)
  /// 
  /// [folderName] optional parameter to avoid redundant titles
  /// (e.g., if folder is "Todo", don't generate title "Todo: Buy Milk")
  /// [detectedLanguage] ensures title is in same language as content
  Future<String> generateNoteTitle(String content, {String? folderName, String? detectedLanguage}) async {
    try {
      // Get plain text from content (might be Quill JSON)
      String plainText = content;
      try {
        final json = jsonDecode(content);
        // If it's Quill format, extract plain text using Delta
        final delta = Delta.fromJson(json as List);
        // Extract text from delta operations
        final buffer = StringBuffer();
        for (final op in delta.toList()) {
          if (op.data is String) {
            buffer.write(op.data);
          }
        }
        plainText = buffer.toString();
      } catch (e) {
        // If not JSON, use as-is
      }
      
      // Limit to first 500 characters for title generation
      final textSample = plainText.length > 500 
          ? plainText.substring(0, 500) 
          : plainText;
      
      if (textSample.trim().isEmpty) {
        return 'Voice Note ${DateTime.now().toString().substring(11, 16)}';
      }
      
      // Build context hint if folder name is provided
      final folderContext = folderName != null && folderName != 'Unorganized'
          ? '\nFolder context: This note will be saved in the "$folderName" folder.'
          : '';
      
      // Get language name from detected language code
      String? languageInstruction;
      if (detectedLanguage != null) {
        final langMap = {
          'en': 'English',
          'de': 'German',
          'es': 'Spanish',
          'fr': 'French',
          'it': 'Italian',
          'pt': 'Portuguese',
          'nl': 'Dutch',
          'pl': 'Polish',
          'ru': 'Russian',
          'ja': 'Japanese',
          'zh': 'Chinese',
          'ko': 'Korean',
          'ar': 'Arabic',
        };
        final langName = langMap[detectedLanguage];
        if (langName != null) {
          languageInstruction = '\n\nCRITICAL: The note content is in $langName. You MUST generate the title in $langName as well. DO NOT translate or change the language.';
        }
      }
      
      final prompt = '''Generate a short, descriptive title (3-6 words) for this note.

Note content:
"$textSample"$folderContext${languageInstruction ?? ''}

Rules:
- Maximum 6 words
- Descriptive and specific
- No quotes or punctuation
- Title case (capitalize first letter of each word)${folderName != null && folderName != 'Unorganized' ? '\n- DO NOT include "$folderName" in the title (it\'s redundant with the folder name)' : ''}
${detectedLanguage != null ? '- IMPORTANT: Generate the title in the SAME language as the note content' : ''}

Return ONLY the title, nothing else.''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini', // Fast model for titles
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 20,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['choices'][0]['message']['content'] as String;
        return title.trim().replaceAll('"', '').replaceAll("'", '');
      } else {
        debugPrint('Title generation failed: ${response.body}');
        return 'Voice Note ${DateTime.now().toString().substring(11, 16)}';
      }
    } catch (e) {
      debugPrint('Error generating title: $e');
      return 'Voice Note ${DateTime.now().toString().substring(11, 16)}';
    }
  }

  /// Chat completion for AI assistant with action detection
  Future<AIChatResponse> chatCompletion({
    required String message,
    required List<Map<String, String>> history,
    required List<Note> notes,
    List<Folder>? folders,
  }) async {
    try {
      // Format notes context with IDs for actions
      final notesContext = notes.map((note) {
        final preview = note.content.length > 200 
            ? note.content.substring(0, 200) 
            : note.content;
        return '[ID:${note.id}] "${note.name}" (folder: ${note.folderId ?? "unorganized"}): $preview';
      }).take(30).join('\n');

      // Format folders context
      final foldersContext = folders != null && folders.isNotEmpty
          ? folders.where((f) => !f.isSystem).map((f) => '[FOLDER:${f.id}] "${f.name}" ${f.icon}').join('\n')
          : 'No folders yet';

      // Build conversation history
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': '''You are a personal notes assistant with EXCLUSIVE focus on the user's notes.

**CRITICAL: Always respond in the same language as the user's message.**

**YOUR CAPABILITIES:**
1. Answer questions by searching user's notes
2. Detect when user wants to perform actions on notes
3. Provide actionable suggestions with buttons

**USER'S NOTES DATABASE:**
$notesContext

**USER'S FOLDERS:**
$foldersContext

**ACTION DETECTION - Detect these intents:**
- "create note about X" / "make a note" → create_note
- "add this to [note name]" / "append to note" → add_to_note  
- "move [note] to [folder]" → move_note
- "create folder for X" → create_folder
- "summarize our conversation" / "create note from this chat" → summarize_chat
- "pin [note name]" → pin_note
- "delete [note name]" → delete_note

**RESPONSE FORMAT:**
You MUST respond with STRICTLY VALID JSON - NO COMMENTS ALLOWED!

CORRECT format:
{
  "text": "Your conversational response (2-3 sentences)",
  "noteCitations": ["noteId1", "noteId2"],
  "action": {
    "type": "create_note|add_to_note|move_note|create_folder|summarize_chat|pin_note|delete_note",
    "description": "Clear description of what will happen",
    "buttonLabel": "Short action label (2-4 words)",
    "data": {}
  }
}

Data field examples (choose based on action type):
- create_note: {"noteName": "Name", "noteContent": "", "folderId": "id"}
- add_to_note: {"noteId": "id", "contentToAdd": "text"}
- move_note: {"noteId": "id", "targetFolderId": "id", "targetFolderName": "name"}
- create_folder: {"folderName": "name"}
- summarize_chat: {}
- pin_note: {"noteId": "id"}
- delete_note: {"noteId": "id"}

**CRITICAL RULES:**
- NO COMMENTS in JSON (no // or /* */)
- NO trailing commas
- MUST be valid JSON that can be parsed
- If NO action needed, set "action": null
- In "text", reference notes using [NOTE:noteId] format
- Only suggest actions that are POSSIBLE with available data
- Use IDs from the notes/folders database above
- Keep responses concise and helpful

**EXAMPLES:**

User: "What did I note about the meeting?"
Response:
{
  "text": "In your note [NOTE:abc123], you mentioned the Q3 project deadline is Friday.",
  "noteCitations": ["abc123"],
  "action": null
}

User: "Create a note about grocery shopping"
Response:
{
  "text": "I'll create a new note for your grocery shopping list.",
  "noteCitations": [],
  "action": {
    "type": "create_note",
    "description": "Create a new note titled 'Grocery Shopping'",
    "buttonLabel": "Create Note",
    "data": {
      "noteName": "Grocery Shopping",
      "noteContent": ""
    }
  }
}

User: "Add buy milk to my shopping list"
Response:
{
  "text": "I found your shopping list note. I'll add 'buy milk' to it.",
  "noteCitations": ["xyz789"],
  "action": {
    "type": "add_to_note",
    "description": "Add 'buy milk' to Shopping List",
    "buttonLabel": "Add to Note",
    "data": {
      "noteId": "xyz789",
      "contentToAdd": "buy milk"
    }
  }
}'''
        },
        ...history,
        {'role': 'user', 'content': message},
      ];

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'] as String;
        
        // Clean up markdown code blocks if present
        content = content.trim();
        if (content.startsWith('```json')) {
          content = content.substring(7);
        } else if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        content = content.trim();
        
        // Remove any JSON comments (// and /* */) that AI might have added
        content = content.replaceAll(RegExp(r'//.*?(?=\n|$)'), ''); // Remove // comments
        content = content.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ''); // Remove /* */ comments
        content = content.trim();
        
        // Parse JSON response
        dynamic jsonResponse;
        try {
          jsonResponse = jsonDecode(content);
        } catch (e) {
          debugPrint('JSON parsing error: $e');
          debugPrint('Content that failed to parse: $content');
          // Return fallback response without action
          return AIChatResponse(
            text: data['choices'][0]['message']['content'] as String,
            noteCitations: [],
            action: null,
          );
        }
        final responseText = jsonResponse['text'] as String;
        final noteCitationIds = (jsonResponse['noteCitations'] as List?)?.cast<String>() ?? [];
        final actionData = jsonResponse['action'];
        
        // Parse note citations
        final noteCitationRegex = RegExp(r'\[NOTE:([^\]]+)\]');
        final citations = <NoteCitation>[];
        
        // Add citations from JSON
        for (final noteId in noteCitationIds) {
          final note = notes.firstWhere(
            (n) => n.id == noteId,
            orElse: () => notes.first,
          );
          citations.add(NoteCitation(
            noteId: note.id,
            noteName: note.name,
          ));
        }
        
        // Also parse citations from text
        final citationMatches = noteCitationRegex.allMatches(responseText);
        for (final match in citationMatches) {
          final noteId = match.group(1);
          if (noteId != null && !noteCitationIds.contains(noteId)) {
            final note = notes.firstWhere(
              (n) => n.id == noteId,
              orElse: () => notes.first,
            );
            citations.add(NoteCitation(
              noteId: note.id,
              noteName: note.name,
            ));
          }
        }
        
        // Remove citation tags from response text
        final cleanText = responseText.replaceAllMapped(noteCitationRegex, (match) {
          final noteId = match.group(1);
          final note = notes.firstWhere(
            (n) => n.id == noteId,
            orElse: () => notes.first,
          );
          return '"${note.name}"';
        });

        // Parse action if present
        ChatAction? action;
        if (actionData != null && actionData is Map) {
          action = ChatAction(
            type: actionData['type'] as String,
            description: actionData['description'] as String,
            buttonLabel: actionData['buttonLabel'] as String,
            data: Map<String, dynamic>.from(actionData['data'] as Map),
          );
        }

        return AIChatResponse(
          text: cleanText,
          noteCitations: citations,
          action: action,
        );
      } else {
        throw Exception('Chat completion failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error in chat completion: $e');
      // Fallback to simple response
      return AIChatResponse(
        text: 'I encountered an error processing your request. Please try again.',
        noteCitations: [],
        action: null,
      );
    }
  }

  /// Summarize chat history into a coherent note
  Future<String> summarizeChatHistory(List<ChatMessage> messages) async {
    try {
      // Build conversation text
      final conversationText = messages.map((m) {
        final role = m.isUser ? 'User' : 'AI';
        return '$role: ${m.text}';
      }).join('\n\n');

      final prompt = '''Summarize this conversation between a user and their AI notes assistant into a well-structured note.

CONVERSATION:
$conversationText

Create a comprehensive summary that:
- Captures all important points discussed
- Includes any questions asked and answers provided
- Lists any action items or decisions
- Organizes information logically
- Uses clear headings and bullet points

Format as plain text with clear sections. Make it useful as a reference note.

Return ONLY the summary, nothing else.''';

      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': 'You are an expert at creating clear, comprehensive summaries of conversations.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['choices'][0]['message']['content'] as String;
        return summary.trim();
      } else {
        throw Exception('Summary generation failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error summarizing chat: $e');
      throw Exception('Error summarizing chat: $e');
    }
  }
}

class AIChatResponse {
  final String text;
  final List<NoteCitation> noteCitations;
  final ChatAction? action;

  AIChatResponse({
    required this.text,
    this.noteCitations = const [],
    this.action,
  });
}

class NoteCitation {
  final String noteId;
  final String noteName;

  NoteCitation({
    required this.noteId,
    required this.noteName,
  });
}
