import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import 'openai_service.dart';
import 'voice_command_service.dart';
import 'failed_recordings_service.dart';

/// Format a custom title from voice command
/// Removes trailing punctuation and ensures proper capitalization
String formatCustomTitle(String title) {
  if (title.trim().isEmpty) return title;
  
  String formatted = title.trim();
  
  // Remove trailing punctuation (., !, ?, etc.)
  formatted = formatted.replaceAll(RegExp(r'[.!?,;:]+$'), '');
  
  // Capitalize first letter if it's lowercase
  if (formatted.isNotEmpty && formatted[0] == formatted[0].toLowerCase()) {
    formatted = formatted[0].toUpperCase() + formatted.substring(1);
  }
  
  return formatted.trim();
}

/// Get smart emoji for folder based on name semantics
String getSmartEmojiForFolder(String folderName) {
  final name = folderName.toLowerCase();
  
  // Work & Professional
  if (name.contains('work') || name.contains('job') || name.contains('career') || 
      name.contains('business') || name.contains('office') || name.contains('professional')) {
    return '💼';
  }
  
  // Personal & Thoughts
  if (name.contains('personal') || name.contains('thought') || name.contains('reflect') || 
      name.contains('journal') || name.contains('diary') || name.contains('feeling')) {
    return '💭';
  }
  
  // Ideas & Creativity
  if (name.contains('idea') || name.contains('brain') || name.contains('creative') || 
      name.contains('innovation') || name.contains('concept')) {
    return '💡';
  }
  
  // Learning & Education
  if (name.contains('learn') || name.contains('study') || name.contains('education') || 
      name.contains('course') || name.contains('lesson') || name.contains('school') ||
      name.contains('university') || name.contains('college')) {
    return '📚';
  }
  
  // Health & Fitness
  if (name.contains('health') || name.contains('fitness') || name.contains('workout') || 
      name.contains('exercise') || name.contains('medical') || name.contains('doctor') ||
      name.contains('hospital') || name.contains('wellness')) {
    return '🏥';
  }
  
  // Finance & Money
  if (name.contains('finance') || name.contains('money') || name.contains('budget') || 
      name.contains('invest') || name.contains('bank') || name.contains('expense') ||
      name.contains('payment') || name.contains('bill')) {
    return '💰';
  }
  
  // Projects & Goals
  if (name.contains('project') || name.contains('goal') || name.contains('task') || 
      name.contains('plan') || name.contains('objective') || name.contains('target')) {
    return '🎯';
  }
  
  // Travel & Adventure
  if (name.contains('travel') || name.contains('trip') || name.contains('vacation') || 
      name.contains('adventure') || name.contains('journey') || name.contains('tour')) {
    return '✈️';
  }
  
  // Shopping & Purchases
  if (name.contains('shop') || name.contains('buy') || name.contains('purchase') || 
      name.contains('store') || name.contains('groceries') || name.contains('market')) {
    return '🛒';
  }
  
  // Food & Cooking
  if (name.contains('food') || name.contains('cook') || name.contains('recipe') || 
      name.contains('meal') || name.contains('restaurant') || name.contains('eat') ||
      name.contains('kitchen')) {
    return '🍽️';
  }
  
  // Home & Living
  if (name.contains('home') || name.contains('house') || name.contains('apartment') || 
      name.contains('living') || name.contains('room') || name.contains('furniture')) {
    return '🏠';
  }
  
  // Meeting & Events
  if (name.contains('meet') || name.contains('event') || name.contains('conference') || 
      name.contains('appointment') || name.contains('calendar')) {
    return '📅';
  }
  
  // Music & Entertainment
  if (name.contains('music') || name.contains('song') || name.contains('entertainment') || 
      name.contains('movie') || name.contains('show') || name.contains('concert')) {
    return '🎵';
  }
  
  // Art & Design
  if (name.contains('art') || name.contains('design') || name.contains('draw') || 
      name.contains('paint') || name.contains('creative') || name.contains('graphic')) {
    return '🎨';
  }
  
  // Technology & Coding
  if (name.contains('tech') || name.contains('code') || name.contains('program') || 
      name.contains('software') || name.contains('dev') || name.contains('computer')) {
    return '💻';
  }
  
  // Reading & Books
  if (name.contains('book') || name.contains('read') || name.contains('literature') || 
      name.contains('novel') || name.contains('story')) {
    return '📖';
  }
  
  // Default fallback
  return '📁';
}

enum RecordingStatus {
  transcribing,
  organizing,
  complete,
  error,
}

class RecordingQueueItem {
  final String id;
  RecordingStatus status;
  final String? audioPath;
  String? transcription;
  String? noteId;
  String? folderContext; // Folder user was viewing when recording
  String? assignedFolderId;
  String? folderName;
  bool beautified; // Was AI beautification applied
  String? voiceCommandDetected; // Description of detected voice command
  final DateTime timestamp;
  String? errorMessage;

  RecordingQueueItem({
    required this.id,
    required this.status,
    this.audioPath,
    this.transcription,
    this.noteId,
    this.folderContext,
    this.assignedFolderId,
    this.folderName,
    this.beautified = false,
    this.voiceCommandDetected,
    required this.timestamp,
    this.errorMessage,
  });

  RecordingQueueItem copyWith({
    RecordingStatus? status,
    String? transcription,
    String? noteId,
    String? assignedFolderId,
    String? folderName,
    bool? beautified,
    String? voiceCommandDetected,
    String? errorMessage,
  }) {
    return RecordingQueueItem(
      id: id,
      status: status ?? this.status,
      audioPath: audioPath,
      transcription: transcription ?? this.transcription,
      noteId: noteId ?? this.noteId,
      folderContext: folderContext,
      assignedFolderId: assignedFolderId ?? this.assignedFolderId,
      folderName: folderName ?? this.folderName,
      beautified: beautified ?? this.beautified,
      voiceCommandDetected: voiceCommandDetected ?? this.voiceCommandDetected,
      timestamp: timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class RecordingQueueService extends ChangeNotifier {
  static final RecordingQueueService _instance = RecordingQueueService._internal();
  
  factory RecordingQueueService() {
    return _instance;
  }
  
  RecordingQueueService._internal();

  final List<RecordingQueueItem> _queue = [];
  Timer? _cleanupTimer;
  
  // Max concurrent recordings in queue
  static const int maxQueueSize = 10;
  
  // Auto-cleanup completed recordings after 5 minutes
  static const Duration cleanupDelay = Duration(minutes: 5);

  List<RecordingQueueItem> get queue => List.unmodifiable(_queue);
  
  /// Check if there are any items processing
  bool get isProcessing {
    return _queue.any((item) => 
      item.status == RecordingStatus.transcribing || 
      item.status == RecordingStatus.organizing
    );
  }
  
  /// Count of completed items
  int get completedCount {
    return _queue.where((item) => item.status == RecordingStatus.complete).length;
  }
  
  /// Count of items with errors
  int get errorCount {
    return _queue.where((item) => item.status == RecordingStatus.error).length;
  }

  /// Add a new recording to the queue and start processing
  String addRecording({
    required String audioPath,
    String? folderContext,
    Duration? recordingDuration, // Optional recording duration for validation
    required OpenAIService openAIService,
    required NotesProvider notesProvider,
    required FoldersProvider foldersProvider,
    required SettingsProvider settingsProvider,
  }) {
    if (_queue.length >= maxQueueSize) {
      // Remove oldest completed items to make room
      _queue.removeWhere((item) => item.status == RecordingStatus.complete);
    }

    final id = 'recording_${DateTime.now().millisecondsSinceEpoch}';
    final item = RecordingQueueItem(
      id: id,
      status: RecordingStatus.transcribing,
      audioPath: audioPath,
      folderContext: folderContext,
      timestamp: DateTime.now(),
    );

    _queue.insert(0, item); // Add to front of queue
    notifyListeners();
    
    // Start processing immediately
    _processRecording(
      id: id,
      recordingDuration: recordingDuration, // Pass duration for validation
      openAIService: openAIService,
      notesProvider: notesProvider,
      foldersProvider: foldersProvider,
      settingsProvider: settingsProvider,
    );
    
    return id;
  }

  /// Process a recording: transcribe, beautify, organize, and create note
  Future<void> _processRecording({
    required String id,
    Duration? recordingDuration, // Optional recording duration for validation
    required OpenAIService openAIService,
    required NotesProvider notesProvider,
    required FoldersProvider foldersProvider,
    required SettingsProvider settingsProvider,
  }) async {
    try {
      final item = _queue.firstWhere((i) => i.id == id);
      if (item.audioPath == null) {
        throw Exception('No audio path provided');
      }

      // EARLY VALIDATION: Check recording duration if available
      if (recordingDuration != null) {
        // Only reject if duration is extremely short (less than 1 second) - likely accidental tap
        if (recordingDuration.inMilliseconds < 1000) {
          debugPrint('⚠️ Rejecting recording: extremely short (${recordingDuration.inMilliseconds}ms)');
          throw Exception('Recording was too short. Please speak for at least a few seconds.');
        }
        
        // Reject recordings longer than 10 minutes - likely accidental long recording
        if (recordingDuration.inMinutes > 10) {
          debugPrint('⚠️ Rejecting recording: too long (${recordingDuration.inMinutes}m)');
          throw Exception('Recording was too long. Please keep recordings under 10 minutes.');
        }
        
        debugPrint('✅ Recording duration validated: ${recordingDuration.inSeconds}s');
      } else {
        debugPrint('ℹ️ No recording duration provided, proceeding with content validation');
      }

      final settings = settingsProvider.settings;
      
      // 1. TRANSCRIBE
      updateRecording(id, status: RecordingStatus.transcribing);
      
      // Let Whisper auto-detect the spoken language WITHOUT any hints
      // The app UI language should NOT influence what language Whisper detects
      // User speaks English → Whisper detects "en" → transcribes in English
      // User speaks German → Whisper detects "de" → transcribes in German
      final transcriptionResult = await openAIService.transcribeAudio(
        item.audioPath!,
        // NO language parameter - let Whisper detect the actual spoken language
      );
      
      final transcription = transcriptionResult.text;
      final detectedLanguage = transcriptionResult.detectedLanguage;
      
      debugPrint('🌍 Detected language: $detectedLanguage');
      
      // Validate transcription - STRICT validation to prevent empty/invalid recordings
      if (transcription.trim().isEmpty) {
        throw Exception('Recording was too quiet or unclear. Please try again in a quieter environment.');
      }
      
      final lowerTranscription = transcription.toLowerCase().trim();
      final wordCount = lowerTranscription.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      
      // STRICT minimum length requirements
      if (transcription.trim().length < 15) {
        throw Exception('Recording was too short. Please speak for at least a few words.');
      }
      
      // STRICT minimum word count - must have at least 3 meaningful words
      if (wordCount < 3) {
        throw Exception('Recording was too short. Please speak for at least a few words.');
      }
      
      // Enhanced noise pattern detection - reject common meaningless transcriptions
      final noisePatterns = [
        // Basic noise patterns
        'thank you',
        'thanks for watching',
        'subtitle',
        'subtitles',
        'music',
        'applause',
        '...',
        'uh',
        'um',
        'ah',
        'oh',
        'hmm',
        'mm',
        'yeah',
        'yes',
        'no',
        'ok',
        'okay',
        'hello',
        'hi',
        'hey',
        'test',
        'testing',
        'one two three',
        'one two',
        'test test',
        'mic test',
        'microphone test',
        'can you hear me',
        'is this working',
        'check check',
        'sound check',
        
        // Subtitle/Credits patterns (common background audio from videos)
        // English
        'www.mooji.org',
        
        // Dutch
        'ondertitels ingediend door de amara.org gemeenschap',
        'ondertiteld door de amara.org gemeenschap',
        'ondertiteling door de amara.org gemeenschap',
        
        // German
        'untertitelung aufgrund der amara.org-community',
        'untertitel im auftrag des zdf für funk',
        'untertitel von stephanie geiges',
        'untertitel der amara.org-community',
        'untertitel im auftrag des zdf',
        'untertitelung im auftrag des zdf',
        'copyright wdr',
        'swr',
        
        // French
        'sous-titres réalisés para la communauté d\'amara.org',
        'sous-titres réalisés par la communauté d\'amara.org',
        'sous-titres fait par sous-titres par amara.org',
        'sous-titres réalisés par les soustitres d\'amara.org',
        'sous-titres par amara.org',
        'sous-titres par la communauté d\'amara.org',
        'sous-titres réalisés pour la communauté d\'amara.org',
        'sous-titres réalisés par la communauté de l\'amara.org',
        'sous-titres faits par la communauté d\'amara.org',
        'sous-titres par l\'amara.org',
        'sous-titres fait par la communauté d\'amara.org',
        'sous-titrage st\' 501',
        'sous-titrage st\'501',
        'cliquez-vous sur les sous-titres et abonnez-vous à la chaîne d\'amara.org',
        'par soustitreur.com',
        
        // Italian
        'sottotitoli creati dalla comunità amara.org',
        'sottotitoli di sottotitoli di amara.org',
        'sottotitoli e revisione al canale di amara.org',
        'sottotitoli e revisione a cura di amara.org',
        'sottotitoli e revisione a cura di qtss',
        'sottotitoli a cura di qtss',
        
        // Spanish
        'subtítulos realizados por la comunidad de amara.org',
        'subtitulado por la comunidad de amara.org',
        'subtítulos por la comunidad de amara.org',
        'subtítulos creados por la comunidad de amara.org',
        'subtítulos en español de amara.org',
        'subtítulos hechos por la comunidad de amara.org',
        'subtitulos por la comunidad de amara.org',
        'más información www.alimmenta.com',
        
        // Galician
        'subtítulos realizados por la comunidad de amara.org',
        
        // Portuguese
        'legendas pela comunidade amara.org',
        'legendas pela comunidade de amara.org',
        'legendas pela comunidade do amara.org',
        'legendas pela comunidade das amara.org',
        'transcrição e legendas pela comunidade de amara.org',
        
        // Latin
        'sottotitoli creati dalla comunità amara.org',
        'sous-titres réalisés para la communauté d\'amara.org',
        
        // Lingala
        'sous-titres réalisés para la communauté d\'amara.org',
        
        // Polish
        'napisy stworzone przez społeczność amara.org',
        'napisy wykonane przez społeczność amara.org',
        'zdjęcia i napisy stworzone przez społeczność amara.org',
        'napisy stworzone przez społeczność amara.org',
        'tłumaczenie i napisy stworzone przez społeczność amara.org',
        'napisy stworzone przez społeczności amara.org',
        'tłumaczenie stworzone przez społeczność amara.org',
        'napisy robione przez społeczność amara.org',
        'www.multi-moto.eu',
        
        // Russian
        'редактор субтитров а.синецкая корректор а.егорова',
        
        // Turkish
        'yorumlarınızıza abone olmayı unutmayın',
        
        // Sundanese
        'sottotitoli creati dalla comunità amara.org',
        
        // Chinese
        '字幕由amara.org社区提供',
        '小编字幕由amara.org社区提供',
        
        // Common patterns that appear in subtitles
        'amara.org',
        'community',
        'subtitles',
        'sous-titres',
        'sottotitoli',
        'subtítulos',
        'legendas',
        'napisy',
        'copyright',
        'zdf',
        'wdr',
        'swr',
        'qtss',
        'www.',
        '.org',
        '.com',
        '.eu',
      ];
      
      // Clean transcription by removing subtitle/credits content instead of rejecting
      String cleanedTranscription = _cleanSubtitleContent(transcription);
      
      // Update word count based on cleaned content
      final cleanedLowerTranscription = cleanedTranscription.toLowerCase().trim();
      final cleanedWordCount = cleanedLowerTranscription.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      
      debugPrint('🧹 Content cleaning: "${transcription.length}" → "${cleanedTranscription.length}" chars, $wordCount → $cleanedWordCount words');
      
      // Use cleaned transcription for further processing
      final finalTranscription = cleanedTranscription;
      final finalWordCount = cleanedWordCount;
      
      // Only reject if cleaned content is too short
      if (finalTranscription.trim().isEmpty) {
        debugPrint('⚠️ Rejecting: no content after cleaning');
        throw Exception('Recording was unclear. Please speak clearly.');
      }
      
      // STRICT minimum length requirements (on cleaned content)
      if (finalTranscription.trim().length < 15) {
        debugPrint('⚠️ Rejecting: cleaned content too short (${finalTranscription.length} chars)');
        throw Exception('Recording was too short. Please speak for at least a few words.');
      }
      
      // STRICT minimum word count - must have at least 3 meaningful words (on cleaned content)
      if (finalWordCount < 3) {
        debugPrint('⚠️ Rejecting: cleaned content too few words ($finalWordCount words)');
        throw Exception('Recording was too short. Please speak for at least a few words.');
      }
      
      // Reject if cleaned transcription matches noise patterns exactly
      if (noisePatterns.contains(cleanedLowerTranscription)) {
        debugPrint('⚠️ Rejecting cleaned transcription as noise pattern: "$finalTranscription"');
        throw Exception('Recording was unclear. Please speak clearly.');
      }
      
      // Reject if cleaned transcription is mostly single repeated words or very repetitive
      final cleanedWords = cleanedLowerTranscription.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (cleanedWords.length >= 2) {
        final uniqueWords = cleanedWords.toSet().length;
        final repetitionRatio = uniqueWords / cleanedWords.length;
        
        // If more than 60% of words are repeated, likely noise/meaningless
        if (repetitionRatio < 0.4) {
          debugPrint('⚠️ Rejecting cleaned transcription as repetitive: "$finalTranscription" (ratio: $repetitionRatio)');
          throw Exception('Recording was unclear. Please speak clearly.');
        }
      }
      
      // Reject if cleaned transcription contains mostly punctuation or special characters
      final cleanedAlphaChars = finalTranscription.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
      if (cleanedAlphaChars.length < finalTranscription.trim().length * 0.5) {
        debugPrint('⚠️ Rejecting cleaned transcription as mostly non-alphabetic: "$finalTranscription"');
        throw Exception('Recording was unclear. Please speak clearly.');
      }
      
      debugPrint('✅ Cleaned transcription validated: ${finalTranscription.length} chars, $finalWordCount words');
      
      // 2. DETECT VOICE COMMAND (before beautification) - use cleaned transcription
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      final voiceCommandResult = await VoiceCommandService.detectCommand(
        finalTranscription, // Use cleaned transcription
        foldersProvider.folders,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
      );
      
      String? voiceCommandDescription;
      String contentForProcessing = voiceCommandResult.remainingContent;
      bool isAppendCommand = false;
      String? voiceCommandFolderId;
      String? customNoteTitle;
      
      if (voiceCommandResult.hasCommands) {
        voiceCommandDescription = VoiceCommandService.getCommandsDescription(voiceCommandResult.commands);
        debugPrint('🎯 Voice commands detected: ${voiceCommandResult.commands.length} command(s)');
        debugPrint('   Commands: $voiceCommandDescription');
        debugPrint('   Remaining content: "${contentForProcessing.substring(0, contentForProcessing.length > 100 ? 100 : contentForProcessing.length)}..."');
        
        // Process each command
        for (final command in voiceCommandResult.commands) {
          debugPrint('   Processing: $command');
          
          switch (command.type) {
            case VoiceCommandType.folder:
              // Handle folder assignment - create if doesn't exist
              if (command.folderName != null) {
                debugPrint('📁 Voice command folder: ${command.folderName}');
                // Check if folder already exists (case-insensitive)
                final existingFolder = foldersProvider.getFolderByName(command.folderName!);
                if (existingFolder != null) {
                  // Folder already exists, use it
                  voiceCommandFolderId = existingFolder.id;
                  debugPrint('📁 Folder "${command.folderName}" already exists, using it (${existingFolder.id})');
                } else {
                  // Create new folder
                  final newFolder = await foldersProvider.createFolder(
                    name: command.folderName!,
                    icon: getSmartEmojiForFolder(command.folderName!),
                  );
                  voiceCommandFolderId = newFolder.id;
                  debugPrint('✨ Created new folder: ${newFolder.name} (${newFolder.id})');
                }
              }
              break;
              
            case VoiceCommandType.setTitle:
              // Set custom title for note and format it properly
              if (command.noteTitle != null) {
                customNoteTitle = formatCustomTitle(command.noteTitle!);
                debugPrint('📝 Custom title set: "$customNoteTitle" (formatted from: "${command.noteTitle}")');
              }
              break;
              
            case VoiceCommandType.append:
              // Mark for append operation (handled later)
              isAppendCommand = true;
              debugPrint('➕ Will append to last created note');
              break;
          }
        }
      }
      
      // Validate content after command extraction
      if (contentForProcessing.trim().isEmpty) {
        // If we have a custom title but no content, that's okay for title-only notes
        if (customNoteTitle == null) {
          debugPrint('⚠️ Content is empty after command extraction and no title set');
          if (voiceCommandResult.hasCommands) {
            // If we detected commands but got no content, the whole transcription was just commands
            throw Exception('No content provided after voice command. Please provide note content.');
          }
        } else {
          debugPrint('ℹ️ Creating title-only note: "$customNoteTitle"');
        }
      }
      
      // 3. BEAUTIFY (always enabled, unless content is empty for title-only note)
      String content = contentForProcessing;
      bool beautified = false;
      
      if (contentForProcessing.trim().isNotEmpty) {
        try {
          debugPrint('🎨 Starting beautification for ${contentForProcessing.length} chars...');
          debugPrint('🌍 Using detected language: $detectedLanguage');
          content = await openAIService.beautifyTranscription(
            contentForProcessing,
            detectedLanguage: detectedLanguage,
          );
          
          // Validate beautified content
          if (content.trim().isEmpty) {
            debugPrint('⚠️ AI beautification returned EMPTY content, using original content');
            debugPrint('   Original had ${contentForProcessing.length} chars: "${contentForProcessing.substring(0, contentForProcessing.length > 100 ? 100 : contentForProcessing.length)}..."');
            content = contentForProcessing;
            beautified = false;
          } else if (content.trim().length < contentForProcessing.trim().length ~/ 2) {
            // If beautified is less than half the original length, something might be wrong
            debugPrint('⚠️ AI beautification returned suspiciously short content (${content.length} vs ${contentForProcessing.length}), using original');
            content = contentForProcessing;
            beautified = false;
          } else {
            debugPrint('✅ Beautification successful: ${contentForProcessing.length} → ${content.length} chars');
            beautified = true;
          }
        } catch (e) {
          debugPrint('⚠️ AI beautification FAILED with error: $e');
          debugPrint('   Using original content (${contentForProcessing.length} chars)');
          content = contentForProcessing;
          beautified = false;
        }
      } else if (customNoteTitle != null) {
        // Title-only note, no content to beautify
        debugPrint('ℹ️ Skipping beautification for title-only note');
        content = ''; // Empty content is okay for title-only notes
        beautified = false;
      }
      
      // 4. HANDLE APPEND COMMAND (if detected)
      if (isAppendCommand) {
        debugPrint('➕ Processing append command...');
        
        // Check if we have content to append
        if (content.trim().isEmpty) {
          debugPrint('⚠️ Append command detected but no content to append, skipping');
          throw Exception('No content to append. Please provide content after the append command.');
        }
        
        // Get the last created note
        final allNotes = notesProvider.allNotes;
        if (allNotes.isEmpty) {
          debugPrint('⚠️ No existing notes to append to, creating new note instead');
          isAppendCommand = false; // Fall through to normal note creation
        } else {
          // Sort by creation date and get most recent
          final sortedNotes = List<Note>.from(allNotes)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final lastNote = sortedNotes.first;
          
          debugPrint('📄 Appending to note: "${lastNote.name}" (${lastNote.id})');
          
          // Parse existing content (might be Quill Delta JSON or plain text)
          String updatedContent;
          try {
            // Try to parse as Quill Delta
            final json = jsonDecode(lastNote.content);
            final delta = Delta.fromJson(json as List);
            
            // Append new content as new paragraph
            delta.insert('\n\n');
            delta.insert(content);
            
            updatedContent = jsonEncode(delta.toJson());
            debugPrint('✅ Appended to Quill Delta format');
          } catch (e) {
            // Not Quill format, treat as plain text
            updatedContent = '${lastNote.content}\n\n$content';
            debugPrint('✅ Appended to plain text format');
          }
          
          // Update the note with dual-mode support
          final updatedNote = lastNote.copyWith(
            content: updatedContent,
            // Append to raw transcription if it exists (use cleaned transcription)
            rawTranscription: lastNote.rawTranscription != null 
                ? '${lastNote.rawTranscription}\n\n$finalTranscription'
                : finalTranscription,
            // Append to beautified content if it exists and new content is beautified
            beautifiedContent: lastNote.beautifiedContent != null && beautified
                ? '${lastNote.beautifiedContent}\n\n$content'
                : (beautified ? content : lastNote.beautifiedContent),
            updatedAt: DateTime.now(),
          );
          
          await notesProvider.updateNote(updatedNote);
          debugPrint('✅ Note updated with appended content (dual-mode)');
          
          // Mark as complete
          updateRecording(
            id,
            status: RecordingStatus.complete,
            transcription: finalTranscription, // Use cleaned transcription
            noteId: lastNote.id,
            assignedFolderId: lastNote.folderId,
            folderName: lastNote.folderId != null 
                ? foldersProvider.getFolderById(lastNote.folderId!)?.name 
                : null,
            beautified: beautified,
            voiceCommandDetected: voiceCommandDescription,
          );
          
          debugPrint('🎉 Append operation complete');
          return; // Exit early, don't create new note
        }
      }
      
      // 5. ORGANIZE (skip if voice command specified folder)
      updateRecording(id, status: RecordingStatus.organizing);
      String? folderId;
      String? folderName;
      
      // Priority 1: Voice command folder override
      if (voiceCommandFolderId != null) {
        folderId = voiceCommandFolderId;
        final folder = foldersProvider.getFolderById(folderId);
        folderName = folder?.name ?? 'Unknown';
        debugPrint('📁 Using voice command folder: $folderName');
      }
      // Priority 2: Folder context (user was viewing a specific folder)
      else if (item.folderContext != null) {
        folderId = item.folderContext;
        final folder = foldersProvider.getFolderById(folderId!);
        folderName = folder?.name ?? 'Unknown';
        debugPrint('📁 Using folder context: $folderName');
      }
      // Priority 3: Auto-organization
      else if (settings.organizationMode == OrganizationMode.autoOrganize) {
        // Create a temporary note for organization analysis
        final tempNote = Note(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Voice Note ${DateTime.now().toString().substring(11, 16)}',
          icon: '🎤',
          content: content,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final result = await openAIService.autoOrganizeNote(
          note: tempNote,
          folders: foldersProvider.folders,
          recentNotes: notesProvider.notes.take(5).toList(),
        );
        
        // Handle folder creation if suggested
        if (result.createNewFolder) {
          // Check if a folder with this name already exists (case-insensitive)
          final proposedFolderName = result.folderName ?? 'New Folder';
          
          // Use the existing getFolderByName method which handles case-insensitive lookup correctly
          final existingFolder = foldersProvider.getFolderByName(proposedFolderName);
          
          // Use existing folder if found, otherwise create new one
          if (existingFolder != null) {
            debugPrint('📁 Reusing existing folder: ${existingFolder.name} (ID: ${existingFolder.id})');
            folderId = existingFolder.id;
            folderName = existingFolder.name;
          } else {
            // No existing folder, create new one with smart icon
            // Always use getSmartEmojiForFolder if AI returns default folder icon
            final aiIcon = result.suggestedFolderIcon;
            final smartIcon = (aiIcon == null || aiIcon == '📁') 
                ? getSmartEmojiForFolder(proposedFolderName) 
                : aiIcon;
            final newFolder = await foldersProvider.createFolder(
              name: proposedFolderName,
              icon: smartIcon,
              aiCreated: true,
            );
            debugPrint('✨ Created new folder: ${newFolder.name} (ID: ${newFolder.id})');
            folderId = newFolder.id;
            folderName = newFolder.name;
          }
        } else if (result.folderId != null) {
          folderId = result.folderId;
          folderName = result.folderName;
        } else {
          // Fall back to unorganized
          folderId = foldersProvider.unorganizedFolder?.id;
          folderName = 'Unorganized';
        }
      }
      // Priority 4: Default to unorganized
      else {
        folderId = foldersProvider.unorganizedFolder?.id;
        folderName = 'Unorganized';
      }
      
      // 6. GENERATE OR USE CUSTOM TITLE
      
      // Final content validation before creating note (unless title-only note)
      if (content.trim().isEmpty && customNoteTitle == null) {
        debugPrint('❌ CRITICAL: Content is empty after beautification and no custom title!');
        debugPrint('   Transcription was: "${transcription.substring(0, transcription.length > 200 ? 200 : transcription.length)}..."');
        throw Exception('Content processing failed - please try recording again');
      }
      
      // Additional validation: Check if final content is meaningful
      if (content.trim().isNotEmpty) {
        final lowerContent = content.toLowerCase().trim();
        
        // Check if content matches any noise patterns exactly
        if (noisePatterns.contains(lowerContent)) {
          debugPrint('⚠️ Rejecting note creation - content matches noise pattern: "$content"');
          throw Exception('Recording was unclear. Please speak clearly.');
        }
      }
      
      // Use custom title if provided by voice command, otherwise generate one
      String noteTitle;
      if (customNoteTitle != null) {
        noteTitle = customNoteTitle;
        debugPrint('✅ Using custom title from voice command: "$noteTitle"');
      } else if (content.trim().isNotEmpty) {
        // Generate descriptive title from content
        try {
          debugPrint('📝 Generating title for content (${content.length} chars)...');
          noteTitle = await openAIService.generateNoteTitle(
            content,
            folderName: folderName, // Pass folder name to avoid redundant titles
            detectedLanguage: detectedLanguage, // Use same language as content
          );
          
          // Validate title
          if (noteTitle.trim().isEmpty) {
            debugPrint('⚠️ Title generation returned empty, using default');
            noteTitle = 'Voice Note ${DateTime.now().toString().substring(5, 16)}';
          } else {
            debugPrint('✅ Generated title: "$noteTitle"');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to generate title: $e, using default');
          noteTitle = 'Voice Note ${DateTime.now().toString().substring(5, 16)}';
        }
      } else {
        // Should not reach here, but just in case
        noteTitle = 'Voice Note ${DateTime.now().toString().substring(5, 16)}';
      }
      
      debugPrint('📄 Creating note...');
      debugPrint('   Title: "$noteTitle"');
      debugPrint('   Content length: ${content.length} chars');
      debugPrint('   Folder: ${folderName ?? "None"} (${folderId ?? "null"})');
      debugPrint('   Beautified: $beautified');
      
      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: noteTitle, // Use AI-generated title
        icon: '🎤',
        content: content, // Active content (beautified by default, or raw if not beautified)
        rawTranscription: finalTranscription, // Use cleaned transcription instead of original
        beautifiedContent: beautified ? content : null, // Save beautified version if AI processed it
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        folderId: folderId,
        aiOrganized: item.folderContext == null && settings.organizationMode == OrganizationMode.autoOrganize,
        aiBeautified: beautified,
        detectedLanguage: detectedLanguage, // Store detected language from Whisper
      );
      
      await notesProvider.addNote(note);
      debugPrint('✅ Note created successfully: ${note.id}');
      
      // 7. GENERATE SUMMARY IN BACKGROUND (don't block UI)
      _generateSummaryInBackground(
        noteId: note.id,
        transcription: finalTranscription, // Use cleaned transcription
        detectedLanguage: detectedLanguage,
        notesProvider: notesProvider,
        openAIService: openAIService,
      );
      
      // 8. MARK COMPLETE
      updateRecording(
        id,
        status: RecordingStatus.complete,
        transcription: finalTranscription, // Use cleaned transcription
        noteId: note.id,
        assignedFolderId: folderId,
        folderName: folderName,
        beautified: beautified,
        voiceCommandDetected: voiceCommandDescription,
      );
      
      debugPrint('🎉 Recording processing complete for $id');
      
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR processing recording $id: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Provide user-friendly error messages
      String errorMessage;
      if (e.toString().contains('too quiet') || 
          e.toString().contains('unclear') ||
          e.toString().contains('too short')) {
        // Use the custom error message we threw
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else if (e.toString().contains('network') || 
                 e.toString().contains('connection') ||
                 e.toString().contains('timeout')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('API') || 
                 e.toString().contains('quota') ||
                 e.toString().contains('limit')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('audio') || 
                 e.toString().contains('file')) {
        errorMessage = 'Could not process audio file. Please try recording again.';
      } else {
        errorMessage = 'Failed to process recording. Please try again.';
      }
      
      // Backup failed recording for retry
      try {
        final item = _queue.firstWhere((i) => i.id == id);
        if (item.audioPath != null) {
          await FailedRecordingsService().addFailedRecording(
            tempAudioPath: item.audioPath!,
            errorMessage: errorMessage,
            folderContext: item.folderContext,
            recordingDuration: recordingDuration,
          );
          debugPrint('💾 Backed up failed recording for retry: $id');
        }
      } catch (backupError) {
        debugPrint('❌ Failed to backup recording $id: $backupError');
      }
      
      updateRecording(
        id,
        status: RecordingStatus.error,
        errorMessage: errorMessage,
      );
    }
  }

  /// Update the status of a recording
  void updateRecording(String id, {
    RecordingStatus? status,
    String? transcription,
    String? noteId,
    String? assignedFolderId,
    String? folderName,
    bool? beautified,
    String? voiceCommandDetected,
    String? errorMessage,
  }) {
    final index = _queue.indexWhere((item) => item.id == id);
    if (index == -1) return;

    _queue[index] = _queue[index].copyWith(
      status: status,
      transcription: transcription,
      noteId: noteId,
      assignedFolderId: assignedFolderId,
      folderName: folderName,
      beautified: beautified,
      voiceCommandDetected: voiceCommandDetected,
      errorMessage: errorMessage,
    );

    notifyListeners();
    
    // Auto-dismiss completed/error items after 8 seconds
    if (status == RecordingStatus.complete || status == RecordingStatus.error) {
      Future.delayed(const Duration(seconds: 8), () {
        removeRecording(id);
      });
    }
  }

  /// Remove a recording from the queue
  void removeRecording(String id) {
    _queue.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  /// Clear all completed recordings
  void clearCompleted() {
    _queue.removeWhere((item) => 
      item.status == RecordingStatus.complete || 
      item.status == RecordingStatus.error
    );
    notifyListeners();
  }

  /// Clear all recordings
  void clearAll() {
    _queue.clear();
    _cleanupTimer?.cancel();
    notifyListeners();
  }

  /// Get a recording by ID
  RecordingQueueItem? getRecording(String id) {
    try {
      return _queue.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Generate summary in background (fire-and-forget)
  /// This doesn't block the UI - summary appears when ready
  void _generateSummaryInBackground({
    required String noteId,
    required String transcription,
    required String? detectedLanguage,
    required NotesProvider notesProvider,
    required OpenAIService openAIService,
  }) {
    // Run in background without blocking
    Future.microtask(() async {
      try {
        debugPrint('📝 Starting background summary generation for note $noteId...');
        
        // Generate summary using the new method
        final summary = await openAIService.generateSummary(
          transcription,
          detectedLanguage: detectedLanguage,
        );
        
        debugPrint('✅ Summary generated successfully (${summary.length} chars)');
        
        // Update the note with the summary
        final note = notesProvider.getNoteById(noteId);
        if (note != null) {
          final updatedNote = note.copyWith(
            summary: summary,
            updatedAt: DateTime.now(),
          );
          await notesProvider.updateNote(updatedNote);
          debugPrint('✅ Note updated with summary');
        } else {
          debugPrint('⚠️ Note $noteId not found, cannot update summary');
        }
      } catch (e) {
        // Don't fail the entire flow if summary generation fails
        debugPrint('⚠️ Failed to generate summary: $e');
        // Summary will be null, user can regenerate it later if needed
      }
    });
  }

  /// Clean subtitle/credits content from transcription while preserving legitimate content
  String _cleanSubtitleContent(String transcription) {
    if (transcription.trim().isEmpty) return transcription;
    
    // Define subtitle patterns to remove (exact matches)
    final subtitlePatterns = [
      // English
      'www.mooji.org',
      
      // Dutch
      'ondertitels ingediend door de amara.org gemeenschap',
      'ondertiteld door de amara.org gemeenschap',
      'ondertiteling door de amara.org gemeenschap',
      
      // German
      'untertitelung aufgrund der amara.org-community',
      'untertitel im auftrag des zdf für funk',
      'untertitel von stephanie geiges',
      'untertitel der amara.org-community',
      'untertitel im auftrag des zdf',
      'untertitelung im auftrag des zdf',
      'copyright wdr',
      'swr',
      
      // French
      'sous-titres réalisés para la communauté d\'amara.org',
      'sous-titres réalisés par la communauté d\'amara.org',
      'sous-titres fait par sous-titres par amara.org',
      'sous-titres réalisés par les soustitres d\'amara.org',
      'sous-titres par amara.org',
      'sous-titres par la communauté d\'amara.org',
      'sous-titres réalisés pour la communauté d\'amara.org',
      'sous-titres réalisés par la communauté de l\'amara.org',
      'sous-titres faits par la communauté d\'amara.org',
      'sous-titres par l\'amara.org',
      'sous-titres fait par la communauté d\'amara.org',
      'sous-titrage st\' 501',
      'sous-titrage st\'501',
      'cliquez-vous sur les sous-titres et abonnez-vous à la chaîne d\'amara.org',
      'par soustitreur.com',
      
      // Italian
      'sottotitoli creati dalla comunità amara.org',
      'sottotitoli di sottotitoli di amara.org',
      'sottotitoli e revisione al canale di amara.org',
      'sottotitoli e revisione a cura di amara.org',
      'sottotitoli e revisione a cura di qtss',
      'sottotitoli a cura di qtss',
      
      // Spanish
      'subtítulos realizados por la comunidad de amara.org',
      'subtitulado por la comunidad de amara.org',
      'subtítulos por la comunidad de amara.org',
      'subtítulos creados por la comunidad de amara.org',
      'subtítulos en español de amara.org',
      'subtítulos hechos por la comunidad de amara.org',
      'subtitulos por la comunidad de amara.org',
      'más información www.alimmenta.com',
      
      // Galician
      'subtítulos realizados por la comunidad de amara.org',
      
      // Portuguese
      'legendas pela comunidade amara.org',
      'legendas pela comunidade de amara.org',
      'legendas pela comunidade do amara.org',
      'legendas pela comunidade das amara.org',
      'transcrição e legendas pela comunidade de amara.org',
      
      // Latin
      'sottotitoli creati dalla comunità amara.org',
      'sous-titres réalisés para la communauté d\'amara.org',
      
      // Lingala
      'sous-titres réalisés para la communauté d\'amara.org',
      
      // Polish
      'napisy stworzone przez społeczność amara.org',
      'napisy wykonane przez społeczność amara.org',
      'zdjęcia i napisy stworzone przez społeczność amara.org',
      'napisy stworzone przez społeczność amara.org',
      'tłumaczenie i napisy stworzone przez społeczność amara.org',
      'napisy stworzone przez społeczności amara.org',
      'tłumaczenie stworzone przez społeczność amara.org',
      'napisy robione przez społeczność amara.org',
      'www.multi-moto.eu',
      
      // Russian
      'редактор субтитров а.синецкая корректор а.егорова',
      
      // Turkish
      'yorumlarınızıza abone olmayı unutmayın',
      
      // Sundanese
      'sottotitoli creati dalla comunità amara.org',
      
      // Chinese
      '字幕由amara.org社区提供',
      '小编字幕由amara.org社区提供',
    ];
    
    String cleaned = transcription;
    final lowerTranscription = transcription.toLowerCase();
    
    // Remove exact pattern matches
    for (final pattern in subtitlePatterns) {
      final lowerPattern = pattern.toLowerCase();
      if (lowerTranscription.contains(lowerPattern)) {
        // Remove the pattern and clean up extra spaces
        cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), '');
        debugPrint('🧹 Removed subtitle pattern: "$pattern"');
      }
    }
    
    // Remove common subtitle keywords and phrases
    final subtitleKeywords = [
      'amara.org',
      'community',
      'subtitles',
      'sous-titres',
      'sottotitoli',
      'subtítulos',
      'legendas',
      'napisy',
      'copyright',
      'zdf',
      'wdr',
      'swr',
      'qtss',
      'ondertitels',
      'untertitel',
      '字幕',
      '社区',
      '提供',
    ];
    
    // Remove sentences/phrases containing subtitle keywords
    final sentences = cleaned.split(RegExp(r'[.!?]'));
    final cleanedSentences = <String>[];
    
    for (final sentence in sentences) {
      final lowerSentence = sentence.toLowerCase().trim();
      bool containsSubtitleKeyword = false;
      
      for (final keyword in subtitleKeywords) {
        if (lowerSentence.contains(keyword.toLowerCase())) {
          containsSubtitleKeyword = true;
          debugPrint('🧹 Removing sentence with subtitle keyword "$keyword": "$sentence"');
          break;
        }
      }
      
      if (!containsSubtitleKeyword && sentence.trim().isNotEmpty) {
        cleanedSentences.add(sentence.trim());
      }
    }
    
    // Rejoin sentences
    cleaned = cleanedSentences.join('. ').trim();
    
    // Clean up extra whitespace and punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[.]{2,}'), '.').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[.,;:!?]+'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[.,;:!?]+\s*$'), '').trim();
    
    return cleaned;
  }

  /// Get smart emoji for folder based on name keywords
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}

