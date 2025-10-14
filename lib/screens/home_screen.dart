import 'dart:async';
import 'dart:io';
import 'dart:math';
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
import '../widgets/ai_chat_overlay.dart';
import '../widgets/note_organization_sheet.dart';
import '../widgets/folder_selector.dart';
import '../widgets/recording_overlay.dart';
import '../widgets/recording_status_bar.dart';
import '../widgets/folder_management_dialog.dart';
import '../widgets/home/home_search_overlay.dart';
import '../widgets/home/home_ask_ai_button.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<MicrophoneButtonState> _microphoneKey = GlobalKey<MicrophoneButtonState>();
  bool _showSearchOverlay = false;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  
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
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: AppTheme.animationNormal,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeOutCubic,
    );
    _scrollController.addListener(_handleScroll);
    
    // Request microphone permission on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestMicPermissionIfNeeded();
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
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      // Detect overscroll at the top for pull-to-search
      if (_scrollController.offset < -50 && !_showSearchOverlay) {
        setState(() {
          _showSearchOverlay = true;
        });
        _searchAnimationController.forward();
        HapticService.light();
      }
    }
  }

  void _hideSearchOverlay() {
    if (_showSearchOverlay) {
      setState(() {
        _showSearchOverlay = false;
        _searchController.clear();
        context.read<NotesProvider>().setSearchQuery('');
      });
      _searchAnimationController.reverse();
      HapticService.light();
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
    
    // Hide search overlay when entering chat
    _hideSearchOverlay();
    
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
      final provider = context.read<NotesProvider>();
      final openAIService = OpenAIService(apiKey: dotenv.env['OPENAI_API_KEY'] ?? '');
      
      // Build conversation history
      final history = _chatMessages
          .where((m) => m.isUser)
          .map((m) => {'role': 'user', 'content': m.text})
          .toList();

      final response = await openAIService.chatCompletion(
        message: message,
        history: history,
        notes: provider.allNotes,
      );

      // Add AI response with citations
      final aiMessage = ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        noteCitations: response.noteCitations,
      );

      setState(() {
        _chatMessages.add(aiMessage);
        _isAIProcessing = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add(ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isAIProcessing = false;
      });
    }
  }

  void _undoLastAction() async {
    if (_lastAction == null) return;
    
    final provider = context.read<NotesProvider>();
    
    try {
      switch (_lastAction!['type']) {
        case 'create_note':
          final noteId = _undoData as String;
          await provider.deleteNote(noteId);
          break;
        case 'consolidate':
          final data = _undoData as Map<String, dynamic>;
          // Delete consolidated note
          await provider.deleteNote(data['consolidatedId']);
          // Restore original notes
          for (final note in data['originalNotes'] as List<Note>) {
            provider.addNote(note);
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
    final provider = context.read<NotesProvider>();
    
    try {
      switch (action.type) {
        case 'create_note':
        final noteName = action.data['noteName'] as String;
        
        final result = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => CreateNoteDialog(
            initialName: noteName,
          ),
        );

        if (result != null && mounted) {
          HapticService.success();
          final newNote = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result['name']!,
            icon: result['icon']!,
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          provider.addNote(newNote);
          
          // Save undo data
          _lastAction = {'type': 'create_note'};
          _undoData = newNote.id;
          
          setState(() {
            _chatMessages.add(ChatMessage(
              text: '✅ Created note "${result['name']}"!',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
          
          // Show undo snackbar
          if (mounted) {
            final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
            CustomSnackbar.show(
              context,
              message: LocalizationService().t('created_note', {'name': result['name'] ?? ''}),
              type: SnackbarType.success,
              actionLabel: 'UNDO',
              onAction: _undoLastAction,
              duration: const Duration(seconds: 4),
              themeConfig: themeConfig,
            );
          }
          
          // Navigate to the newly created note so user can see it
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(noteId: newNote.id),
              ),
            );
          }
        }
        break;
        
      case 'consolidate':
        final targetName = action.data['targetName'] as String;
        final noteIds = (action.data['noteIds'] as List).cast<String>();
        
        // Get all notes to consolidate
        final notesToConsolidate = provider.allNotes
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
        provider.addNote(consolidatedNote);
        
        // Delete old notes
        for (final note in notesToConsolidate) {
          await provider.deleteNote(note.id);
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
    HapticService.medium();

    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;
      _totalPausedDuration = Duration.zero; // Reset paused duration
      _pauseStartTime = null; // Reset pause start time
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

    // TODO: Implement real amplitude stream when available in record package
    // For now, simulate realistic amplitude changes with history tracking
    _amplitudeSubscription = Stream.periodic(const Duration(milliseconds: 50), (i) {
      // Create more realistic voice-like amplitude patterns
      final time = i * 0.05; // Time in seconds
      final baseAmplitude = -40.0; // Base quiet level
      
      // Add voice-like patterns (speaking, pauses, emphasis)
      double voicePattern = 0.0;
      if (time % 10 < 7) { // Speaking for 7 seconds, pause for 3
        // Simulate speech patterns with varying intensity
        voicePattern = 15.0 * (0.5 + 0.5 * sin(time * 2)) * (0.3 + 0.7 * cos(time * 0.7));
        
        // Add occasional emphasis (louder words)
        if (sin(time * 1.3) > 0.8) {
          voicePattern *= 1.5;
        }
      }
      
      // Add some natural variation
      final variation = 5.0 * sin(time * 3.7);
      
      final finalAmplitude = baseAmplitude + voicePattern + variation;
      return Amplitude(current: finalAmplitude.clamp(-60.0, 0.0), max: 0.0);
    }).listen((amplitude) {
      if (mounted) {
        setState(() {
          final newAmplitude = _normalizeAmplitude(amplitude.current);
          _currentAmplitude = newAmplitude;
          
          // Add to history (keep last 100 samples)
          _amplitudeHistory.add(newAmplitude);
          if (_amplitudeHistory.length > 100) {
            _amplitudeHistory.removeAt(0);
          }
        });
      }
    });

    // Use optimized recording service
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

    // Recording path no longer stored - handled by RecordingQueueService
  }

  Future<void> _stopRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.medium();
    
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
        openAIService: openAIService,
        notesProvider: context.read<NotesProvider>(),
        foldersProvider: context.read<FoldersProvider>(),
        settingsProvider: context.read<SettingsProvider>(),
      );
      
      // Show brief hint if enabled (only for explicit folder saves)
      final settings = context.read<SettingsProvider>().settings;
      if (settings.showOrganizationHints && mounted && _currentFolderContext != null) {
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
    HapticService.medium();
    
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
        initialIcon: note.icon,
      ),
    );

    if (result != null && mounted) {
      final provider = context.read<NotesProvider>();
      final updatedNote = note.copyWith(
        name: result['name'],
        icon: result['icon'],
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
        return Scaffold(
          body: GestureDetector(
            onTap: () {
              // Unfocus when tapping background
              FocusScope.of(context).unfocus();
              // Hide search overlay when tapping background
              _hideSearchOverlay();
            },
            child: AnimatedBackground(
            style: settingsProvider.settings.backgroundStyle,
            themeConfig: settingsProvider.currentThemeConfig,
            isSimpleMode: settingsProvider.isSimpleMode,
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
                              setState(() => _showSearchOverlay = true);
                              _searchAnimationController.forward();
                            },
                            onOrganizeTap: _showOrganizeBottomSheet,
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
                      // Add top padding when search is active
                      if (_showSearchOverlay)
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 30),
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
                                onHideSearchOverlay: _hideSearchOverlay,
                                onShowNoteOptions: _showNoteOptions,
                              );
                            }
                            // Grid View - using custom layout for varying heights
                            else if (viewType == NoteViewType.grid) {
                              return HomeNotesGrid(
                                notes: filteredNotes,
                                provider: provider,
                                                  searchQuery: _searchController.text,
                                onHideSearchOverlay: _hideSearchOverlay,
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
                                    _hideSearchOverlay();
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
              // Hide when search overlay is visible
              if (!_showSearchOverlay)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _showSearchOverlay ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSlide(
                      offset: _showSearchOverlay ? const Offset(0, 1) : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
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
                  ),
                ),
          
              // Pull-to-search overlay
              if (_showSearchOverlay)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HomeSearchOverlay(
                    animation: _searchAnimation,
                    searchController: _searchController,
                    isInChatMode: _isInChatMode,
                    primaryColor: themeConfig.primaryColor,
                    onClose: _hideSearchOverlay,
                    onChanged: (value) {
                      if (!_isInChatMode) {
                        context.read<NotesProvider>().setSearchQuery(value);
                        setState(() {}); // Rebuild to update Ask AI button
                      }
                    },
                    onSubmitted: (value) async {
                      if (value.trim().isEmpty) return;
                      if (_isInChatMode) {
                        await _sendToAI(value);
                        _searchController.clear();
                      }
                    },
                    askAIButton: HomeAskAIButton(
                      searchQuery: _searchController.text,
                      hasResults: _getFilteredNotes(context.read<NotesProvider>().notes).isNotEmpty,
                      primaryColor: themeConfig.primaryColor,
                      onTap: () {
                        HapticService.light();
                        _enterChatMode(_searchController.text.isNotEmpty 
                            ? _searchController.text 
                            : '');
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
    
    // Get note context
    final provider = context.read<NotesProvider>();
    final filteredNotes = _getFilteredNotes(provider.notes);
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
        'Night owl mode 🦉',
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
