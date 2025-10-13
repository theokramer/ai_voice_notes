import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_quill/quill_delta.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/app_language.dart';
import '../models/organization_suggestion.dart';

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

  /// Beautify raw transcription into structured note (GPT-4o for quality)
  /// Outputs clean plain text without any markdown formatting
  Future<String> beautifyTranscription(String rawText) async {
    try {
      final prompt = '''You are a note formatter. Your ONLY job is to format text nicely while keeping the EXACT same language.

INPUT TEXT:
"$rawText"

🚨 CRITICAL RULE - LANGUAGE PRESERVATION:
DETECT the language of the input text above and respond in THE EXACT SAME LANGUAGE.
- German input → German output
- English input → English output  
- Spanish input → Spanish output
- French input → French output

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

Formatting instructions:
- Use line breaks to separate paragraphs and sections
- Use proper capitalization and punctuation
- Add blank lines between different topics/sections
- Fix any obvious transcription errors
- Preserve all information from the original text
- Keep it concise, clear, and easy to read
- Structure with natural text flow

Examples of CORRECT behavior:
✓ Input (German): "Heute war ein guter Tag. Ich habe viel geschafft."
  Output (German): "Mein Tag\n\nHeute war ein guter Tag. Ich habe viel geschafft."

✓ Input (English): "Today was a good day. I accomplished a lot."
  Output (English): "My Day\n\nToday was a good day. I accomplished a lot."

✓ Input (English): "I need to buy milk eggs and bread"
  Output (English): "Shopping List\n\nmilk\neggs\nbread"

Examples of WRONG behavior:
✗ Output: "## My Day" ← NO! Don't use ##
✗ Output: "- milk" ← NO! Don't use -
✗ Output: "**important**" ← NO! Don't use **

Return ONLY the formatted plain text in the SAME language as input. No markdown. No explanations. No translations.''';

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
            {'role': 'system', 'content': 'You are a plain text formatter that NEVER uses markdown syntax or formatting characters. You only output clean, readable plain text while preserving the original language.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1, // Very low to ensure strict language preservation
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
4. Only suggest new folder if confidence > 0.9 AND folder name is GENERIC
5. Ask: "Could 10+ other future notes fit in this folder?" If no, don't create it
6. If uncertain (confidence < 0.7), return "Unorganized"
7. AVOID specific folder names like "Voting Experiences" - prefer generic like "Personal Thoughts"

Return JSON:
{
  "action": "use_existing" | "create_new" | "unorganized",
  "folderId": "id from list" | null,
  "folderName": "existing name" | "new folder name",
  "suggestedIcon": "emoji for new folder" | null,
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
              suggestedFolderIcon: result['suggestedIcon'] ?? '📁',
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
2. CREATE new folder (use newFolderName and newFolderIcon) - ONLY if confidence > 0.9
3. If UNCERTAIN (confidence < 0.6), still provide best guess but mark confidence low

FOLDER CREATION RULES (EXTREMELY IMPORTANT):
- STRONGLY prefer using existing folders, even if not perfect match
- Only suggest NEW folder if confidence > 0.9 AND folder name is GENERIC AND broad
- Ask yourself: "Could 10+ OTHER FUTURE notes reasonably fit in this folder?"
- PREFER generic, broad categories like "Personal Thoughts", "Work", "Ideas", "Learning"
- AVOID overly specific folders like "Voting Experiences", "Grocery Trip May 2024", "Meeting Notes Tuesday"

WRONG EXAMPLES (too specific):
❌ "Reflections" → Too narrow, use "Personal Thoughts"
❌ "Voting Experiences" → Too specific, use "Journaling" or "Personal Thoughts"  
❌ "Grocery Shopping" → Too specific, use "Daily Tasks" or existing folder
❌ "Project X Notes" → Too specific, use "Work Notes"

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

Return JSON array with EXACTLY ${unorganizedNotes.length} objects:
[
  {
    "noteId": "note id from list above",
    "type": "move" | "create_folder",
    "targetFolderId": "existing folder id" | null,
    "targetFolderName": "existing folder name" | null,
    "newFolderName": "name for new folder" | null,
    "newFolderIcon": "emoji for new folder" | null,
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
              newFolderIcon: s['newFolderIcon'] ?? '📁',
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
  Future<String> generateNoteTitle(String content) async {
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
      
      final prompt = '''Generate a short, descriptive title (3-6 words) for this note.

Note content:
"$textSample"

Rules:
- Maximum 6 words
- Descriptive and specific
- No quotes or punctuation
- Title case (capitalize first letter of each word)

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

  /// Chat completion for AI assistant (existing feature)
  Future<AIChatResponse> chatCompletion({
    required String message,
    required List<Map<String, String>> history,
    required List<Note> notes,
  }) async {
    try {
      // Format notes context with IDs for actions
      final notesContext = notes.map((note) {
        final preview = note.content.length > 200 
            ? note.content.substring(0, 200) 
            : note.content;
        return '[ID:${note.id}] "${note.name}": $preview';
      }).take(30).join('\n');

      // Build conversation history
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': '''You are an intelligent AI assistant with direct access to the user's personal notes.

**IMPORTANT: Always respond in the same language as the user's message. If the user writes in German, respond in German. If they write in English, respond in English. Match their language exactly.**

**PRIORITY HANDLING:**
1. ALWAYS check the user's notes first for relevant information
2. If notes contain relevant info → Use them prominently in your response
3. If notes don't have the answer → Help with general knowledge
4. When user asks vague questions, scan notes for context clues

**YOUR NOTES DATABASE:**
$notesContext

**RESPONSE STYLE:**
- Be conversational and concise (2-3 sentences)
- When referencing notes, use this format: "In your note [NOTE:noteId]..." where noteId is from the [ID:xxx] in the notes database
- If notes are sparse, offer to help organize or add information
- Proactively suggest organizing scattered information

Focus on being a smart assistant that leverages their notes to provide better, personalized answers.'''
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
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        // Parse note citations
        final noteCitationRegex = RegExp(r'\[NOTE:([^\]]+)\]');
        final citations = <NoteCitation>[];
        final citationMatches = noteCitationRegex.allMatches(content);
        
        for (final match in citationMatches) {
          final noteId = match.group(1);
          if (noteId != null) {
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
        final responseText = content.replaceAllMapped(noteCitationRegex, (match) {
          final noteId = match.group(1);
          final note = notes.firstWhere(
            (n) => n.id == noteId,
            orElse: () => notes.first,
          );
          return '"${note.name}"';
        });

        return AIChatResponse(
          text: responseText,
          noteCitations: citations,
        );
      } else {
        throw Exception('Chat completion failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error in chat completion: $e');
    }
  }
}

class AIChatResponse {
  final String text;
  final List<NoteCitation> noteCitations;

  AIChatResponse({
    required this.text,
    this.noteCitations = const [],
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
