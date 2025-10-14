import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../widgets/quick_move_dialog.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import '../theme/app_theme.dart';

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
  late TextEditingController _contentController;
  Timer? _saveTimer;
  bool _hasUnsavedChanges = false;
  bool _showingRawTranscription = false; // false = show beautified/content, true = show raw

  @override
  void initState() {
    super.initState();
    final note = context.read<NotesProvider>().getNoteById(widget.noteId);
    if (note != null) {
      _nameController = TextEditingController(text: note.name);
      _contentController = TextEditingController(text: _extractPlainText(note.content));
    } else {
      _nameController = TextEditingController();
      _contentController = TextEditingController();
    }

    _nameController.addListener(_onNameChanged);
    _contentController.addListener(_onContentChanged);
  }

  String _extractPlainText(String content) {
    if (content.isEmpty) return '';
    
    try {
      // Try to parse as Quill Delta JSON
      final json = jsonDecode(content);
      if (json is List) {
        final buffer = StringBuffer();
        for (final op in json) {
          if (op is Map && op.containsKey('insert')) {
            final data = op['insert'];
            if (data is String) {
              buffer.write(data);
            }
          }
        }
        return buffer.toString();
      }
    } catch (e) {
      // Not JSON, return as-is
    }
    
    return content;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _contentController.removeListener(_onContentChanged);
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
    _debouncedSave();
  }

  void _onContentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
    _debouncedSave();
  }

  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _saveNote();
    });
  }

  void _saveNote() {
    final provider = context.read<NotesProvider>();
    final note = provider.getNoteById(widget.noteId);
    if (note == null) return;

    // Save content to the appropriate field based on current view mode
    final content = _contentController.text;

    final updatedNote = note.copyWith(
      name: _nameController.text.trim().isEmpty ? 'Untitled' : _nameController.text.trim(),
      content: content, // Always update main content
      // Update the specific field being edited
      rawTranscription: _showingRawTranscription ? content : note.rawTranscription,
      beautifiedContent: !_showingRawTranscription ? content : note.beautifiedContent,
      updatedAt: DateTime.now(),
    );

    provider.updateNote(updatedNote);

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  void _toggleViewMode() {
    final note = context.read<NotesProvider>().getNoteById(widget.noteId);
    if (note == null) return;

    // Save current changes before switching
    if (_hasUnsavedChanges) {
      _saveNote();
    }

    HapticService.light();
    
    setState(() {
      _showingRawTranscription = !_showingRawTranscription;
      
      // Update content controller based on view mode
      if (_showingRawTranscription) {
        // Show raw transcription (fallback to content if not available)
        _contentController.text = _extractPlainText(note.rawTranscription ?? note.content);
      } else {
        // Show beautified content (fallback to content if not available)
        _contentController.text = _extractPlainText(note.beautifiedContent ?? note.content);
      }
    });
  }

  Future<void> _showMoveDialog(Note note) async {
                            HapticService.light();
    final foldersProvider = context.read<FoldersProvider>();

    final newFolderId = await QuickMoveDialog.show(
      context: context,
      folders: foldersProvider.folders,
      currentFolderId: note.folderId,
      noteIcon: note.icon,
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

  // Pin, delete, and share methods removed per user request

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
              _saveNote();
              await Future.delayed(const Duration(milliseconds: 100));
            }
            return true;
          },
          child: Scaffold(
            body: AnimatedBackground(
              style: settingsProvider.settings.backgroundStyle,
              themeConfig: themeConfig,
              isSimpleMode: settingsProvider.isSimpleMode,
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
                                _saveNote();
                              }
                              Navigator.pop(context);
                            },
                          ),
                          // Note icon
                          Text(
                            note.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
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
                          // View mode toggle (show if either raw transcription or beautified content exists)
                          if (note.rawTranscription != null || note.beautifiedContent != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Material(
                                color: _showingRawTranscription 
                                    ? themeConfig.accentColor.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: _toggleViewMode,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showingRawTranscription ? Icons.article : Icons.auto_awesome,
                                          size: 18,
                                          color: _showingRawTranscription 
                                              ? themeConfig.accentColor 
                                              : Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _showingRawTranscription ? 'Raw' : 'Summary',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _showingRawTranscription 
                                                ? themeConfig.accentColor 
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Folder and Tags bar
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
                                        style: TextStyle(
                                          color: Colors.white,
                                              fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
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

                    // Plain text editor with beautify button
                    Expanded(
                      child: Stack(
                    children: [
                          // Text editor
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _contentController,
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
                          ),
                        ],
                ),
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
}

