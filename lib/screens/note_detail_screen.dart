import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/openai_service.dart';
import '../services/export_service.dart';
import '../widgets/tag_editor.dart';
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
  bool _showTagEditor = false;
  bool _isBeautifying = false;

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

    // Save as plain text
    final content = _contentController.text;

      final updatedNote = note.copyWith(
      name: _nameController.text.trim().isEmpty ? 'Untitled' : _nameController.text.trim(),
      content: content,
        updatedAt: DateTime.now(),
      );

    provider.updateNote(updatedNote);

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _beautifyNote() async {
    final plainText = _contentController.text;
    if (plainText.trim().isEmpty) return;
    
        HapticService.light();
    setState(() => _isBeautifying = true);
    
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }
      
      final openAIService = OpenAIService(apiKey: apiKey);
      final beautified = await openAIService.beautifyTranscription(plainText);
      
      _contentController.text = beautified;
      _saveNote();
      
      HapticService.success();
          if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
            CustomSnackbar.show(
              context,
          message: 'Note beautified! ✨',
              type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    } catch (e) {
      debugPrint('Error beautifying note: $e');
            if (mounted) {
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
                        CustomSnackbar.show(
                          context,
          message: 'Failed to beautify: $e',
          type: SnackbarType.error,
                    themeConfig: themeConfig,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBeautifying = false);
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

  // Pin and delete methods removed per user request

  Future<void> _shareNote(Note note, BuildContext context) async {
    try {
      await HapticService.light();
      
      final foldersProvider = context.read<FoldersProvider>();
      final folder = note.folderId != null 
          ? foldersProvider.getFolderById(note.folderId!)
          : null;
      
      // Export as human-readable Markdown
      final content = await ExportService.exportNoteAsMarkdown(
        note: note,
        folderName: folder?.name,
      );
      
      final filename = '${note.name.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.md';
      
      // Get the render box for positioning the share dialog on iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      
      await ExportService.shareExport(
        content: content,
        filename: filename,
        mimeType: 'text/markdown',
        sharePositionOrigin: sharePositionOrigin,
      );
      
      await HapticService.success();
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Note exported successfully',
          type: SnackbarType.success,
          themeConfig: themeConfig,
        );
      }
    } catch (e) {
      await HapticService.error();
      if (mounted) {
        final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
        CustomSnackbar.show(
          context,
          message: 'Failed to export note: ${e.toString()}',
          type: SnackbarType.error,
          themeConfig: themeConfig,
        );
      }
    }
  }

  void _toggleTagEditor() {
    HapticService.light();
      setState(() {
      _showTagEditor = !_showTagEditor;
    });
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
          return const Scaffold(
            body: Center(child: Text('Note not found')),
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
                          // Share button for exporting single note
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () => _shareNote(note, context),
                            tooltip: 'Share note',
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
                          const SizedBox(width: 12),

                          // Tags display
                          if (note.tags.isNotEmpty && !_showTagEditor)
                      Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
            child: Row(
                                  children: note.tags.take(3).map((tag) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                            ),
                            decoration: BoxDecoration(
                                        color: themeConfig.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: themeConfig.primaryColor.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                              child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              ),
                            ),
                          ),

                          if (!_showTagEditor) const Spacer(),

                          // Edit tags button
                          IconButton(
                            icon: Icon(_showTagEditor ? Icons.close : Icons.local_offer_outlined),
                            onPressed: _toggleTagEditor,
                            iconSize: 20,
                ),
              ],
            ),
          ),

                    // Tag editor (expanded)
                    if (_showTagEditor)
                  Container(
                        padding: const EdgeInsets.all(16),
                        child: TagEditor(
                          tags: note.tags,
                          onTagsChanged: (newTags) {
                            final updatedNote = note.copyWith(tags: newTags);
                            context.read<NotesProvider>().updateNote(updatedNote);
                          },
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
                          // Beautify button (only show when text exists)
                          if (_contentController.text.trim().isNotEmpty)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton.extended(
                                onPressed: _isBeautifying ? null : _beautifyNote,
                                icon: _isBeautifying
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(Icons.auto_fix_high),
                                label: Text(_isBeautifying ? 'Beautifying...' : 'Beautify'),
                                backgroundColor: themeConfig.primaryColor,
                                elevation: 8,
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

