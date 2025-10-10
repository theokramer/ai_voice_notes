import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note.dart';

class OpenAIService {
  final String apiKey;

  OpenAIService({required this.apiKey});

  Future<String> transcribeAudio(String audioPath) async {
    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = 'whisper-1';
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['text'] ?? '';
      } else {
        throw Exception('Transcription failed: $responseBody');
      }
    } catch (e) {
      throw Exception('Error transcribing audio: $e');
    }
  }

  Future<HeadlineMatch> findOrCreateHeadline(
    String transcribedText,
    Note note,
  ) async {
    try {
      // Detect language from note name and recent entries for multi-language support
      final recentEntries = note.headlines
          .expand((h) => h.entries)
          .take(3)
          .map((e) => e.text)
          .join(' ');
      final contextText = '${note.name} $recentEntries';
      
      // Format existing headlines as numbered list for exact copying
      final existingHeadlinesList = note.headlines
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. "${entry.value.title}"')
          .join('\n');
      
      // Count entries per headline for usage context
      final headlineUsage = note.headlines
          .map((h) => '  - "${h.title}" (${h.entries.length} entries)')
          .join('\n');

      // Balanced prompt with note context and semantic matching
      final prompt = existingHeadlinesList.isEmpty
          ? '''Note: "${note.name}"
Text: "$transcribedText"

CONTEXT-AWARE HEADLINE CREATION:
Your headline should be ONE LEVEL MORE SPECIFIC than the note title.

Examples:
- Note "Daily Notes" (broad) → Create broad headlines: "Tools", "Ideas", "Work"
- Note "App Development" (specific) → Create specific headlines: "Development Tools", "Feature Ideas", "Bug Fixes"
- Note "Personal" (broad) → Create broad headlines: "Goals", "Thoughts", "Planning"
- Note "Marketing Strategy" (specific) → Create specific headlines: "Content Ideas", "Campaign Plans", "Analytics"

Think: What category fits this text that's slightly more specific than "${note.name}"?

JSON: {"action":"create_new","headline":"..."}'''
          : '''Note: "${note.name}"
New text to categorize: "$transcribedText"

EXISTING HEADLINES IN THIS NOTE:
$existingHeadlinesList

Current usage:
$headlineUsage

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TASK: Decide if this text belongs under an existing headline or needs a new one.

CRITICAL INSTRUCTION:
When you choose "use_existing", you MUST copy the headline EXACTLY character-for-character from the numbered list above. NO modifications, translations, or paraphrasing allowed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DECISION CRITERIA:
✓ Is this text about the SAME TOPIC as an existing headline? → use_existing (copy exact headline)
✗ Is this a completely DIFFERENT subject/context? → create_new (broad, general headline)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CORRECT MATCHES (use_existing with EXACT headline copy):

✓ Headline "App Development" + text "working on login feature"
  → {"action":"use_existing","headline":"App Development"}

✓ Headline "App Development" + text "fixed database bug"
  → {"action":"use_existing","headline":"App Development"}

✓ Headline "App Development" + text "planning new API endpoints"
  → {"action":"use_existing","headline":"App Development"}

✓ Headline "Music" + text "listened to new jazz album"
  → {"action":"use_existing","headline":"Music"}

✓ Headline "Music" + text "practicing guitar scales"
  → {"action":"use_existing","headline":"Music"}

✓ Headline "Work" + text "team standup discussion"
  → {"action":"use_existing","headline":"Work"}

✓ Headline "Shopping" + text "need to buy groceries tomorrow"
  → {"action":"use_existing","headline":"Shopping"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CORRECT NON-MATCHES (create_new with broad headline):

✗ Headline "App Development" + text "buy groceries and milk"
  → {"action":"create_new","headline":"Shopping"}

✗ Headline "Music" + text "team meeting notes for project"
  → {"action":"create_new","headline":"Work"}

✗ Headline "Work Tasks" + text "planning summer vacation"
  → {"action":"create_new","headline":"Travel"}

✗ Headline "Shopping" + text "workout routine for abs"
  → {"action":"create_new","headline":"Fitness"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONTEXT-AWARE HEADLINE CREATION:
Headline specificity should match the note title's specificity level.

For BROAD note titles (e.g., "Daily Notes", "Personal", "Work"):
✓ Create BROAD headlines: "Tools", "Ideas", "Tasks", "Notes"
❌ Don't be too specific: "Analytics Tools", "Feature Ideas"

For SPECIFIC note titles (e.g., "App Development", "Marketing Strategy"):
✓ Create MORE SPECIFIC headlines: "Development Tools", "Feature Ideas", "Bug Fixes"
❌ Don't be too generic: "Tools", "Ideas" (not specific enough)

Examples by note context:
- Note "Daily Notes" + text about SensorTower → Headline: "Tools"
- Note "App Development" + text about SensorTower → Headline: "Development Tools" or "Analytics"
- Note "Personal" + text about ideas → Headline: "Ideas"
- Note "Product Strategy" + text about ideas → Headline: "Feature Ideas" or "Strategy Ideas"

Rule: Headlines should be ONE LEVEL MORE SPECIFIC than the note title.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRITICAL RULES:
❌ DON'T create headline variations
❌ DON'T match unrelated topics
❌ DON'T rephrase when using existing (copy EXACTLY)
❌ DON'T be specific - stay BROAD and GENERAL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return JSON only: {"action":"use_existing"/"create_new","headline":"EXACT_TEXT_OR_NEW_HEADLINE"}''';

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
            {
              'role': 'system',
              'content': '''You are a smart note organizer. Your job: decide if new text fits an existing headline or needs a new one.

LANGUAGE: Preserve the language of existing headlines (don't translate them).

CRITICAL RULES:
1. When using "use_existing": copy the headline EXACTLY from the numbered list. Character-for-character.
2. When creating new headlines: Match the specificity to the note's context.
   - CONTEXT-AWARE SPECIFICITY: Headlines should be ONE LEVEL MORE SPECIFIC than the note title.
   - Note "Daily Notes" (broad) → Use broad headlines: "Tools", "Ideas"
   - Note "App Development" (specific) → Use specific headlines: "Development Tools", "Feature Ideas"

BALANCE:
- Group related content (same topic) → use_existing
- Separate unrelated content (different topics) → create_new

Note context: "${note.name}"
Recent content: "${contextText.length > 100 ? contextText.substring(0, 100) : contextText}..."'''
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 Full API Response: ${response.body}');
        
        final content = data['choices'][0]['message']['content'];
        print('🔍 AI Response Content: "$content"');
        
        // Check if content is empty or null
        if (content == null || content.toString().trim().isEmpty) {
          print('❌ AI returned empty response! Falling back to default.');
          return HeadlineMatch(
            action: HeadlineAction.createNew,
            headline: 'Notes',
          );
        }
        
        // Try to parse the JSON response
        try {
          final result = jsonDecode(content);
          final action = result['action'] == 'use_existing'
              ? HeadlineAction.useExisting
              : HeadlineAction.createNew;
          final headline = result['headline'] as String;
          
          // Debug logging: check if AI returned exact match
          if (action == HeadlineAction.useExisting) {
            final existingTitles = note.headlines.map((h) => h.title).toList();
            final exactMatch = existingTitles.any(
              (title) => title.toLowerCase() == headline.toLowerCase()
            );
            if (!exactMatch) {
              print('⚠️ HEADLINE MISMATCH WARNING:');
              print('   AI returned: "$headline"');
              print('   Available: ${existingTitles.join(", ")}');
              print('   This will create a duplicate headline!');
            } else {
              print('✓ Headline match successful: "$headline"');
            }
          } else {
            print('✓ Creating new headline: "$headline"');
          }
          
          return HeadlineMatch(
            action: action,
            headline: headline,
          );
        } catch (e) {
          print('❌ Failed to parse AI response: $content');
          print('   Error: $e');
          print('   Response was: ${content.runtimeType}');
          // If parsing fails, create a new generic headline
          return HeadlineMatch(
            action: HeadlineAction.createNew,
            headline: 'Notes',
          );
        }
      } else {
        throw Exception('GPT request failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Headline matching error: $e');
      // Fallback: create a default headline
      return HeadlineMatch(
        action: HeadlineAction.createNew,
        headline: 'Notes',
      );
    }
  }

  Future<AIChatResponse> chatCompletion({
    required String message,
    required List<Map<String, String>> history,
    required List<Note> notes,
  }) async {
    try {
      // Format notes context with IDs for actions
      final notesContext = notes.map((note) {
        final entries = note.headlines.expand((h) => h.entries).map((e) => e.text).take(5).join(' | ');
        return '[ID:${note.id}] "${note.name}": $entries';
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

**ACTIONS YOU CAN SUGGEST:**
End your response with [ACTION:type:data] when appropriate:
- create_note:New Note Name
- add_entry:noteId:text to add
- move_entry:sourceNoteId:targetNoteId:entryId

NOTE: Use the exact [ID:xxx] values from the notes list above when specifying noteIds in actions.

**WHEN TO SUGGEST ACTIONS:**
- User shares new info → suggest add_entry or create_note

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

        // Parse action if present
        final actionRegex = RegExp(r'\[ACTION:(\w+):(.+?)\]');
        final actionMatch = actionRegex.firstMatch(content);

        String responseText = content;
        String? actionType;
        String? actionData;

        if (actionMatch != null) {
          actionType = actionMatch.group(1);
          actionData = actionMatch.group(2);
          // Remove action tag from response text
          responseText = content.replaceAll(actionRegex, '').trim();
        }
        
        // Parse note citations
        final noteCitationRegex = RegExp(r'\[NOTE:([^\]]+)\]');
        final citations = <NoteCitation>[];
        final citationMatches = noteCitationRegex.allMatches(responseText);
        
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
        responseText = responseText.replaceAllMapped(noteCitationRegex, (match) {
          final noteId = match.group(1);
          final note = notes.firstWhere(
            (n) => n.id == noteId,
            orElse: () => notes.first,
          );
          return '"${note.name}"';
        });

        return AIChatResponse(
          text: responseText,
          actionType: actionType,
          actionData: actionData,
          noteCitations: citations,
        );
      } else {
        throw Exception('Chat completion failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error in chat completion: $e');
    }
  }

  Future<List<String>> generateTags(Note note) async {
    try {
      if (note.headlines.isEmpty) return [];

      // Collect all text content from the note
      final allText = note.headlines
          .expand((h) => h.entries)
          .map((e) => e.text)
          .join(' ');

      if (allText.trim().isEmpty) return [];

      // Limit text length to avoid token issues and speed up processing
      final textToAnalyze = allText.length > 1000 
          ? allText.substring(0, 1000) 
          : allText;

      // Optimized, shorter prompt
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
          'temperature': 0.1, // Lower for faster, more consistent results
          'max_tokens': 100, // Limit tokens for faster response
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          // Try to parse the JSON array response
          final tags = List<String>.from(jsonDecode(content));
          return tags.take(5).toList(); // Limit to 5 tags
        } catch (e) {
          // If parsing fails, return empty list
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      // Fallback: return empty list on any error
      return [];
    }
  }
}

enum HeadlineAction { useExisting, createNew }

class HeadlineMatch {
  final HeadlineAction action;
  final String headline;

  HeadlineMatch({
    required this.action,
    required this.headline,
  });
}

class AIChatResponse {
  final String text;
  final String? actionType;
  final String? actionData;
  final List<NoteCitation> noteCitations;

  AIChatResponse({
    required this.text,
    this.actionType,
    this.actionData,
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

