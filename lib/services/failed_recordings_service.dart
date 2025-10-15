import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/failed_recording.dart';
import '../services/recording_queue_service.dart';
import '../services/openai_service.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';

/// Service to manage failed recordings that need retry
class FailedRecordingsService extends ChangeNotifier {
  static final FailedRecordingsService _instance = FailedRecordingsService._internal();
  
  factory FailedRecordingsService() {
    return _instance;
  }
  
  FailedRecordingsService._internal();

  static const String _storageKey = 'failed_recordings';
  static const String _failedRecordingsDir = 'failed_recordings';
  
  List<FailedRecording> _failedRecordings = [];
  bool _isInitialized = false;

  List<FailedRecording> get failedRecordings => List.unmodifiable(_failedRecordings);
  
  int get count => _failedRecordings.length;
  
  bool get hasFailedRecordings => _failedRecordings.isNotEmpty;

  /// Initialize the service and load existing failed recordings
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadFailedRecordings();
      await _cleanupOldRecordings();
      _isInitialized = true;
      debugPrint('✅ FailedRecordingsService initialized with ${_failedRecordings.length} recordings');
    } catch (e) {
      debugPrint('❌ Failed to initialize FailedRecordingsService: $e');
      _isInitialized = true; // Continue anyway
    }
  }

  /// Add a failed recording to the backup system
  Future<void> addFailedRecording({
    required String tempAudioPath,
    required String errorMessage,
    String? folderContext,
    Duration? recordingDuration,
  }) async {
    try {
      await initialize();
      
      // Create unique ID
      final id = 'failed_${DateTime.now().millisecondsSinceEpoch}';
      
      // Ensure failed recordings directory exists
      final documentsDir = await getApplicationDocumentsDirectory();
      final failedDir = Directory('${documentsDir.path}/$_failedRecordingsDir');
      if (!await failedDir.exists()) {
        await failedDir.create(recursive: true);
      }
      
      // Copy audio file to permanent storage
      final tempFile = File(tempAudioPath);
      final permanentPath = '${failedDir.path}/$id.m4a';
      await tempFile.copy(permanentPath);
      
      // Create failed recording entry
      final failedRecording = FailedRecording(
        id: id,
        audioPath: permanentPath,
        timestamp: DateTime.now(),
        errorMessage: errorMessage,
        folderContext: folderContext,
        recordingDuration: recordingDuration,
      );
      
      // Add to list and save
      _failedRecordings.insert(0, failedRecording); // Most recent first
      await _saveFailedRecordings();
      
      debugPrint('✅ Added failed recording backup: $id');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to backup recording: $e');
    }
  }

  /// Retry a single failed recording
  Future<bool> retryRecording(String id) async {
    try {
      // For now, just remove from failed list - actual retry will be implemented
      // when we have access to the providers in the UI layer
      await removeRecording(id);
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to retry recording $id: $e');
      return false;
    }
  }

  /// Retry all failed recordings
  Future<int> retryAllRecordings({
    required OpenAIService openAIService,
    required NotesProvider notesProvider,
    required FoldersProvider foldersProvider,
    required SettingsProvider settingsProvider,
  }) async {
    int successCount = 0;
    final recordingsToRetry = List<FailedRecording>.from(_failedRecordings);
    
    debugPrint('🔄 Retrying ${recordingsToRetry.length} failed recordings...');
    
    for (final recording in recordingsToRetry) {
      try {
        // Add back to recording queue for processing
        final queueService = RecordingQueueService();
        queueService.addRecording(
          audioPath: recording.audioPath,
          folderContext: recording.folderContext,
          recordingDuration: recording.recordingDuration,
          openAIService: openAIService,
          notesProvider: notesProvider,
          foldersProvider: foldersProvider,
          settingsProvider: settingsProvider,
        );
        
        // Remove from failed list
        await removeRecording(recording.id);
        successCount++;
        
        debugPrint('✅ Queued recording for retry: ${recording.id}');
      } catch (e) {
        debugPrint('❌ Failed to retry recording ${recording.id}: $e');
      }
    }
    
    debugPrint('🎉 Retry complete: $successCount/${recordingsToRetry.length} recordings queued');
    return successCount;
  }

  /// Remove a failed recording
  Future<void> removeRecording(String id) async {
    try {
      final recording = _failedRecordings.firstWhere((r) => r.id == id);
      
      // Delete audio file
      final file = File(recording.audioPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from list
      _failedRecordings.removeWhere((r) => r.id == id);
      await _saveFailedRecordings();
      
      debugPrint('🗑️ Removed failed recording: $id');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to remove recording $id: $e');
    }
  }

  /// Clear all failed recordings
  Future<void> clearAllRecordings() async {
    try {
      // Delete all audio files
      for (final recording in _failedRecordings) {
        final file = File(recording.audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Clear list
      _failedRecordings.clear();
      await _saveFailedRecordings();
      
      debugPrint('🗑️ Cleared all failed recordings');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to clear all recordings: $e');
    }
  }

  /// Get storage size estimate
  Future<int> getStorageSizeBytes() async {
    int totalSize = 0;
    
    for (final recording in _failedRecordings) {
      try {
        final file = File(recording.audioPath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (e) {
        // Ignore individual file errors
      }
    }
    
    return totalSize;
  }

  /// Get formatted storage size
  Future<String> getFormattedStorageSize() async {
    final bytes = await getStorageSizeBytes();
    
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  /// Load failed recordings from storage
  Future<void> _loadFailedRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _failedRecordings = jsonList
            .map((json) => FailedRecording.fromJson(json as Map<String, dynamic>))
            .toList();
        
        debugPrint('📂 Loaded ${_failedRecordings.length} failed recordings from storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load failed recordings: $e');
      _failedRecordings = [];
    }
  }

  /// Save failed recordings to storage
  Future<void> _saveFailedRecordings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _failedRecordings.map((r) => r.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await prefs.setString(_storageKey, jsonString);
      debugPrint('💾 Saved ${_failedRecordings.length} failed recordings to storage');
    } catch (e) {
      debugPrint('❌ Failed to save failed recordings: $e');
    }
  }

  /// Clean up recordings older than 30 days
  Future<void> _cleanupOldRecordings() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldRecordings = _failedRecordings.where((r) => r.timestamp.isBefore(cutoffDate)).toList();
      
      if (oldRecordings.isNotEmpty) {
        debugPrint('🧹 Cleaning up ${oldRecordings.length} old failed recordings...');
        
        for (final recording in oldRecordings) {
          // Delete audio file
          final file = File(recording.audioPath);
          if (await file.exists()) {
            await file.delete();
          }
          
          // Remove from list
          _failedRecordings.remove(recording);
        }
        
        await _saveFailedRecordings();
        debugPrint('✅ Cleaned up old recordings');
      }
    } catch (e) {
      debugPrint('❌ Failed to cleanup old recordings: $e');
    }
  }

  /// Clean up failed recordings directory (called from settings)
  Future<void> cleanupStorage() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final failedDir = Directory('${documentsDir.path}/$_failedRecordingsDir');
      
      if (await failedDir.exists()) {
        await failedDir.delete(recursive: true);
        debugPrint('🗑️ Cleaned up failed recordings storage directory');
      }
      
      _failedRecordings.clear();
      await _saveFailedRecordings();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to cleanup storage: $e');
    }
  }
}
