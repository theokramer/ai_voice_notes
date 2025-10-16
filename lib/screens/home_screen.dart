import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/folders_provider.dart';
import '../services/haptic_service.dart';
import '../services/recording_service.dart';
import '../services/recording_queue_service.dart';
import '../services/openai_service.dart';
import '../services/localization_service.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../widgets/microphone_button.dart';
import '../widgets/note_card.dart';
import '../widgets/create_note_dialog.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import '../widgets/hero_page_route.dart';
import '../feature_updates/ai_chat_overlay.dart';
import '../widgets/note_organization_sheet.dart';
import '../widgets/folder_selector.dart';
import '../widgets/recording_overlay.dart';
import '../widgets/recording_status_bar.dart';
import '../widgets/folder_management_dialog.dart';
import '../widgets/home/home_animated_header.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_notes_list.dart';
import '../widgets/home/home_notes_grid.dart';
import 'note_detail_screen.dart';
import 'organization_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<MicrophoneButtonState> _microphoneKey = GlobalKey<MicrophoneButtonState>();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  double _pullDownOffset = 0.0; // Track pull-down amount for search bar animation
  
  // Chat mode state
  bool _isInChatMode = false;
  final List<ChatMessage> _chatMessages = [];
  String? _chatContext;
  bool _isAIProcessing = false;
  
  // Recording state for overlay
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  bool _isPaused = false;
  
  // Recording timer and amplitude
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  Duration _totalPausedDuration = Duration.zero; // Track total paused time
  DateTime? _pauseStartTime; // Track when pause started
  double _currentAmplitude = 0.5;
  List<double> _amplitudeHistory = [];
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  
  void _onRecordingLock() {
    setState(() {
      _isRecordingLocked = true;
    });
  }

  void _onRecordingUnlock() {
    setState(() {
      _isRecordingLocked = false;
    });
  }

  // Convert dB (-160 to 0) to visual amplitude (0.0 to 1.0)
  double _normalizeAmplitude(double db) {
    // Clamp to reasonable range (-60dB to 0dB for voice)
    final normalized = ((db + 60) / 60).clamp(0.0, 1.0);
    return normalized;
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    
    try {
      await _audioRecorder.pause();
      _recordingTimer?.cancel(); // Pause timer
      _pauseStartTime = DateTime.now(); // Track when pause started
      setState(() {
        _isPaused = true;
      });
      debugPrint('⏸️ Recording paused');
    } catch (e) {
      debugPrint('Failed to pause recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    
    try {
      await _audioRecorder.resume();
      
      // Add paused duration to total
      if (_pauseStartTime != null) {
        _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
        _pauseStartTime = null;
      }
      
      // Resume timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _recordingStartTime != null) {
          setState(() {
            // Calculate total elapsed time minus paused time
            final totalElapsed = DateTime.now().difference(_recordingStartTime!);
            _recordingDuration = totalElapsed - _totalPausedDuration;
          });
        }
      });
      
      setState(() {
        _isPaused = false;
      });
      debugPrint('▶️ Recording resumed');
    } catch (e) {
      debugPrint('Failed to resume recording: $e');
    }
  }
  
  // Folder context state (for context-aware recording)
  String? _currentFolderContext;
  
  // Undo state
  Map<String, dynamic>? _lastAction;
  dynamic _undoData;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _searchFocusNode.addListener(_handleSearchFocusChange);
    
    // Ensure search bar is never focused on init
    _searchFocusNode.unfocus();
    
    // Request microphone permission on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestMicPermissionIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure search bar is never focused when navigating to home screen
    // Use a post-frame callback to ensure this happens after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        // Also clear any search state to ensure clean state
        if (_searchController.text.isNotEmpty) {
          _searchController.clear();
          context.read<NotesProvider>().setSearchQuery('');
        }
      }
    });
  }

  void _handleSearchFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  Future<void> _requestMicPermissionIfNeeded() async {
    final settingsProvider = context.read<SettingsProvider>();
    
    if (!settingsProvider.hasRequestedMicPermission) {
      // Request microphone permission
      await Permission.microphone.request();
      
      // Save that we've requested (regardless of result)
      await settingsProvider.setMicPermissionRequested();
    }
  }

  @override
  void dispose() {
    // Try to stop any active recording before disposing
    // AudioRecorder.dispose() will handle cleanup even if recording is in progress
    _audioRecorder.stop().catchError((e) {
      debugPrint('Note: Recording stop during dispose completed with: $e');
      return null;
    });
    
    // Clean up timer and amplitude subscription
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    
    _audioRecorder.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      
      // Track pull-down offset for animation (negative values mean pulling down)
      if (offset < 0) {
        setState(() {
          _pullDownOffset = offset.abs().clamp(0.0, 100.0);
        });
      } else if (_pullDownOffset != 0.0) {
        setState(() {
          _pullDownOffset = 0.0;
        });
      }
      
      // DISABLED: Automatic pull-down-to-focus to prevent accidental triggers
      // Users can still tap the search bar to focus it manually
      // This prevents the search bar from focusing when navigating to home screen
    }
  }


  /// Apply folder filtering to notes list
  List<Note> _getFilteredNotes(List<Note> allNotes) {
    if (_currentFolderContext != null) {
      return allNotes.where((n) => n.folderId == _currentFolderContext).toList();
    }
    return allNotes; // Show all if no folder context
  }

  void _enterChatMode(String query) async {
    HapticService.medium();
    setState(() {
      _isInChatMode = true;
      _chatContext = query.isNotEmpty ? query : null;
      _searchController.clear();
    });
    
    // Clear the search filter in NotesProvider when entering chat mode
    context.read<NotesProvider>().setSearchQuery('');
    
    // Unfocus the search bar when entering AI chat mode
    _searchFocusNode.unfocus();
    
    // Only send to AI if there's a query
    if (query.trim().isNotEmpty) {
      await _sendToAI(query);
    }
  }

  void _exitChatMode() {
    HapticService.light();
    setState(() {
      _isInChatMode = false;
      _chatMessages.clear();
      _chatContext = null;
      _isAIProcessing = false;
    });
    
    // Ensure search filter is cleared when exiting chat mode
    context.read<NotesProvider>().setSearchQuery('');
    
    // Unfocus the search bar to show the microphone button
    _searchFocusNode.unfocus();
  }

  Future<void> _sendToAI(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    setState(() {
      _chatMessages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isAIProcessing = true;
    });

    try {
      final notesProvider = context.read<NotesProvider>();
      final foldersProvider = context.read<FoldersProvider>();
      final openAIService = OpenAIService(apiKey: dotenv.env['OPENAI_API_KEY'] ?? '');
      
      // Build conversation history
      final history = _chatMessages
          .where((m) => m.isUser)
          .map((m) => {'role': 'user', 'content': m.text})
          .toList();

      final response = await openAIService.chatCompletion(
        message: message,
        history: history,
        notes: notesProvider.allNotes,
        folders: foldersProvider.folders,
      );

      // Add AI response with citations and action
      final aiMessage = ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        noteCitations: response.noteCitations,
        action: response.action,
      );

      if (mounted) {
        setState(() {
          _chatMessages.add(aiMessage);
          _isAIProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _sendToAI: $e');
      if (mounted) {
        setState(() {
          _chatMessages.add(ChatMessage(
            text: 'Sorry, I encountered an error. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
          _isAIProcessing = false;
        });
      }
    }
  }

  void _undoLastAction() async {
    if (_lastAction == null) return;
    
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    
    try {
      switch (_lastAction!['type']) {
        case 'create_note':
          final noteId = _undoData as String;
          await notesProvider.deleteNote(noteId, foldersProvider: foldersProvider);
          break;
          
        case 'add_to_note':
          final noteId = _lastAction!['noteId'] as String;
          final undoData = _undoData as Map<String, dynamic>;
          final oldContent = undoData['content'] as String;
          final oldRawTranscription = undoData['rawTranscription'] as String?;
          final note = notesProvider.getNoteById(noteId);
          if (note != null) {
            final restoredNote = note.copyWith(
              content: oldContent,
              rawTranscription: oldRawTranscription,
            );
            await notesProvider.updateNote(restoredNote);
          }
          break;
          
        case 'add_to_last_note':
          final noteId = _lastAction!['noteId'] as String;
          final undoData = _undoData as Map<String, dynamic>;
          final oldContent = undoData['content'] as String;
          final oldRawTranscription = undoData['rawTranscription'] as String?;
          final note = notesProvider.getNoteById(noteId);
          if (note != null) {
            final restoredNote = note.copyWith(
              content: oldContent,
              rawTranscription: oldRawTranscription,
            );
            await notesProvider.updateNote(restoredNote);
          }
          break;
          
        case 'move_note':
          final noteId = _lastAction!['noteId'] as String;
          final oldFolderId = _undoData as String?;
          await notesProvider.moveNoteToFolder(
            noteId,
            oldFolderId,
            foldersProvider: foldersProvider,
          );
          break;
          
        case 'create_folder':
          final folderId = _undoData as String;
          await foldersProvider.deleteFolder(folderId);
          break;
          
        case 'pin_note':
          final noteId = _lastAction!['noteId'] as String;
          final wasPinned = _undoData as bool;
          final note = notesProvider.getNoteById(noteId);
          if (note != null) {
            final restoredNote = note.copyWith(isPinned: wasPinned);
            await notesProvider.updateNote(restoredNote);
          }
          break;
          
        case 'consolidate':
          final data = _undoData as Map<String, dynamic>;
          // Delete consolidated note
          await notesProvider.deleteNote(data['consolidatedId'], foldersProvider: foldersProvider);
          // Restore original notes
          for (final note in data['originalNotes'] as List<Note>) {
            await notesProvider.addNote(note, foldersProvider: foldersProvider);
          }
          break;
      }
      
      if (mounted) {
        HapticService.success();
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('action_undone'),
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    } catch (e) {
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('failed_undo'),
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    }
    
    _lastAction = null;
    _undoData = null;
  }
  
  void _handleChatAction(ChatAction action) async {
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    
    try {
      switch (action.type) {
        case 'create_note':
          final noteName = action.data['noteName'] as String;
          final noteContent = action.data['noteContent'] as String? ?? '';
          
          // Always use the default unorganized folder for AI-created notes
          // This prevents the AI from creating unnecessary folders
          String? finalFolderId = foldersProvider.unorganizedFolderId;
          
          HapticService.success();
          final newNote = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: noteName,
            icon: '📝',
            content: noteContent,
            rawTranscription: noteContent, // Set rawTranscription to keep plain text format
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            folderId: finalFolderId,
          );

          await notesProvider.addNote(newNote, foldersProvider: foldersProvider);
          
          // Save undo data
          _lastAction = {'type': 'create_note'};
          _undoData = newNote.id;
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Created note "$noteName"!',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          // Show undo snackbar
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: LocalizationService().t('created_note', {'name': noteName}),
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          
          // Navigate to the newly created note
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(noteId: newNote.id),
              ),
            );
            // Ensure UI is refreshed after returning from note detail
            if (mounted) {
              setState(() {});
            }
          }
          break;
        
        case 'add_to_last_note':
          final contentToAdd = action.data['contentToAdd'] as String;
          
          // Get all notes and sort by creation date (most recent first)
          final allNotes = notesProvider.allNotes;
          if (allNotes.isEmpty) {
            setState(() {
              _chatMessages.add(ChatMessage(
                text: '❌ No notes found to append to.',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            return;
          }
          
          // Sort by creation date and get most recent
          final sortedNotes = List<Note>.from(allNotes)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final lastNote = sortedNotes.first;
          
          HapticService.success();
          
          // Save old content for undo
          final oldContent = lastNote.content;
          final oldRawTranscription = lastNote.rawTranscription;
          
          // Append new content to both content and rawTranscription
          final newContent = lastNote.content.isEmpty 
              ? contentToAdd 
              : '${lastNote.content}\n\n$contentToAdd';
          
          final newRawTranscription = lastNote.rawTranscription == null
              ? contentToAdd
              : '${lastNote.rawTranscription}\n\n$contentToAdd';
          
          final updatedNote = lastNote.copyWith(
            content: newContent,
            rawTranscription: newRawTranscription,
          );
          await notesProvider.updateNote(updatedNote);
          
          // Save undo data
          _lastAction = {'type': 'add_to_last_note', 'noteId': lastNote.id};
          _undoData = {'content': oldContent, 'rawTranscription': oldRawTranscription};
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Added content to "${lastNote.name}"!',
              isUser: false,
              timestamp: DateTime.now(),
              noteCitations: [NoteCitation(
                noteId: lastNote.id,
                noteName: lastNote.name,
              )],
            ));
          });
          
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: 'Added content to "${lastNote.name}"',
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          break;
        
        case 'add_to_note':
          final noteId = action.data['noteId'] as String;
          final contentToAdd = action.data['contentToAdd'] as String;
          
          final note = notesProvider.getNoteById(noteId);
          if (note == null) {
            setState(() {
              _chatMessages.add(ChatMessage(
                text: '❌ Could not find that note.',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            return;
          }
          
          HapticService.success();
          
          // Save old content for undo
          final oldContent = note.content;
          final oldRawTranscription = note.rawTranscription;
          
          // Append new content to both content and rawTranscription
          final newContent = note.content.isEmpty 
              ? contentToAdd 
              : '${note.content}\n\n$contentToAdd';
          
          final newRawTranscription = note.rawTranscription == null
              ? contentToAdd
              : '${note.rawTranscription}\n\n$contentToAdd';
          
          final updatedNote = note.copyWith(
            content: newContent,
            rawTranscription: newRawTranscription,
          );
          await notesProvider.updateNote(updatedNote);
          
          // Save undo data
          _lastAction = {'type': 'add_to_note', 'noteId': noteId};
          _undoData = {'content': oldContent, 'rawTranscription': oldRawTranscription};
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Added content to "${note.name}"!',
              isUser: false,
              timestamp: DateTime.now(),
              noteCitations: [NoteCitation(
                noteId: note.id,
                noteName: note.name,
              )],
            ));
          });
          
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: 'Added content to "${note.name}"',
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          break;
        
        case 'move_note':
          final noteId = action.data['noteId'] as String;
          
          final note = notesProvider.getNoteById(noteId);
          if (note == null) {
            setState(() {
              _chatMessages.add(ChatMessage(
                text: '❌ Could not find that note.',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            return;
          }
          
          HapticService.success();
          
          // Save old folder for undo
          final oldFolderId = note.folderId;
          
          // Always move to unorganized folder to prevent AI from creating/moving to wrong folders
          await notesProvider.moveNoteToFolder(
            noteId, 
            foldersProvider.unorganizedFolderId,
            foldersProvider: foldersProvider,
          );
          
          // Save undo data
          _lastAction = {'type': 'move_note', 'noteId': noteId};
          _undoData = oldFolderId;
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Moved "${note.name}" to the main folder!',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: 'Moved to main folder',
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          break;
        
        case 'create_folder':
          // Disabled: AI should not create folders, always use unorganized folder
          final folderName = action.data['folderName'] as String;
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '📝 Note will be saved to the main folder instead of creating "$folderName"',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          break;
        
        case 'summarize_chat':
          HapticService.medium();
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '🤔 Creating summary...',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          try {
            final openAIService = OpenAIService(apiKey: dotenv.env['OPENAI_API_KEY'] ?? '');
            final summary = await openAIService.summarizeChatHistory(_chatMessages);
            
            // Generate title for the summary note
            final summaryTitle = 'Chat Summary - ${DateTime.now().toString().substring(0, 16)}';
            
            final summaryNote = Note(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: summaryTitle,
              icon: '💬',
              content: summary,
              rawTranscription: summary, // Set rawTranscription to keep plain text format
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            await notesProvider.addNote(summaryNote, foldersProvider: foldersProvider);
            
            // Save undo data
            _lastAction = {'type': 'create_note'};
            _undoData = summaryNote.id;
            
            setState(() {
              // Remove the "Creating summary..." message
              _chatMessages.removeLast();
              _chatMessages.add(ChatMessage(
                text: '✅ Created chat summary note!',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            
            if (mounted) {
              CustomSnackbar.show(
                context,
                message: 'Created chat summary',
                type: SnackbarType.success,
                actionLabel: 'VIEW',
                onAction: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(noteId: summaryNote.id),
                    ),
                  );
                },
                duration: const Duration(seconds: 4),
                themeConfig: settingsProvider.currentThemeConfig,
              );
            }
          } catch (e) {
            setState(() {
              // Remove the "Creating summary..." message
              _chatMessages.removeLast();
              _chatMessages.add(ChatMessage(
                text: '❌ Failed to create summary: ${e.toString()}',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
          }
          break;
        
        case 'pin_note':
          final noteId = action.data['noteId'] as String;
          
          final note = notesProvider.getNoteById(noteId);
          if (note == null) {
            setState(() {
              _chatMessages.add(ChatMessage(
                text: '❌ Could not find that note.',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            return;
          }
          
          HapticService.success();
          
          final wasPinned = note.isPinned;
          final updatedNote = note.copyWith(isPinned: !note.isPinned);
          await notesProvider.updateNote(updatedNote);
          
          // Save undo data
          _lastAction = {'type': 'pin_note', 'noteId': noteId};
          _undoData = wasPinned;
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: wasPinned 
                  ? '✅ Unpinned "${note.name}"!' 
                  : '✅ Pinned "${note.name}"!',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: wasPinned ? 'Note unpinned' : 'Note pinned',
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          break;
        
        case 'delete_note':
          final noteId = action.data['noteId'] as String;
          
          final note = notesProvider.getNoteById(noteId);
          if (note == null) {
            setState(() {
              _chatMessages.add(ChatMessage(
                text: '❌ Could not find that note.',
                isUser: false,
                timestamp: DateTime.now(),
              ));
            });
            return;
          }
          
          // Show confirmation for destructive action
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(LocalizationService().t('delete_note_confirm_title')),
              content: Text('Are you sure you want to delete "${note.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(LocalizationService().t('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(LocalizationService().t('delete')),
                ),
              ],
            ),
          );
          
          if (confirmed != true) return;
          
          HapticService.success();
          await notesProvider.deleteNote(noteId, foldersProvider: foldersProvider);
          
          // No need for special undo - note deletion already has built-in undo
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Deleted "${note.name}".',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: 'Note deleted',
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: () async {
                await notesProvider.undoDelete(foldersProvider: foldersProvider);
              },
              duration: const Duration(seconds: 4),
              themeConfig: settingsProvider.currentThemeConfig,
            );
          }
          break;
        
      case 'consolidate':
        final targetName = action.data['targetName'] as String;
        final noteIds = (action.data['noteIds'] as List).cast<String>();
        
        // Get all notes to consolidate
        final notesToConsolidate = notesProvider.allNotes
            .where((n) => noteIds.contains(n.id))
            .toList();
        
        if (notesToConsolidate.isEmpty) return;
        
        // Collect all content from all notes
        final allContents = <String>[];
        for (final note in notesToConsolidate) {
          if (note.content.isNotEmpty) {
            allContents.add('## ${note.name}\n\n${note.content}');
          }
        }
        
        // Create new consolidated note
        final consolidatedNote = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: targetName,
          icon: notesToConsolidate.first.icon,
          content: allContents.join('\n\n---\n\n'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Save undo data before making changes
        _lastAction = {'type': 'consolidate'};
        _undoData = {
          'consolidatedId': consolidatedNote.id,
          'originalNotes': List.from(notesToConsolidate),
        };
        
        // Add new note
        await notesProvider.addNote(consolidatedNote, foldersProvider: foldersProvider);
        
        // Delete old notes
        for (final note in notesToConsolidate) {
          await notesProvider.deleteNote(note.id, foldersProvider: foldersProvider);
        }
        
        HapticService.success();
        setState(() {
          _chatMessages.add(ChatMessage(
            text: '✅ Consolidated ${notesToConsolidate.length} notes into "$targetName"!',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        
        // Show undo snackbar
        if (mounted) {
          final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
          CustomSnackbar.show(
            context,
            message: LocalizationService().t('consolidated_notes', {'count': notesToConsolidate.length.toString()}),
            type: SnackbarType.success,
            actionLabel: 'UNDO',
            onAction: _undoLastAction,
            duration: const Duration(seconds: 4),
            themeConfig: themeConfig,
          );
        }
        break;
      }
    } catch (e) {
      // Handle any errors
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('failed_execute_action', {'error': e.toString()}),
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    }
  }

  List<String> _extractSnippets(Note note, String query) {
    if (query.trim().isEmpty) return [];
    
    final snippets = <String>[];
    final lowerQuery = query.toLowerCase();
    final content = note.content;
    
    if (content.toLowerCase().contains(lowerQuery)) {
      // Find all matches
      int searchStart = 0;
      while (searchStart < content.length && snippets.length < 2) {
        final index = content.toLowerCase().indexOf(lowerQuery, searchStart);
        if (index == -1) break;
        
        final start = (index - 50).clamp(0, content.length);
        final end = (index + query.length + 50).clamp(0, content.length);
        
        String snippet = content.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < content.length) snippet = '$snippet...';
        
        snippets.add(snippet);
        searchStart = index + 1;
      }
    }
    
    return snippets;
  }

  // Estimate the height of a note card for grid layout balancing
  // This must match the actual NoteCard rendering in grid view
  Future<void> _startRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.light();

    // CRITICAL: Cancel any existing subscriptions before starting new recording
    // This prevents "Stream has already been listened to" error
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;
      _totalPausedDuration = Duration.zero; // Reset paused duration
      _pauseStartTime = null; // Reset pause start time
      _currentAmplitude = 0.5; // Reset amplitude for visualization
      _amplitudeHistory.clear(); // Clear previous recording's amplitude history
    });

    // Start recording timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _recordingStartTime != null) {
        setState(() {
          // Calculate total elapsed time minus paused time
          final totalElapsed = DateTime.now().difference(_recordingStartTime!);
          _recordingDuration = totalElapsed - _totalPausedDuration;
        });
      }
    });

    // Use optimized recording service (must start before listening to amplitude)
    final result = await RecordingService().startRecording(_audioRecorder);

    if (!result.success) {
      // Clean up on failure
      _recordingTimer?.cancel();
      _amplitudeSubscription?.cancel();
      
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingStartTime = null;
          _recordingDuration = Duration.zero;
        });
        
        final errorMessage = result.errorType == RecordingErrorType.permissionDeniedPermanently
            ? 'Microphone permission required'
            : result.errorType == RecordingErrorType.permissionDenied
                ? 'Microphone permission required'
                : 'Failed to start recording: ${result.errorMessage}';
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: errorMessage,
          type: SnackbarType.error,
          actionLabel: result.errorType == RecordingErrorType.permissionDeniedPermanently 
              ? 'Settings' 
              : null,
          onAction: result.errorType == RecordingErrorType.permissionDeniedPermanently 
              ? () => openAppSettings() 
              : null,
          themeConfig: themeConfig,
        );
      }
      return;
    }

    debugPrint('🎤 Recording started successfully, setting up amplitude listener...');
    
    // Listen to real microphone amplitude from the record package
    try {
      _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen(
          (amplitude) {
            if (mounted && _isRecording) {
              setState(() {
                final newAmplitude = _normalizeAmplitude(amplitude.current);
                _currentAmplitude = newAmplitude;
                
                // Add to history (keep last 100 samples for smooth scrolling)
                _amplitudeHistory.add(newAmplitude);
                if (_amplitudeHistory.length > 100) {
                  _amplitudeHistory.removeAt(0);
                }
              });
            }
          },
          onError: (error) {
            debugPrint('⚠️ Amplitude stream error: $error');
          },
          cancelOnError: false,
        );
      debugPrint('✅ Amplitude listener set up successfully');
    } catch (e) {
      debugPrint('❌ Failed to set up amplitude listener: $e');
    }

    // Recording path no longer stored - handled by RecordingQueueService
  }

  Future<void> _stopRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.light();
    
    // Capture the final recording duration before resetting
    final finalRecordingDuration = _recordingDuration;
    debugPrint('📊 Final recording duration: ${finalRecordingDuration.inSeconds}s');
    
    // Clean up timer and amplitude subscription
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    
    // Reset microphone button state
    _microphoneKey.currentState?.resetRecordingState();
    
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isPaused = false;
      _recordingStartTime = null;
      _recordingDuration = Duration.zero;
      _totalPausedDuration = Duration.zero; // Reset paused duration
      _pauseStartTime = null; // Reset pause start time
      _currentAmplitude = 0.5;
      _amplitudeHistory.clear();
    });
    
    final stoppedPath = await RecordingService().stopRecording(_audioRecorder);
    
    // Dispose and recreate AudioRecorder for next recording
    // This ensures fresh amplitude stream every time
    try {
      await _audioRecorder.dispose();
      debugPrint('🔄 AudioRecorder disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing AudioRecorder: $e');
    }
    _audioRecorder = AudioRecorder();
    debugPrint('✅ New AudioRecorder instance created');

    if (stoppedPath == null) {
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('failed_stop_recording'),
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
      return;
    }

    // Add to recording queue service with folder context
    if (mounted) {
      final queueService = context.read<RecordingQueueService>();
      final openAIService = OpenAIService(apiKey: dotenv.env['OPENAI_API_KEY'] ?? '');
      
      queueService.addRecording(
        audioPath: stoppedPath,
        folderContext: _currentFolderContext,
        recordingDuration: finalRecordingDuration, // Pass captured recording duration for validation
        openAIService: openAIService,
        notesProvider: context.read<NotesProvider>(),
        foldersProvider: context.read<FoldersProvider>(),
        settingsProvider: context.read<SettingsProvider>(),
      );
      
      // Show brief hint if enabled (only for explicit folder saves)
      if (mounted && _currentFolderContext != null) {
        final folderName = context.read<FoldersProvider>().getFolderById(_currentFolderContext!)?.name;
        
        if (folderName != null) {
          CustomSnackbar.show(
            context,
            message: 'Recording saved to $folderName',
            type: SnackbarType.success,
            themeConfig: context.read<SettingsProvider>().currentThemeConfig,
          );
        }
      }
    }
  }

  Future<void> _discardRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.light();
    
    // Clean up timer and amplitude subscription
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    
    // Reset microphone button state
    _microphoneKey.currentState?.resetRecordingState();
    
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isPaused = false;
      _recordingStartTime = null;
      _recordingDuration = Duration.zero;
      _totalPausedDuration = Duration.zero; // Reset paused duration
      _pauseStartTime = null; // Reset pause start time
      _currentAmplitude = 0.5;
      _amplitudeHistory.clear();
    });
    
    // Stop recording without processing
    final stoppedPath = await RecordingService().stopRecording(_audioRecorder);
    
    // Dispose and recreate AudioRecorder for next recording
    // This ensures fresh amplitude stream every time
    try {
      await _audioRecorder.dispose();
      debugPrint('🔄 AudioRecorder disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing AudioRecorder: $e');
    }
    _audioRecorder = AudioRecorder();
    debugPrint('✅ New AudioRecorder instance created');
    
    // Delete the temp audio file if it exists
    if (stoppedPath != null) {
      try {
        final file = File(stoppedPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete discarded recording: $e');
      }
    }
    
    // Show confirmation toast
    if (mounted) {
      final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
      CustomSnackbar.show(
        context,
        message: 'Recording discarded',
        type: SnackbarType.success,
        themeConfig: themeConfig,
      );
    }
  }

  void _showEditNoteDialog(Note note) async {
    HapticService.light();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => CreateNoteDialog(
        initialName: note.name,
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<NotesProvider>();
      final updatedNote = note.copyWith(
        name: result['name'],
      );
      provider.updateNote(updatedNote); // Non-blocking
      HapticService.success(); // Fire-and-forget
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('note_updated'),
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    }
  }

  void _showDeleteConfirmation(Note note) async {
    HapticService.light();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              decoration: BoxDecoration(
                color: AppTheme.glassStrongSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFef4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFef4444),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    LocalizationService().t('delete_note'),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    LocalizationService().t('home_delete_note_confirm', {'name': note.name}),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
                            Navigator.pop(context, false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.glassSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              border:
                                  Border.all(color: AppTheme.glassBorder, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.medium();
                            Navigator.pop(context, true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFef4444),
                                  Color(0xFFdc2626),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFef4444).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Delete',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationNormal,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: AppTheme.animationNormal),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<NotesProvider>();
      provider.deleteNote(note.id); // Non-blocking - instant UI update
      HapticService.heavy(); // Fire-and-forget
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: LocalizationService().t('note_deleted'),
          type: SnackbarType.info,
          actionLabel: 'Undo',
          onAction: () {
            provider.undoDelete(); // Non-blocking
            HapticService.success(); // Fire-and-forget
          },
          duration: const Duration(seconds: 5),
          themeConfig: themeConfig,
        );
      }
    }
  }

  void _showNoteOptions(Note note) async {
    HapticService.light();
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassStrongSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXLarge),
              ),
              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: AppTheme.spacing12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  _buildOptionTile(
                    icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    title: note.isPinned ? LocalizationService().t('unpin_note') : LocalizationService().t('pin_note'),
                    themeConfig: themeConfig,
                    onTap: () async {
                      Navigator.pop(context);
                      await context.read<NotesProvider>().toggleNotePin(note.id);
                      await HapticService.success();
                      if (mounted) {
                        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
                        CustomSnackbar.show(
                          context,
                          message: note.isPinned ? LocalizationService().t('note_unpinned') : LocalizationService().t('note_pinned'),
                          type: SnackbarType.success,
                          themeConfig: themeConfig,
                        );
                      }
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.edit,
                    title: LocalizationService().t('edit_note'),
                    themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                      _showEditNoteDialog(note);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    title: LocalizationService().t('delete_note'),
                    themeConfig: themeConfig,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(note);
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .slideY(
            begin: 0.3,
            end: 0,
            duration: AppTheme.animationNormal,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(duration: AppTheme.animationNormal),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeConfig themeConfig,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () {
        HapticService.light();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing16,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFef4444).withValues(alpha: 0.2)
                    : themeConfig.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: isDestructive ? const Color(0xFFef4444) : themeConfig.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? const Color(0xFFef4444) : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        return GestureDetector(
          onTap: () {
            // Properly unfocus search bar when tapping background
            // This should behave the same as pressing the keyboard done button
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
              // Clear any search query when unfocusing via background tap
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                context.read<NotesProvider>().setSearchQuery('');
              }
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        child: Scaffold(
          body: AnimatedBackground(
            themeConfig: settingsProvider.currentThemeConfig,
            child: SafeArea(
              top: false, // Allow header to extend into safe area
              child: Stack(
                children: [
              // Main scrollable content with CustomScrollView
              Consumer<NotesProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: themeConfig.primaryColor,
                      ),
                    );
                  }

                  final filteredNotes = _getFilteredNotes(provider.notes);
                  
                  // Show notes list only if not in chat mode
                  if (_isInChatMode) {
                    return Container(
                      color: Colors.transparent,
                    );
                  }

                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // Animated Header with smooth collapsing effect
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: AnimatedHeaderDelegate(
                          builder: (progress) => HomeAnimatedHeader(
                            progress: progress,
                            greeting: _getGreeting(),
                            onSearchTap: () {
                              HapticService.light();
                              // Focus the search field when tapped
                              _searchFocusNode.requestFocus();
                            },
                            onOrganizeTap: _showOrganizeBottomSheet,
                            searchController: _searchController,
                            searchFocusNode: _searchFocusNode,
                            onSearchChanged: (value) {
                              if (!_isInChatMode) {
                                context.read<NotesProvider>().setSearchQuery(value);
                              }
                              setState(() {});
                            },
                            onSearchSubmitted: (value) async {
                              // Properly unfocus search bar when done button is pressed
                              _searchFocusNode.unfocus();
                              
                              if (value.trim().isEmpty) return;
                              if (_isInChatMode) {
                                await _sendToAI(value);
                                _searchController.clear();
                              }
                            },
                            onAskAI: () {
                              _enterChatMode(_searchController.text);
                            },
                            hasSearchQuery: _searchController.text.isNotEmpty,
                            isInChatMode: _isInChatMode,
                            isSearchFocused: _isSearchFocused,
                            pullDownOffset: _pullDownOffset,
                          ),
                          expandedHeight: 140.0 + MediaQuery.of(context).padding.top,
                          collapsedHeight: 56.0 + MediaQuery.of(context).padding.top,
                        ),
                      ),
                      // Folder Selector
                      Consumer<FoldersProvider>(
                        builder: (context, foldersProvider, child) {
                          final unorganized = foldersProvider.unorganizedFolder;
                          if (unorganized == null) {
                            return const SliverToBoxAdapter(child: SizedBox.shrink());
                          }
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: FolderSelector(
                                selectedFolderId: _currentFolderContext,
                                folders: foldersProvider.folders,
                                unorganizedFolder: unorganized,
                                onFolderSelected: (folderId) {
                                  setState(() => _currentFolderContext = folderId);
                                },
                                onManageFolders: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (context) => FolderManagementDialog(),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      // Empty state when no notes
                      if (filteredNotes.isEmpty)
                        Consumer<FoldersProvider>(
                          builder: (context, foldersProvider, child) {
                            final isViewingUnorganized = _currentFolderContext == foldersProvider.unorganizedFolderId;
                            return HomeEmptyState(
                              hasSearchQuery: _searchController.text.isNotEmpty,
                              searchQuery: _searchController.text,
                              isViewingUnorganized: isViewingUnorganized,
                            );
                          },
                        ),
                      // Notes list - View type based on provider setting
                      if (filteredNotes.isNotEmpty)
                        Consumer<NotesProvider>(
                          builder: (context, notesProvider, child) {
                            final viewType = notesProvider.noteViewType;
                            
                            // Minimalistic List View
                            if (viewType == NoteViewType.minimalisticList) {
                              return HomeNotesList(
                                notes: filteredNotes,
                                provider: provider,
                                searchQuery: _searchController.text,
                                onShowNoteOptions: _showNoteOptions,
                              );
                            }
                            // Grid View - using custom layout for varying heights
                            else if (viewType == NoteViewType.grid) {
                              return HomeNotesGrid(
                                notes: filteredNotes,
                                provider: provider,
                                searchQuery: _searchController.text,
                                onShowNoteOptions: _showNoteOptions,
                                extractSnippets: _extractSnippets,
                              );
                            }
                            // Standard List View
                            else {
                              // List view with pinned section
                              final pinnedNotes = filteredNotes.where((n) => n.isPinned).toList();
                              final unpinnedNotes = filteredNotes.where((n) => !n.isPinned).toList();
                              final hasPinned = pinnedNotes.isNotEmpty;
                              
                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing24,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      // Show pinned header
                                      if (index == 0 && hasPinned) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppTheme.spacing24,
                                            top: AppTheme.spacing8,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: AppTheme.spacing12,
                                                  vertical: AppTheme.spacing8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      themeConfig.primaryColor.withOpacity(0.2),
                                                      themeConfig.primaryColor.withOpacity(0.1),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                  border: Border.all(
                                                    color: themeConfig.primaryColor.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.push_pin,
                                                      size: 14,
                                                      color: themeConfig.primaryColor,
                                                    ),
                                                    const SizedBox(width: AppTheme.spacing8),
                                                    Text(
                                                      'Pinned',
                                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                            color: themeConfig.primaryColor,
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: 0.5,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: AppTheme.spacing16),
                                              Expanded(
                                                child: Container(
                                                  height: 1,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        themeConfig.primaryColor.withOpacity(0.3),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      
                                      int adjustedIndex = index;
                                      if (hasPinned) adjustedIndex -= 1;
                                      
                                      // Show divider between pinned and unpinned
                                      if (hasPinned && unpinnedNotes.isNotEmpty && 
                                          adjustedIndex == pinnedNotes.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: AppTheme.spacing16,
                                            bottom: AppTheme.spacing32,
                                          ),
                                          child: Container(
                                            height: 1,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  AppTheme.glassBorder.withOpacity(0.2),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      if (hasPinned && unpinnedNotes.isNotEmpty && 
                                          adjustedIndex > pinnedNotes.length) {
                                        adjustedIndex -= 1;
                                      }
                                      
                                      final allNotes = [...pinnedNotes, ...unpinnedNotes];
                                      final note = allNotes[adjustedIndex];
                                      final snippets = _extractSnippets(note, _searchController.text);
                                      
                                      return Dismissible(
                                        key: Key(note.id),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss: (direction) async {
                                          _showDeleteConfirmation(note);
                                          return false;
                                        },
                                        background: Container(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: AppTheme.spacing24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xFFef4444),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            child: GestureDetector(
                              onLongPress: () => _showNoteOptions(note),
                              child: NoteCard(
                                note: note,
                                searchQuery: _searchController.text,
                                      matchedSnippets: snippets,
                                index: adjustedIndex,
                                onTap: () async {
                                  await HapticService.light();
                                  provider.markNoteAsAccessed(note.id);
                                  
                                  // Capture search query before clearing
                                  final searchQuery = _searchController.text.isNotEmpty
                                      ? _searchController.text
                                      : null;
                                  
                                  // Clear search bar when navigating to note
                                  if (searchQuery != null) {
                                    _searchController.clear();
                                    context.read<NotesProvider>().setSearchQuery('');
                                  }
                                  
                                  await context.pushHero(
                                    NoteDetailScreen(
                                      noteId: note.id,
                                      searchQuery: searchQuery,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                              childCount: filteredNotes.length + 
                                  (hasPinned ? 1 : 0) + 
                                  (hasPinned && unpinnedNotes.isNotEmpty ? 1 : 0),
                              addAutomaticKeepAlives: true,
                              addRepaintBoundaries: true,
                                  ),
                                ),
                              );
                            }
                            },
                        ),
                      ],
                    );
                },
              ),
              
              // Recording Overlay - Full screen (background layer)
              if (_isRecording)
                RecordingOverlay(
                  isLocked: _isRecordingLocked,
                  isPaused: _isPaused,
                  onStop: _stopRecording,
                  onDiscard: _discardRecording,
                  onPause: _pauseRecording,
                  onResume: _resumeRecording,
                  recordingDuration: _recordingDuration,
                  amplitude: _currentAmplitude,
                  amplitudeHistory: _amplitudeHistory,
                ),
              
              // Microphone button - centered (or Organize button when viewing Unorganized)
              // Hide when search is focused or in chat mode
              if (!_isSearchFocused && !_isInChatMode)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Consumer<FoldersProvider>(
                      builder: (context, foldersProvider, child) {
                        final isViewingUnorganized = _currentFolderContext == foldersProvider.unorganizedFolderId;
                        
                        if (isViewingUnorganized) {
                          // Show Organize button when viewing unorganized folder
                          return FloatingActionButton.extended(
                            onPressed: () {
                              HapticService.medium();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OrganizationScreen()),
                              );
                            },
                            icon: const Icon(Icons.auto_fix_high),
                            label: Text(LocalizationService().t('organize')),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          );
                        } else {
                          // Show microphone button for all other views
                          return MicrophoneButton(
                            key: _microphoneKey,
                            onRecordingStart: _startRecording,
                            onRecordingStop: _stopRecording,
                            onRecordingLock: _onRecordingLock,
                            onRecordingUnlock: _onRecordingUnlock,
                          );
                        }
                      },
                    ),
                  ),
                ),
          
              // Chat overlay
              if (_isInChatMode)
                Positioned.fill(
                  child: AIChatOverlay(
                    messages: _chatMessages,
                    context: _chatContext,
                    isProcessing: _isAIProcessing,
                    onClose: _exitChatMode,
                    onAction: _handleChatAction,
                    onSendMessage: (message) async {
                      await _sendToAI(message);
                    },
                    onNoteTap: (noteId) async {
                      HapticService.light();
                      // Don't exit chat mode - let it persist in the background
                      
                      // Simply open the note - AI citations are general references
                      // not specific search queries, so we don't try to highlight anything
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteDetailScreen(
                            noteId: noteId,
                          ),
                        ),
                      );
                      // Chat will still be active when user returns
                    },
                    themeConfig: themeConfig,
                  ),
                ),
              
              // Recording Status Bar - Fixed at top
              Consumer<RecordingQueueService>(
                builder: (context, queueService, child) {
                  if (queueService.queue.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    child: const RecordingStatusBar(),
                  );
                },
              ),
              
                ],
              ),
            ),
          ),
        ),
          );
      },
    );
  }

  void _showOrganizeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const NoteOrganizationSheet(),
    );
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    // Get note context (use allNotes so search doesn't affect greeting)
    final provider = context.read<NotesProvider>();
    final filteredNotes = _getFilteredNotes(provider.allNotes);
    final noteCount = filteredNotes.length;
    final hasNotes = noteCount > 0;
    
    // Check if user created notes today
    final today = DateTime.now();
    int notesToday = 0;
    for (final note in filteredNotes) {
      if (note.updatedAt.year == today.year && 
          note.updatedAt.month == today.month && 
          note.updatedAt.day == today.day) {
        notesToday++;
      }
    }
    
    // Weekend morning override
    if (isWeekend && hour >= 6 && hour < 12) {
      return 'Weekend vibes 🎉';
    }
    
    // Context-aware messages
    if (notesToday >= 5) {
      return 'On a roll today 🔥';
    }
    
    if (!hasNotes) {
      return 'Ready to capture?';
    }
    
    // Time-based greetings with randomization
    final greetings = _getGreetingsForHour(hour);
    final randomIndex = (hour + now.minute) % greetings.length;
    return greetings[randomIndex];
  }
  
  List<String> _getGreetingsForHour(int hour) {
    if (hour >= 5 && hour < 8) {
      // Early Morning
      return [
        'Rise & shine ☀️',
        'Early bird gets the notes 🐦',
        'Fresh start, fresh ideas',
      ];
    } else if (hour >= 8 && hour < 12) {
      // Morning
      return [
        'Let\'s do this ✨',
        'Morning, genius 💡',
        'What\'s brewing?',
      ];
    } else if (hour >= 12 && hour < 14) {
      // Lunch
      return [
        'Midday brain dump 🧠',
        'Lunch thoughts?',
        'Afternoon fuel ⚡',
      ];
    } else if (hour >= 14 && hour < 17) {
      // Afternoon
      return [
        'Keep it rolling 🔥',
        'Afternoon vibes',
        'Ideas flowing?',
      ];
    } else if (hour >= 17 && hour < 21) {
      // Evening
      return [
        'Evening wind down 🌙',
        'Day\'s not over yet',
        'Golden hour thoughts ✨',
      ];
    } else if (hour >= 21 && hour < 24) {
      // Night
      return [
        
        'Late night genius',
        'Still going strong',
      ];
    } else {
      // Late Night (12am-5am)
      return [
        'Midnight thoughts 🌃',
        'Can\'t sleep? 💭',
        'Burning midnight oil 🕯️',
      ];
    }
  }
}
