import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import 'openai_service.dart';
import 'voice_command_service.dart';

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
      
      // Validate transcription
      if (transcription.trim().isEmpty) {
        throw Exception('Recording was too quiet or unclear. Please try again in a quieter environment.');
      }
      
      // Check for minimum length - RELAXED (was 15, now 10 for better UX)
      if (transcription.trim().length < 10) {
        throw Exception('Recording was too short. Please speak for at least a few words.');
      }
      
      // Check for common silence/noise patterns from Whisper - RELAXED validation
      final lowerTranscription = transcription.toLowerCase().trim();
      final wordCount = lowerTranscription.split(RegExp(r'\s+')).length;
      
      // Only reject if it's EXACTLY one of these common noise patterns
      final exactNoisePatterns = [
        'thank you',
        'thanks for watching',
        'subtitle',
        'subtitles',
        '...',
        'music',
        'applause',
      ];
      
      // Only reject if transcription is EXACTLY one of these patterns AND very short
      if (exactNoisePatterns.contains(lowerTranscription) && wordCount <= 2) {
        debugPrint('⚠️ Rejecting transcription as noise: "$transcription"');
        throw Exception('Recording was unclear. Please speak clearly.');
      }
      
      debugPrint('✅ Transcription validated: ${transcription.length} chars, $wordCount words');
      
      // 2. DETECT VOICE COMMAND (before beautification)
      final voiceCommand = VoiceCommandService.detectCommand(
        transcription,
        foldersProvider.folders,
      );
      
      String? voiceCommandDescription;
      String contentForProcessing = transcription;
      bool isAppendCommand = false;
      String? voiceCommandFolderId;
      
      if (voiceCommand != null) {
        voiceCommandDescription = VoiceCommandService.getCommandDescription(voiceCommand);
        debugPrint('🎯 Voice command detected: $voiceCommand');
        
        // Extract content without the command keyword
        contentForProcessing = VoiceCommandService.extractContentAfterCommand(
          transcription,
          voiceCommand,
        );
        
        debugPrint('📝 Content after command extraction: "${contentForProcessing.substring(0, contentForProcessing.length > 100 ? 100 : contentForProcessing.length)}..."');
        
        // Handle command types
        if (voiceCommand.type == VoiceCommandType.folder) {
          // Override folder assignment with voice command folder
          voiceCommandFolderId = voiceCommand.folderId;
          debugPrint('📁 Voice command folder override: ${voiceCommand.folderName} (${voiceCommand.folderId})');
        } else if (voiceCommand.type == VoiceCommandType.createFolder) {
          // Create new folder with the specified name
          if (voiceCommand.newFolderName != null) {
            debugPrint('📁 Voice command: creating new folder "${voiceCommand.newFolderName}"');
            // Check if folder already exists (case-insensitive)
            final existingFolder = foldersProvider.getFolderByName(voiceCommand.newFolderName!);
            if (existingFolder != null) {
              // Folder already exists, use it
              voiceCommandFolderId = existingFolder.id;
              debugPrint('📁 Folder "${voiceCommand.newFolderName}" already exists, using it (${existingFolder.id})');
            } else {
              // Create new folder
              final newFolder = await foldersProvider.createFolder(
                name: voiceCommand.newFolderName!,
                icon: getSmartEmojiForFolder(voiceCommand.newFolderName!),
              );
              voiceCommandFolderId = newFolder.id;
              debugPrint('✨ Created new folder: ${newFolder.name} (${newFolder.id})');
            }
          }
        } else if (voiceCommand.type == VoiceCommandType.append) {
          // Mark for append operation (handled later)
          isAppendCommand = true;
          debugPrint('➕ Will append to last created note');
        }
      }
      
      // Validate content after command extraction
      if (contentForProcessing.trim().isEmpty && voiceCommand != null) {
        debugPrint('⚠️ Content is empty after command extraction, using command keyword as content');
        contentForProcessing = voiceCommand.originalKeyword;
      }
      
      // 3. BEAUTIFY (if enabled)
      String content = contentForProcessing;
      bool beautified = false;
      if (settings.transcriptionMode == TranscriptionMode.aiBeautify) {
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
      } else {
        debugPrint('ℹ️ Beautification skipped (mode: ${settings.transcriptionMode})');
      }
      
      // 4. HANDLE APPEND COMMAND (if detected)
      if (isAppendCommand) {
        debugPrint('➕ Processing append command...');
        
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
          
          // Update the note
          final updatedNote = lastNote.copyWith(
            content: updatedContent,
            updatedAt: DateTime.now(),
          );
          
          await notesProvider.updateNote(updatedNote);
          debugPrint('✅ Note updated with appended content');
          
          // Mark as complete
          updateRecording(
            id,
            status: RecordingStatus.complete,
            transcription: transcription,
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
        if (result.createNewFolder && settings.allowAICreateFolders) {
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
      
      // 6. GENERATE TITLE (pass folder name to avoid redundant titles)
      
      // Final content validation before creating note
      if (content.trim().isEmpty) {
        debugPrint('❌ CRITICAL: Content is empty after beautification!');
        debugPrint('   Transcription was: "${transcription.substring(0, transcription.length > 200 ? 200 : transcription.length)}..."');
        throw Exception('Content processing failed - please try recording again');
      }
      
      // Generate descriptive title from content
      String noteTitle;
      try {
        debugPrint('📝 Generating title for content (${content.length} chars)...');
        noteTitle = await openAIService.generateNoteTitle(
          content,
          folderName: folderName, // Pass folder name to avoid redundant titles
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
      
      debugPrint('📄 Creating note...');
      debugPrint('   Title: "$noteTitle"');
      debugPrint('   Content length: ${content.length} chars');
      debugPrint('   Folder: ${folderName ?? "None"} (${folderId ?? "null"})');
      debugPrint('   Beautified: $beautified');
      
      final note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: noteTitle, // Use AI-generated title
        icon: '🎤',
        content: content, // Store as plain text
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        folderId: folderId,
        aiOrganized: item.folderContext == null && settings.organizationMode == OrganizationMode.autoOrganize,
        aiBeautified: beautified,
        detectedLanguage: detectedLanguage, // Store detected language from Whisper
      );
      
      await notesProvider.addNote(note);
      debugPrint('✅ Note created successfully: ${note.id}');
      
      // 7. MARK COMPLETE
      updateRecording(
        id,
        status: RecordingStatus.complete,
        transcription: transcription,
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

  /// Get smart emoji for folder based on name keywords
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}

