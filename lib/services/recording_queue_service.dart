import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../models/settings.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import 'openai_service.dart';

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
      
      // Use preferredLanguage as hint, but let Whisper detect actual spoken language
      // If no preferred language is set, Whisper will auto-detect
      final transcriptionResult = await openAIService.transcribeAudio(
        item.audioPath!,
        language: settings.preferredLanguage,
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
      
      // 2. BEAUTIFY (if enabled)
      String content = transcription;
      bool beautified = false;
      if (settings.transcriptionMode == TranscriptionMode.aiBeautify) {
        try {
          debugPrint('🎨 Starting beautification for ${transcription.length} chars...');
          content = await openAIService.beautifyTranscription(transcription);
          
          // Validate beautified content
          if (content.trim().isEmpty) {
            debugPrint('⚠️ AI beautification returned EMPTY content, using original transcription');
            debugPrint('   Original had ${transcription.length} chars: "${transcription.substring(0, transcription.length > 100 ? 100 : transcription.length)}..."');
            content = transcription;
            beautified = false;
          } else if (content.trim().length < transcription.trim().length ~/ 2) {
            // If beautified is less than half the original length, something might be wrong
            debugPrint('⚠️ AI beautification returned suspiciously short content (${content.length} vs ${transcription.length}), using original');
            content = transcription;
            beautified = false;
          } else {
            debugPrint('✅ Beautification successful: ${transcription.length} → ${content.length} chars');
            beautified = true;
          }
        } catch (e) {
          debugPrint('⚠️ AI beautification FAILED with error: $e');
          debugPrint('   Using original transcription (${transcription.length} chars)');
          content = transcription;
          beautified = false;
        }
      } else {
        debugPrint('ℹ️ Beautification skipped (mode: ${settings.transcriptionMode})');
      }
      
      // 3. ORGANIZE
      updateRecording(id, status: RecordingStatus.organizing);
      String? folderId = item.folderContext; // Use context if provided
      String? folderName;
      
      // If no folder context, use organization mode
      if (folderId == null && settings.organizationMode == OrganizationMode.autoOrganize) {
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
            // No existing folder, create new one
            final newFolder = await foldersProvider.createFolder(
              name: proposedFolderName,
              icon: result.suggestedFolderIcon ?? '📁',
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
      } else if (folderId != null) {
        // Get folder name for display
        final folder = foldersProvider.getFolderById(folderId);
        folderName = folder?.name ?? 'Unknown';
      } else {
        // Default to unorganized
        folderId = foldersProvider.unorganizedFolder?.id;
        folderName = 'Unorganized';
      }
      
      // 4. CREATE NOTE
      // Store as plain text (no Quill conversion needed)
      
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
        noteTitle = await openAIService.generateNoteTitle(content);
        
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
      
      // 5. MARK COMPLETE
      updateRecording(
        id,
        status: RecordingStatus.complete,
        transcription: transcription,
        noteId: note.id,
        assignedFolderId: folderId,
        folderName: folderName,
        beautified: beautified,
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

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}

