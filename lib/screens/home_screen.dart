import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/recording_service.dart';
import '../services/openai_service.dart';
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
import '../widgets/minimalistic_note_card.dart';
import 'note_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _recordingPath;
  String? _transcribedText;
  bool _isTranscribing = false;
  bool _showSearchOverlay = false;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  
  // Chat mode state
  bool _isInChatMode = false;
  final List<ChatMessage> _chatMessages = [];
  String? _chatContext;
  bool _isAIProcessing = false;
  
  // Selection mode state
  bool _isInSelectionMode = false;
  
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
      ChatMessage aiMessage = ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        noteCitations: response.noteCitations,
      );

      // Handle actions
      if (response.actionType != null && response.actionData != null) {
        ChatAction? action;
        
        switch (response.actionType) {
          case 'create_note':
            action = ChatAction(
              type: 'create_note',
              description: 'Create note "${response.actionData}"',
              buttonLabel: 'Create Note',
              data: {'noteName': response.actionData},
            );
            break;
          case 'add_entry':
            final parts = response.actionData!.split(':');
            if (parts.length >= 2) {
              final noteId = parts[0];
              final entryText = parts.sublist(1).join(':');
              final note = provider.allNotes.firstWhere((n) => n.id == noteId, orElse: () => provider.allNotes.first);
              action = ChatAction(
                type: 'add_entry',
                description: 'Add to "${note.name}"',
                buttonLabel: 'Add Entry',
                data: {'noteId': noteId, 'entryText': entryText},
              );
            }
            break;
          case 'consolidate':
            final parts = response.actionData!.split(':');
            if (parts.length >= 2) {
              final targetName = parts[0];
              final noteIds = parts[1].split(',');
              action = ChatAction(
                type: 'consolidate',
                description: 'Consolidate ${noteIds.length} notes into "$targetName"',
                buttonLabel: 'Consolidate',
                data: {'targetName': targetName, 'noteIds': noteIds},
              );
            }
            break;
          case 'move_entry':
            final parts = response.actionData!.split(':');
            if (parts.length >= 3) {
              action = ChatAction(
                type: 'move_entry',
                description: 'Move entry between notes',
                buttonLabel: 'Move Entry',
                data: {
                  'sourceNoteId': parts[0],
                  'targetNoteId': parts[1],
                  'entryId': parts[2],
                },
              );
            }
            break;
        }
        
        if (action != null) {
          aiMessage = ChatMessage(
            text: response.text,
            isUser: false,
            timestamp: DateTime.now(),
            action: action,
            noteCitations: response.noteCitations,
          );
        }
      }

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
        case 'add_entry':
          final data = _undoData as Map<String, dynamic>;
          final note = provider.allNotes.firstWhere((n) => n.id == data['noteId']);
          final headlines = note.headlines.map((h) {
            if (h.id == data['headlineId']) {
              return h.copyWith(
                entries: h.entries.where((e) => e.id != data['entryId']).toList(),
              );
            }
            return h;
          }).toList();
          await provider.updateNote(note.copyWith(headlines: headlines));
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
          message: 'Action undone',
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    } catch (e) {
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Failed to undo action',
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
            headlines: [],
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
              message: 'Created note "${result['name']}"',
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
        
      case 'add_entry':
        final noteId = action.data['noteId'] as String;
        final entryText = action.data['entryText'] as String;
        
        // Try to find note by ID, fall back to finding by name if ID doesn't match
        Note note;
        try {
          note = provider.allNotes.firstWhere((n) => n.id == noteId);
        } catch (e) {
          // Try to find by partial ID match or name
          note = provider.allNotes.firstWhere(
            (n) => n.name.toLowerCase().contains(noteId.toLowerCase()),
            orElse: () => provider.allNotes.first,
          );
        }
        
        // Create new entry
        final entry = TextEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: entryText,
          createdAt: DateTime.now(),
        );
        
        // Add to first headline or create one
        List<Headline> headlines;
        if (note.headlines.isEmpty) {
          headlines = [
            Headline(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: 'Notes',
              entries: [entry],
              createdAt: DateTime.now(),
            ),
          ];
        } else {
          headlines = note.headlines.map((h) {
            if (h == note.headlines.first) {
              return h.copyWith(entries: [...h.entries, entry]);
            }
            return h;
          }).toList();
        }
        
        final updatedNote = note.copyWith(headlines: headlines);
        await provider.updateNote(updatedNote);
        
        // Save undo data
        _lastAction = {'type': 'add_entry'};
        _undoData = {
          'noteId': noteId,
          'headlineId': headlines.first.id,
          'entryId': entry.id,
        };
        
        HapticService.success();
        setState(() {
          _chatMessages.add(ChatMessage(
            text: '✅ Added entry to "${note.name}"!',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        
        // Show undo snackbar
        if (mounted) {
          final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
          CustomSnackbar.show(
            context,
            message: 'Added entry to "${note.name}"',
            type: SnackbarType.success,
            actionLabel: 'UNDO',
            onAction: _undoLastAction,
            duration: const Duration(seconds: 4),
            themeConfig: themeConfig,
          );
        }
        
        // Navigate to the note with the newly created entry highlighted
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteDetailScreen(
                noteId: note.id,
                highlightedEntryId: entry.id,
                autoCloseAfterDelay: false,
              ),
            ),
          );
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
        
        // Collect all headlines from all notes
        final allHeadlines = <Headline>[];
        for (final note in notesToConsolidate) {
          allHeadlines.addAll(note.headlines);
        }
        
        // Create new consolidated note
        final consolidatedNote = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: targetName,
          icon: notesToConsolidate.first.icon,
          headlines: allHeadlines,
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
            message: 'Consolidated ${notesToConsolidate.length} notes',
            type: SnackbarType.success,
            actionLabel: 'UNDO',
            onAction: _undoLastAction,
            duration: const Duration(seconds: 4),
            themeConfig: themeConfig,
          );
        }
        break;
        
      case 'move_entry':
        final sourceNoteId = action.data['sourceNoteId'] as String;
        final targetNoteId = action.data['targetNoteId'] as String;
        final entryId = action.data['entryId'] as String;
        
        await provider.moveEntry(sourceNoteId, '', targetNoteId, entryId);
        
        HapticService.success();
        setState(() {
          _chatMessages.add(ChatMessage(
            text: '✅ Moved entry!',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        break;
    }
    } catch (e) {
      // Handle any errors
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Failed to execute action: ${e.toString()}',
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
    
    for (final headline in note.headlines) {
      for (final entry in headline.entries) {
        if (entry.text.toLowerCase().contains(lowerQuery)) {
          // Find the position of the match
          final index = entry.text.toLowerCase().indexOf(lowerQuery);
          final start = (index - 50).clamp(0, entry.text.length);
          final end = (index + query.length + 50).clamp(0, entry.text.length);
          
          String snippet = entry.text.substring(start, end);
          if (start > 0) snippet = '...$snippet';
          if (end < entry.text.length) snippet = '$snippet...';
          
          snippets.add(snippet);
          if (snippets.length >= 2) return snippets;
        }
      }
    }
    
    return snippets;
  }

  // Estimate the height of a note card for grid layout balancing
  // This must match the actual NoteCard rendering in grid view
  double _estimateNoteCardHeight(Note note) {
    // Base structure for grid view (reduced padding):
    // top padding (12) + icon (48) + name row (16) + spacing (4) + date (13) + spacing (8)
    double height = 12.0 + 48.0 + 16.0 + 4.0 + 13.0 + 8.0; // ~101px
    
    // Get the latest entry text (same logic as NoteCard._getFirstSentence)
    final latestText = note.latestEntryText;
    
    if (latestText == null || latestText.isEmpty) {
      // "No content" text
      height += 12.0 * 1.4; // fontSize 12, height 1.4
      height += 12.0; // bottom padding (reduced)
      return height + 12.0; // margin bottom
    }
    
    // Calculate text that will actually be shown (first 35 words or less)
    final words = latestText.split(RegExp(r'\s+'));
    final displayedWords = words.length <= 35 ? words : words.take(35).toList();
    final displayedText = displayedWords.join(' ');
    
    // Estimate how many lines this text will take
    // In grid view, cards are narrower - estimate ~30-35 characters per line
    const charsPerLine = 32; // conservative estimate for grid width
    final estimatedLines = (displayedText.length / charsPerLine).ceil().clamp(1, 15);
    
    // Text height: fontSize 12 * lineHeight 1.4 = 16.8px per line
    final textHeight = estimatedLines * 16.8;
    height += textHeight;
    
    // Add search snippet height if there's a search query
    // (Note: we don't have search query here, but typically adds ~30-50px per snippet)
    
    // Bottom padding (reduced for grid view)
    height += 12.0;
    
    // Bottom margin
    height += 12.0;
    
    // Round to prevent floating point issues
    return height.roundToDouble().clamp(130.0, 600.0);
  }

  Future<void> _startRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.medium();

    // Use optimized recording service
    final result = await RecordingService().startRecording(_audioRecorder);

    if (!result.success) {
      if (mounted) {
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

    _recordingPath = result.recordingPath;
  }

  Future<void> _stopRecording() async {
    // Fire haptic feedback immediately (don't await)
    HapticService.medium();
    
    final stoppedPath = await RecordingService().stopRecording(_audioRecorder);

    if (stoppedPath == null && _recordingPath == null) {
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Failed to stop recording',
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
      return;
    }

    _startTranscription();
    _enterSelectionMode();
  }

  void _enterSelectionMode() {
    setState(() {
      _isInSelectionMode = true;
    });
    HapticService.light();
  }

  void _exitSelectionMode() {
    setState(() {
      _isInSelectionMode = false;
    });
    // Clear recording data if user cancels
    _recordingPath = null;
    _transcribedText = null;
    HapticService.light();
  }

  void _handleNoteSelectionInMode(Note note) async {
    // Exit selection mode
    setState(() {
      _isInSelectionMode = false;
    });
    
    // Process the recording
    await _processRecording(note);
  }

  void _handleCreateNoteInSelectionMode() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CreateNoteDialog(),
    );

    if (result != null && mounted) {
      HapticService.success();
      final provider = context.read<NotesProvider>();
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name']!,
        icon: result['icon']!,
        headlines: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provider.addNote(newNote);
      
      // Exit selection mode and process recording
      setState(() {
        _isInSelectionMode = false;
      });
      
      await _processRecording(newNote);
    }
  }

  Future<void> _startTranscription() async {
    if (_recordingPath == null) return;

    setState(() {
      _isTranscribing = true;
      _transcribedText = null;
    });

    try {
      final provider = context.read<NotesProvider>();
      _transcribedText = await provider.transcribeAudio(_recordingPath!);
    } catch (e) {
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Transcription failed: $e',
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  Future<void> _processRecording(Note note) async {
    if (_recordingPath == null) return;

    try {
      final provider = context.read<NotesProvider>();
      final themeConfig = context.read<SettingsProvider>().currentThemeConfig;

      // Show processing dialog immediately
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildProcessingDialog(
            isTranscribing: _isTranscribing,
            themeConfig: themeConfig,
          ),
        );
      }

      // Wait for transcription if still in progress (non-blocking for modal)
      String? transcribedText = _transcribedText;
      if (_isTranscribing) {
        // Wait for transcription to complete
        while (_isTranscribing && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        transcribedText = _transcribedText;
      }

      if (transcribedText == null || transcribedText.isEmpty) {
        throw Exception('Transcription failed or returned empty text');
      }

      // Add transcription to note and get the created entry ID
      final entryId = await provider.addTranscriptionToNote(transcribedText, note.id);

      // Close dialog immediately
      if (mounted) {
        Navigator.pop(context);
      }

      // Provide haptic feedback and navigate (fire-and-forget)
      HapticService.success();
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteDetailScreen(
              noteId: note.id,
              highlightedEntryId: entryId,
              autoCloseAfterDelay: true,
            ),
          ),
        );
      }

      _transcribedText = null;
      _recordingPath = null;
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        HapticService.error();
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Error processing recording: $e',
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    }
  }

  Widget _buildProcessingDialog({
    required bool isTranscribing,
    required ThemeConfig themeConfig,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing32),
            decoration: BoxDecoration(
              color: AppTheme.glassStrongSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: themeConfig.primaryColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  isTranscribing ? 'Transcribing...' : 'Organizing...',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  isTranscribing
                      ? 'Converting speech to text'
                      : 'Categorizing your note',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppTheme.animationFast)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: AppTheme.animationNormal,
          curve: Curves.easeOutBack,
        );
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
          message: 'Note updated',
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
                    'Delete Note?',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'This will permanently delete "${note.name}" and all its entries.',
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
          message: 'Note deleted',
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
                    title: note.isPinned ? 'Unpin Note' : 'Pin Note',
                    themeConfig: themeConfig,
                    onTap: () async {
                      Navigator.pop(context);
                      await context.read<NotesProvider>().toggleNotePin(note.id);
                      await HapticService.success();
                      if (mounted) {
                        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
                        CustomSnackbar.show(
                          context,
                          message: note.isPinned ? 'Note unpinned' : 'Note pinned',
                          type: SnackbarType.success,
                          themeConfig: themeConfig,
                        );
                      }
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.edit,
                    title: 'Edit Note',
                    themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                      _showEditNoteDialog(note);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Note',
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

                  if (provider.notes.isEmpty) {
                      if (_searchController.text.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing48),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipOval(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: AppTheme.glassStrongSurface,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.glassBorder, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.search_off,
                                        size: 40,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacing24),
                                Text(
                                  'No results found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                Text(
                                  'Try different search terms',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacing48),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppTheme.glassStrongSurface,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: AppTheme.glassBorder, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      size: 40,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacing24),
                              Text(
                                'No notes yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: AppTheme.spacing8),
                              Text(
                                'Press and hold the microphone\nto record your first note',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                              .animate()
                              .fadeIn(
                                duration: AppTheme.animationSlow,
                                delay: 200.ms,
                              )
                              .slideY(
                                begin: 0.1,
                                end: 0,
                                duration: AppTheme.animationSlow,
                                delay: 200.ms,
                              ),
                        ),
                      );
                    }

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
                        delegate: _AnimatedHeaderDelegate(
                          builder: _buildAnimatedHeader,
                          expandedHeight: 140.0 + MediaQuery.of(context).padding.top, // Increased by 10px to prevent overflow (greeting + search bar)
                          collapsedHeight: 56.0 + MediaQuery.of(context).padding.top, // Smaller collapsed height
                        ),
                      ),
                      // Add top padding when search is active
                      if (_showSearchOverlay)
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 30),
                        ),
                      // Notes list - View type based on provider setting
                        Consumer<NotesProvider>(
                          builder: (context, notesProvider, child) {
                            final viewType = notesProvider.noteViewType;
                            
                            // Minimalistic List View
                            if (viewType == NoteViewType.minimalisticList) {
                              final groupedNotes = notesProvider.groupNotesByTimePeriod(provider.notes);
                              final todayCount = groupedNotes['Today']!.length;
                              final thisWeekCount = groupedNotes['This Week']!.length;
                              final moreCount = groupedNotes['More']!.length;
                              
                              return SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    // Calculate which group and item we're rendering
                                    
                                    // Today section
                                    if (todayCount > 0 && index == 0) {
                                      return _buildSectionHeader('Today');
                                    }
                                    if (index > 0 && index <= todayCount) {
                                      final note = groupedNotes['Today']![index - 1];
                                      return GestureDetector(
                                        onLongPress: () => _isInSelectionMode ? null : _showNoteOptions(note),
                                        child: MinimalisticNoteCard(
                                          note: note,
                                          index: index - 1,
                                          onTap: () async {
                                            await HapticService.light();
                                            if (_isInSelectionMode) {
                                              _handleNoteSelectionInMode(note);
                                            } else {
                                              provider.markNoteAsAccessed(note.id);
                                              if (_searchController.text.isNotEmpty) {
                                                _hideSearchOverlay();
                                              }
                                              await context.pushHero(
                                                NoteDetailScreen(noteId: note.id),
                                              );
                                            }
                                          },
                                        ),
                                      );
                                    }
                                    
                                    // This Week section
                                    int weekStartIndex = todayCount > 0 ? todayCount + 1 : 0;
                                    if (thisWeekCount > 0 && index == weekStartIndex) {
                                      return _buildSectionHeader('This Week');
                                    }
                                    if (index > weekStartIndex && index <= weekStartIndex + thisWeekCount) {
                                      final note = groupedNotes['This Week']![index - weekStartIndex - 1];
                                      return GestureDetector(
                                        onLongPress: () => _isInSelectionMode ? null : _showNoteOptions(note),
                                        child: MinimalisticNoteCard(
                                          note: note,
                                          index: index - weekStartIndex - 1,
                                          onTap: () async {
                                            await HapticService.light();
                                            if (_isInSelectionMode) {
                                              _handleNoteSelectionInMode(note);
                                            } else {
                                              provider.markNoteAsAccessed(note.id);
                                              if (_searchController.text.isNotEmpty) {
                                                _hideSearchOverlay();
                                              }
                                              await context.pushHero(
                                                NoteDetailScreen(noteId: note.id),
                                              );
                                            }
                                          },
                                        ),
                                      );
                                    }
                                    
                                    // More section
                                    int moreStartIndex = weekStartIndex + (thisWeekCount > 0 ? thisWeekCount + 1 : 0);
                                    if (groupedNotes['More']!.isNotEmpty && index == moreStartIndex) {
                                      return _buildSectionHeader('More');
                                    }
                                    if (index > moreStartIndex) {
                                      final note = groupedNotes['More']![index - moreStartIndex - 1];
                                      return GestureDetector(
                                        onLongPress: () => _isInSelectionMode ? null : _showNoteOptions(note),
                                        child: MinimalisticNoteCard(
                                          note: note,
                                          index: index - moreStartIndex - 1,
                                          onTap: () async {
                                            await HapticService.light();
                                            if (_isInSelectionMode) {
                                              _handleNoteSelectionInMode(note);
                                            } else {
                                              provider.markNoteAsAccessed(note.id);
                                              if (_searchController.text.isNotEmpty) {
                                                _hideSearchOverlay();
                                              }
                                              await context.pushHero(
                                                NoteDetailScreen(noteId: note.id),
                                              );
                                            }
                                          },
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  childCount: (todayCount > 0 ? todayCount + 1 : 0) +
                                      (thisWeekCount > 0 ? thisWeekCount + 1 : 0) +
                                      (moreCount > 0 ? moreCount + 1 : 0),
                                ),
                              );
                            }
                            // Grid View - using custom layout for varying heights
                            else if (viewType == NoteViewType.grid) {
                              final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;
                              final notes = provider.notes;
                              
                              // Group notes into columns for masonry effect with balanced heights
                              // Track column heights to balance the layout
                              final columns = List.generate(crossAxisCount, (_) => <Note>[]);
                              final columnHeights = List.generate(crossAxisCount, (_) => 0.0);
                              
                              // Distribute notes by adding each to the shortest column
                              // This maintains roughly the same sort order while balancing heights
                              for (var i = 0; i < notes.length; i++) {
                                final note = notes[i];
                                
                                // Estimate note height based on content
                                final estimatedHeight = _estimateNoteCardHeight(note);
                                
                                // Find the shortest column
                                // When heights are equal, prefer the column with fewer items (better distribution)
                                var shortestColumnIndex = 0;
                                var shortestHeight = columnHeights[0];
                                
                                for (var col = 1; col < crossAxisCount; col++) {
                                  // Use <= to ensure we check all columns
                                  // Prefer the column with shorter height, or if equal, the one with fewer items
                                  if (columnHeights[col] < shortestHeight ||
                                      (columnHeights[col] == shortestHeight && 
                                       columns[col].length < columns[shortestColumnIndex].length)) {
                                    shortestHeight = columnHeights[col];
                                    shortestColumnIndex = col;
                                  }
                                }
                                
                                // Add note to the shortest column
                                columns[shortestColumnIndex].add(note);
                                columnHeights[shortestColumnIndex] += estimatedHeight;
                              }
                              
                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing16,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: List.generate(crossAxisCount, (columnIndex) {
                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: columnIndex == 0 ? 0 : AppTheme.spacing4,
                                            right: columnIndex == crossAxisCount - 1 ? 0 : AppTheme.spacing4,
                                          ),
                                          child: Column(
                                            children: columns[columnIndex].map((note) {
                                              final index = notes.indexOf(note);
                                              final snippets = _extractSnippets(note, _searchController.text);
                                              
                                              return GestureDetector(
                                                onLongPress: () => _isInSelectionMode ? null : _showNoteOptions(note),
                                                child: NoteCard(
                                                  note: note,
                                                  searchQuery: _searchController.text,
                                                  matchedSnippets: snippets,
                                                  index: index,
                                                  isGridView: true,
                                                  onTap: () async {
                                                    await HapticService.light();
                                                    if (_isInSelectionMode) {
                                                      _handleNoteSelectionInMode(note);
                                                    } else {
                                                      provider.markNoteAsAccessed(note.id);
                                                      
                                                      final searchQuery = _searchController.text.isNotEmpty
                                                          ? _searchController.text
                                                          : null;
                                                      
                                                      if (searchQuery != null) {
                                                        _hideSearchOverlay();
                                                      }
                                                      
                                                      await context.pushHero(
                                                        NoteDetailScreen(
                                                          noteId: note.id,
                                                          searchQuery: searchQuery,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              )
                                                  .animate(
                                                    onPlay: (controller) => controller.repeat(reverse: true),
                                                  )
                                                  .shimmer(
                                                    duration: 2000.ms,
                                                    delay: (index * 100 + 2000).ms,
                                                    color: Colors.white.withOpacity(0.3),
                                                  );
                                            }).toList(),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              );
                            }
                            // Standard List View
                            else {
                              // List view with pinned section
                              final pinnedNotes = provider.notes.where((n) => n.isPinned).toList();
                              final unpinnedNotes = provider.notes.where((n) => !n.isPinned).toList();
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
                              onLongPress: () => _isInSelectionMode ? null : _showNoteOptions(note),
                              child: NoteCard(
                                note: note,
                                searchQuery: _searchController.text,
                                      matchedSnippets: snippets,
                                index: adjustedIndex,
                                onTap: () async {
                                  await HapticService.light();
                                  if (_isInSelectionMode) {
                                    _handleNoteSelectionInMode(note);
                                  } else {
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
                                  }
                                },
                              ),
                            ),
                          );
                        },
                              childCount: provider.notes.length + 
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
              
              // Microphone button - centered
              Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: MicrophoneButton(
                onRecordingStart: _startRecording,
                onRecordingStop: _stopRecording,
              ),
            ),
          ),
          
              // Pull-to-search overlay
              if (_showSearchOverlay)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildSearchOverlay(themeConfig),
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
              
              // Selection mode overlay (just the banner at top, notes remain clickable)
              if (_isInSelectionMode)
                _buildSelectionModeOverlay(),
            ],
              ),
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildSelectionModeOverlay() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact banner at top
                Container(
                  margin: const EdgeInsets.all(AppTheme.spacing16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing20,
                          vertical: AppTheme.spacing16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black.withOpacity(0.75),
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(
                            color: themeConfig.primaryColor.withOpacity(0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeConfig.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icon indicator
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacing8),
                              decoration: BoxDecoration(
                                color: themeConfig.primaryColor.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                border: Border.all(
                                  color: themeConfig.primaryColor.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                _isTranscribing ? Icons.transcribe : Icons.touch_app,
                                size: 20,
                                color: themeConfig.primaryColor,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isTranscribing 
                                        ? 'Transcribing...'
                                        : 'Select a note',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                  ),
                                  if (!_isTranscribing)
                                    Text(
                                      'Choose where to save your entry',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            // Action buttons
                            GestureDetector(
                              onTap: _handleCreateNoteInSelectionMode,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing12,
                                  vertical: AppTheme.spacing8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      themeConfig.buttonColor,
                                      themeConfig.buttonColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeConfig.buttonColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'New',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            // Cancel button
                            GestureDetector(
                              onTap: _exitSelectionMode,
                              child: Container(
                                padding: const EdgeInsets.all(AppTheme.spacing8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: AppTheme.animationFast)
                    .slideY(begin: -0.5, end: 0, duration: AppTheme.animationNormal, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchOverlay(ThemeConfig themeConfig) {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -100 * (1 - _searchAnimation.value)),
          child: Opacity(
            opacity: _searchAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7 * _searchAnimation.value),
                        Colors.black.withValues(alpha: 0.4 * _searchAnimation.value),
                        Colors.black.withValues(alpha: 0.1 * _searchAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacing48,
                    bottom: AppTheme.spacing8,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.glassStrongSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(
                              color: themeConfig.primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeConfig.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  hintText: _isInChatMode
                                      ? 'Ask AI...'
                                      : 'Search notes or ask AI...',
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                  prefixIcon: Icon(
                                    _isInChatMode ? Icons.psychology : Icons.search,
                                    color: _isInChatMode ? themeConfig.primaryColor : AppTheme.textTertiary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppTheme.textTertiary,
                                    ),
                                    onPressed: _hideSearchOverlay,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                                ),
                                onChanged: (value) {
                                  if (!_isInChatMode) {
                                    context.read<NotesProvider>().setSearchQuery(value);
                                    setState(() {}); // Rebuild to update Ask AI button
                                  }
                                },
                                onSubmitted: (value) async {
                                  if (value.trim().isEmpty) return;
                                  
                                  if (_isInChatMode) {
                                    // Send to AI
                                    await _sendToAI(value);
                                    _searchController.clear();
                                  }
                                  // In search mode, do nothing (live filtering already happens)
                                },
                              ),
                              const SizedBox(height: AppTheme.spacing12),
                              // Ask AI button
                              _buildAskAIButton(context.read<NotesProvider>(), themeConfig),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAskAIButton(NotesProvider provider, ThemeConfig themeConfig) {
    final hasQuery = _searchController.text.isNotEmpty;
    final hasResults = provider.notes.isNotEmpty;
    final noResults = hasQuery && !hasResults;
    
    final buttonText = hasQuery 
        ? 'Ask AI about "${_searchController.text}"'
        : 'Ask AI';
    
    return AnimatedContainer(
      duration: AppTheme.animationNormal,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing24,
          0,
          AppTheme.spacing24,
          AppTheme.spacing16,
        ),
        child: GestureDetector(
          onTap: () {
            HapticService.light();
            _enterChatMode(_searchController.text.isNotEmpty 
                ? _searchController.text 
                : '');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: AppTheme.animationNormal,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  gradient: hasQuery
                      ? LinearGradient(
                          colors: [
                            themeConfig.primaryColor.withValues(alpha: 0.25),
                            themeConfig.primaryColor.withValues(alpha: 0.15),
                          ],
                        )
                      : null,
                  color: hasQuery ? null : AppTheme.glassSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: hasQuery
                        ? themeConfig.primaryColor.withValues(alpha: 0.5)
                        : AppTheme.glassBorder,
                    width: hasQuery ? 2 : 1.5,
                  ),
                  boxShadow: hasQuery
                      ? [
                          BoxShadow(
                            color: themeConfig.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: AppTheme.animationNormal,
                      child: Icon(
                        Icons.psychology,
                        key: ValueKey(hasQuery),
                        size: 20,
                        color: hasQuery ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: AppTheme.animationNormal,
                        curve: Curves.easeOutCubic,
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              color: hasQuery ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: hasQuery ? FontWeight.w600 : FontWeight.w500,
                            ),
                        child: Text(
                          buttonText,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            )
            .shimmer(
              duration: noResults ? 1500.ms : 3000.ms,
              delay: noResults ? 0.ms : 5000.ms,
            ),
      ),
    );
  }

  void _showOrganizeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const NoteOrganizationSheet(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing16,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    // Get note context
    final provider = context.read<NotesProvider>();
    final noteCount = provider.notes.length;
    final hasNotes = noteCount > 0;
    
    // Check if user created notes today
    final today = DateTime.now();
    int notesToday = 0;
    for (final note in provider.notes) {
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
  
  Widget _buildAnimatedHeader(double progress) {
    // Get safe area insets
    final safePadding = MediaQuery.of(context).padding.top;
    
    // Interpolate values based on scroll progress
    final double fontSize = 28 - (progress * 10); // 28 -> 18
    final double topPadding = 40 - (progress * 24); // 40 -> 16
    final double horizontalPadding = 24.0; // Fixed 24px to align with note cards
    final double iconOpacity = 0.85 + ((1 - progress) * 0.15);
    
    // Search bar and greeting scale down during transition
    final double searchBarHeight = 40 - (progress * 15); // 40 -> 25 (shrinks)
    final double greetingBottomPadding = 20 - (progress * 16); // 20 -> 4 (shrinks spacing)
    
    // Control when elements appear/disappear - better transition timing
    // Only show expanded when progress < 0.8 (mostly expanded)
    final double expandedOpacity = (1.0 - progress).clamp(0.0, 1.0);
    // Only show collapsed when progress > 0.7 (mostly scrolled)  
    final double collapsedOpacity = ((progress - 0.7) * 3.33).clamp(0.0, 1.0);
    
    // Background opacity increases as we scroll
    final double backgroundOpacity = progress * 0.5; // More visible when scrolled
    final double blurAmount = progress * 20;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassDarkSurface.withValues(alpha: backgroundOpacity),
            border: progress > 0.5 ? const Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder,
                width: 1.5,
              ),
            ) : null,
          ),
          child: Stack(
            children: [
              // EXPANDED STATE: Greeting + Search Bar
              if (expandedOpacity > 0)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: safePadding + topPadding,
                  child: Opacity(
                    opacity: expandedOpacity.clamp(0.0, 1.0),
                    child: IgnorePointer(
                      ignoring: expandedOpacity < 0.3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Greeting text with dynamic padding
                          Padding(
                            padding: EdgeInsets.only(bottom: greetingBottomPadding.clamp(4.0, 20.0)),
                            child: Text(
                              _getGreeting(),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                    color: AppTheme.textPrimary.withOpacity(0.9),
                                  ),
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                            ),
                          ),
                          // Search bar with ellipsis - shrinks during scroll
                          Row(
                            children: [
                              // Search bar - fills available width
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticService.light();
                                    setState(() {
                                      _showSearchOverlay = true;
                                    });
                                    _searchAnimationController.forward();
                                  },
                                  child: Container(
                                    height: searchBarHeight.clamp(25.0, 40.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.glassSurface.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.glassBorder.withOpacity(0.25),
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 16,
                                          color: AppTheme.textSecondary.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ask AI',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary.withOpacity(0.7),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Ellipsis button - matches search bar height
                              GestureDetector(
                                onTap: () {
                                  HapticService.light();
                                  _showOrganizeBottomSheet();
                                },
                                child: Container(
                                  width: searchBarHeight.clamp(25.0, 40.0),
                                  height: searchBarHeight.clamp(25.0, 40.0),
                                  decoration: BoxDecoration(
                                    color: AppTheme.glassSurface.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.glassBorder.withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.more_horiz,
                                      size: 18,
                                      color: AppTheme.textPrimary.withOpacity(0.7),
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
              
              // COLLAPSED STATE: Home title with search and settings icons
              if (collapsedOpacity > 0)
                Positioned.fill(
                  top: safePadding,
                  child: Opacity(
                    opacity: collapsedOpacity.clamp(0.0, 1.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Search icon on left
                          GestureDetector(
                            onTap: () {
                              HapticService.light();
                              setState(() {
                                _showSearchOverlay = true;
                              });
                              _searchAnimationController.forward();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.search,
                                size: 22,
                                color: AppTheme.textPrimary.withOpacity(iconOpacity),
                              ),
                            ),
                          ),
                          // "Home" title - centered
                          Expanded(
                            child: Text(
                              'Home',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: AppTheme.textPrimary,
                                  ),
                              overflow: TextOverflow.visible,
                              maxLines: 1,
                            ),
                          ),
                          // Settings icon on right
                          GestureDetector(
                            onTap: () async {
                              await HapticService.light();
                              await context.pushHero(const SettingsScreen());
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.settings_outlined,
                                size: 22,
                                color: AppTheme.textPrimary.withOpacity(iconOpacity),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Settings icon for expanded state (top-right)
              if (expandedOpacity > 0)
                Positioned(
                  top: safePadding + 8,
                  right: 24,
                  child: Opacity(
                    opacity: expandedOpacity.clamp(0.0, 1.0),
                    child: GestureDetector(
                      onTap: () async {
                        await HapticService.light();
                        await context.pushHero(const SettingsScreen());
                      },
                      child: Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: AppTheme.textPrimary.withOpacity(iconOpacity),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom SliverPersistentHeaderDelegate for animated header
class _AnimatedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double) builder;
  final double expandedHeight;
  final double collapsedHeight;

  _AnimatedHeaderDelegate({
    required this.builder,
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate progress based on how much the header has shrunk
    final double shrinkProgress = (shrinkOffset / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
    return SizedBox.expand(
      child: builder(shrinkProgress),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _AnimatedHeaderDelegate oldDelegate) {
    return true; // Always rebuild for smooth animation
  }
}

