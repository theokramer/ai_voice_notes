import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../services/openai_service.dart';
import '../widgets/quick_move_dialog.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import '../widgets/summary_display.dart';
import '../theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum NoteViewMode {
  transcription,
  summary,
}

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final String? searchQuery;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    this.searchQuery,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _transcriptionController;
  Timer? _saveTimer;
  bool _hasUnsavedChanges = false;
  NoteViewMode _viewMode = NoteViewMode.summary; // Default to summary view
  bool _transcriptionModified = false;
  bool _isRegeneratingSummary = false;
  String? _originalTranscription;

  @override
  void initState() {
    super.initState();
    final note = context.read<NotesProvider>().getNoteById(widget.noteId);
    if (note != null) {
      _nameController = TextEditingController(text: note.name);
      _transcriptionController = TextEditingController(
        text: note.rawTranscription ?? note.content,
      );
      _originalTranscription = note.rawTranscription ?? note.content;
    } else {
      _nameController = TextEditingController();
      _transcriptionController = TextEditingController();
    }

    _nameController.addListener(_onNameChanged);
    _transcriptionController.addListener(_onTranscriptionChanged);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _transcriptionController.removeListener(_onTranscriptionChanged);
    _nameController.dispose();
    _transcriptionController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
    _debouncedSave();
  }

  void _onTranscriptionChanged() {
    final note = context.read<NotesProvider>().getNoteById(widget.noteId);
    if (note != null) {
      final isModified = _transcriptionController.text != _originalTranscription;
      if (isModified != _transcriptionModified) {
        setState(() {
          _transcriptionModified = isModified;
        });
      }
    }
    
    setState(() {
      _hasUnsavedChanges = true;
    });
    _debouncedSave();
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveTranscription();
    });
  }

  void _saveTranscription() {
    final provider = context.read<NotesProvider>();
    final note = provider.getNoteById(widget.noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      name: _nameController.text.trim().isEmpty ? 'Untitled' : _nameController.text.trim(),
      rawTranscription: _transcriptionController.text,
      content: _transcriptionController.text, // Keep content in sync
      updatedAt: DateTime.now(),
    );

    provider.updateNote(updatedNote);

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _regenerateSummary() async {
    final provider = context.read<NotesProvider>();
    final note = provider.getNoteById(widget.noteId);
    if (note == null) return;

    setState(() {
      _isRegeneratingSummary = true;
    });

    HapticService.light();

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      final openAIService = OpenAIService(apiKey: apiKey);
      final summary = await openAIService.generateSummary(
        _transcriptionController.text,
        detectedLanguage: note.detectedLanguage,
      );

      final updatedNote = note.copyWith(
        summary: summary,
        updatedAt: DateTime.now(),
      );

      await provider.updateNote(updatedNote);

      // Update original transcription to reflect the new baseline
      _originalTranscription = _transcriptionController.text;

      setState(() {
        _isRegeneratingSummary = false;
        _transcriptionModified = false;
      });

      HapticService.success();

      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Summary regenerated',
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );

        // Switch to summary view to show the new summary
        setState(() {
          _viewMode = NoteViewMode.summary;
        });
      }
    } catch (e) {
      setState(() {
        _isRegeneratingSummary = false;
      });

      HapticService.error();

      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Failed to regenerate summary',
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    }
  }

  Future<void> _showMoveDialog(Note note) async {
    HapticService.light();
    final foldersProvider = context.read<FoldersProvider>();

    final newFolderId = await QuickMoveDialog.show(
      context: context,
      folders: foldersProvider.folders,
      currentFolderId: note.folderId,
      noteName: note.name,
    );

    if (newFolderId != null && mounted) {
      await context.read<NotesProvider>().moveNoteToFolder(note.id, newFolderId);
      HapticService.success();
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Note moved',
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotesProvider, SettingsProvider>(
      builder: (context, notesProvider, settingsProvider, child) {
        final note = notesProvider.getNoteById(widget.noteId);
        if (note == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
          return Scaffold(
            body: Center(child: Text(LocalizationService().t('note_not_found'))),
          );
        }

        final themeConfig = settingsProvider.currentThemeConfig;

        return WillPopScope(
          onWillPop: () async {
            if (_hasUnsavedChanges) {
              _saveTranscription();
              await Future.delayed(const Duration(milliseconds: 100));
            }
            return true;
          },
          child: Scaffold(
            body: AnimatedBackground(
              themeConfig: themeConfig,
              child: SafeArea(
                child: Column(
                  children: [
                    // Custom App Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              if (_hasUnsavedChanges) {
                                _saveTranscription();
                              }
                              Navigator.pop(context);
                            },
                          ),
                          // Note name editor
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Note title',
                                isDense: true,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Folder bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Folder badge
                          GestureDetector(
                            onTap: () => _showMoveDialog(note),
                            child: Consumer<FoldersProvider>(
                              builder: (context, foldersProvider, child) {
                                final folder = note.folderId != null
                                    ? foldersProvider.getFolderById(note.folderId!)
                                    : null;
                                final folderName = folder?.name ?? 'Unorganized';
                                final folderIcon = folder?.icon ?? '📂';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade700,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(folderIcon, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(
                                        folderName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Segmented Control for view mode
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade800,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSegmentButton(
                                label: 'Transcription',
                                icon: Icons.article,
                                isSelected: _viewMode == NoteViewMode.transcription,
                                onTap: () {
                                  HapticService.light();
                                  setState(() {
                                    _viewMode = NoteViewMode.transcription;
                                  });
                                },
                                accentColor: themeConfig.accentColor,
                              ),
                            ),
                            Expanded(
                              child: _buildSegmentButton(
                                label: 'Summary',
                                icon: Icons.auto_awesome,
                                isSelected: _viewMode == NoteViewMode.summary,
                                onTap: () {
                                  HapticService.light();
                                  setState(() {
                                    _viewMode = NoteViewMode.summary;
                                  });
                                },
                                accentColor: themeConfig.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content area
                    Expanded(
                      child: _viewMode == NoteViewMode.transcription
                          ? _buildTranscriptionView(note, themeConfig)
                          : _buildSummaryView(note, themeConfig),
                    ),
                  ],
                ),
              ),
            ),
            // Floating action button for regenerating summary
            floatingActionButton: _viewMode == NoteViewMode.transcription &&
                    _transcriptionModified &&
                    !_isRegeneratingSummary
                ? FloatingActionButton.extended(
                    onPressed: _regenerateSummary,
                    backgroundColor: themeConfig.accentColor,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Regenerate Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: accentColor.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? accentColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? accentColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionView(Note note, themeConfig) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _transcriptionController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.6,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start typing...',
          hintStyle: TextStyle(
            color: AppTheme.textTertiary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView(Note note, themeConfig) {
    return SummaryDisplay(
      summary: note.summary,
      isLoading: _isRegeneratingSummary,
      onGenerateSummary: () => _regenerateSummary(),
      accentColor: themeConfig.accentColor,
    );
  }
}
