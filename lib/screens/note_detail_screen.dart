import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/recording_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/unified_note_view.dart';
import '../widgets/animated_background.dart';
import '../widgets/move_entry_sheet.dart';
import '../widgets/create_note_dialog.dart';
import '../theme/app_theme.dart';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  final bool highlightLastEntry;
  final String? searchQuery;

  const NoteDetailScreen({
    super.key,
    required this.noteId,
    this.highlightLastEntry = false,
    this.searchQuery,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  String? _editingEntryId;
  String? _editingHeadlineId;
  bool _isEditingTitle = false;
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, TextEditingController> _headlineControllers = {};
  final Map<String, FocusNode> _headlineFocusNodes = {};
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _titleFocusListenerAdded = false;
  
  // Debounce timer for auto-save
  Timer? _debounceTimer;
  
  // Recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  bool _isTranscribing = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _audioRecorder.dispose();
    // Clean up controllers and focus nodes
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    for (var controller in _headlineControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _headlineFocusNodes.values) {
      focusNode.dispose();
    }
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _startEditing(TextEntry entry) {
    setState(() {
      _editingEntryId = entry.id;
      if (!_editControllers.containsKey(entry.id)) {
        final controller = TextEditingController(text: entry.text);
        _editControllers[entry.id] = controller;
        final focusNode = FocusNode();
        _focusNodes[entry.id] = focusNode;
        
        // Auto-save asynchronously on text change
        controller.addListener(() {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (_editingEntryId == entry.id) {
              final provider = context.read<NotesProvider>();
              final note = provider.notes.firstWhere((n) => n.headlines.any((h) => h.entries.any((e) => e.id == entry.id)));
              final headline = note.headlines.firstWhere((h) => h.entries.any((e) => e.id == entry.id));
              _saveEditSilently(note.id, headline.id, entry);
            }
          });
        });
        
        // Also save when focus is lost
        focusNode.addListener(() {
          if (!focusNode.hasFocus && _editingEntryId == entry.id) {
            _debounceTimer?.cancel();
            final provider = context.read<NotesProvider>();
            final note = provider.notes.firstWhere((n) => n.headlines.any((h) => h.entries.any((e) => e.id == entry.id)));
            final headline = note.headlines.firstWhere((h) => h.entries.any((e) => e.id == entry.id));
            _saveEdit(note.id, headline.id, entry);
          }
        });
      }
    });
    // Request focus after the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[entry.id]?.requestFocus();
    });
  }
  
  Future<void> _saveEditSilently(String noteId, String headlineId, TextEntry entry) async {
    final controller = _editControllers[entry.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newText = controller.text.trim();
      if (newText != entry.text) {
        final provider = context.read<NotesProvider>();
        await provider.updateEntry(noteId, headlineId, entry.id, newText);
      }
    }
  }

  void _startEditingHeadline(Headline headline) {
    setState(() {
      _editingHeadlineId = headline.id;
      if (!_headlineControllers.containsKey(headline.id)) {
        _headlineControllers[headline.id] = TextEditingController(text: headline.title);
        final focusNode = FocusNode();
        _headlineFocusNodes[headline.id] = focusNode;
        
        // Add listener for auto-save on blur
        focusNode.addListener(() {
          if (!focusNode.hasFocus && _editingHeadlineId == headline.id) {
            final provider = context.read<NotesProvider>();
            final note = provider.notes.firstWhere((n) => n.headlines.any((h) => h.id == headline.id));
            _saveHeadlineEdit(note.id, headline);
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headlineFocusNodes[headline.id]?.requestFocus();
    });
  }

  void _stopEditing() {
    setState(() {
      _editingEntryId = null;
    });
  }

  void _stopEditingHeadline() {
    setState(() {
      _editingHeadlineId = null;
    });
  }

  void _startEditingTitle(String currentTitle) {
    setState(() {
      _isEditingTitle = true;
      _titleController.text = currentTitle;
    });
    
    // Add listener for auto-save on blur (only once)
    if (!_titleFocusListenerAdded) {
      _titleFocusListenerAdded = true;
      _titleFocusNode.addListener(() {
        if (!_titleFocusNode.hasFocus && _isEditingTitle) {
          final provider = context.read<NotesProvider>();
          final note = provider.notes.firstWhere((n) => n.id == widget.noteId);
          _saveTitle(note.id, note.name);
        }
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  void _stopEditingTitle() {
    setState(() {
      _isEditingTitle = false;
    });
  }

  Future<void> _saveTitle(String noteId, String currentTitle) async {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != currentTitle) {
      final provider = context.read<NotesProvider>();
      final note = provider.notes.firstWhere((n) => n.id == noteId);
      final updatedNote = note.copyWith(
        name: newTitle,
        updatedAt: DateTime.now(),
      );
      await provider.updateNote(updatedNote);
      await HapticService.success();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Note renamed',
          type: SnackbarType.success,
        );
      }
    }
    _stopEditingTitle();
  }

  Future<void> _saveEdit(String noteId, String headlineId, TextEntry entry) async {
    final controller = _editControllers[entry.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newText = controller.text.trim();
      if (newText != entry.text) {
        final provider = context.read<NotesProvider>();
        await provider.updateEntry(noteId, headlineId, entry.id, newText);
        await HapticService.light();
        // Silent save - no snackbar for elegant inline editing
      }
    }
    _stopEditing();
  }

  Future<void> _saveHeadlineEdit(String noteId, Headline headline) async {
    final controller = _headlineControllers[headline.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newTitle = controller.text.trim();
      if (newTitle != headline.title) {
        final provider = context.read<NotesProvider>();
        await provider.updateHeadlineTitle(noteId, headline.id, newTitle);
        await HapticService.success();
        if (mounted) {
          CustomSnackbar.show(
            context,
            message: 'Section renamed',
            type: SnackbarType.success,
          );
        }
      }
    }
    _stopEditingHeadline();
  }

  void _showEntryOptions(String noteId, String headlineId, TextEntry entry, Headline headline) async {
    await HapticService.light();
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
              child: SingleChildScrollView(
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
                      icon: Icons.copy,
                      title: 'Copy Text',
                      themeConfig: themeConfig,
                      onTap: () async {
                        Navigator.pop(context);
                        await Clipboard.setData(ClipboardData(text: entry.text));
                        await HapticService.success();
                        if (mounted) {
                          CustomSnackbar.show(
                            context,
                            message: 'Text copied to clipboard',
                            type: SnackbarType.success,
                          );
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.content_copy,
                      title: 'Duplicate Entry',
                      themeConfig: themeConfig,
                      onTap: () async {
                        Navigator.pop(context);
                        final provider = context.read<NotesProvider>();
                        await provider.duplicateEntry(noteId, headlineId, entry.id);
                        await HapticService.success();
                        if (mounted) {
                          CustomSnackbar.show(
                            context,
                            message: 'Entry duplicated',
                            type: SnackbarType.success,
                          );
                        }
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.drive_file_move_outline,
                      title: 'Move to Section',
                      themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                        _showMoveToSectionDialog(noteId, headlineId, entry.id);
                    },
                  ),
                  _buildOptionTile(
                      icon: Icons.note_add_outlined,
                      title: 'Move to Note',
                      themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                        _showMoveToNoteDialog(noteId, headlineId, entry);
                    },
                  ),
                  _buildOptionTile(
                      icon: Icons.share,
                      title: 'Share Entry',
                      themeConfig: themeConfig,
                    onTap: () async {
                      Navigator.pop(context);
                        // We'll need to add share_plus package for this
                      await Clipboard.setData(ClipboardData(text: entry.text));
                      await HapticService.success();
        if (mounted) {
                        CustomSnackbar.show(
                          context,
                            message: 'Text copied to clipboard (Share feature coming soon)',
                            type: SnackbarType.info,
                          );
                        }
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                      child: Divider(color: AppTheme.glassBorder, height: 1),
                    ),
                    _buildOptionTile(
                      icon: headline.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      title: headline.isPinned ? 'Unpin Section' : 'Pin Section',
                      themeConfig: themeConfig,
                      onTap: () async {
                        Navigator.pop(context);
                        final provider = context.read<NotesProvider>();
                        await provider.toggleHeadlinePin(noteId, headlineId);
                        await HapticService.medium();
                        if (mounted) {
                          CustomSnackbar.show(
                            context,
                            message: headline.isPinned ? 'Section unpinned' : 'Section pinned',
                          type: SnackbarType.success,
                        );
                      }
                    },
                  ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                      child: Divider(color: AppTheme.glassBorder, height: 1),
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Entry',
                    themeConfig: themeConfig,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteEntryConfirmation(noteId, headlineId, entry.id);
                    },
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                ],
                ),
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

  void _showMoveToSectionDialog(String noteId, String fromHeadlineId, String entryId) async {
    await HapticService.light();
    final provider = context.read<NotesProvider>();
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
    final note = provider.notes.firstWhere((n) => n.id == noteId);
    final availableHeadlines = note.headlines.where((h) => h.id != fromHeadlineId).toList();

    if (availableHeadlines.isEmpty) {
      CustomSnackbar.show(
        context,
        message: 'No other sections available',
        type: SnackbarType.info,
      );
      return;
    }

    final result = await showDialog<String>(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Move to Section',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'Select a section to move this entry to:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  ...availableHeadlines.map((headline) => GestureDetector(
                        onTap: () {
                          HapticService.light();
                          Navigator.pop(context, headline.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            color: AppTheme.glassSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              if (headline.isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(right: AppTheme.spacing8),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 16,
                                    color: themeConfig.primaryColor,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  headline.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: AppTheme.spacing16),
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.glassSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationNormal,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: AppTheme.animationNormal),
    );

    if (result != null && mounted) {
      await provider.moveEntry(noteId, fromHeadlineId, result, entryId);
      await HapticService.success();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Entry moved',
          type: SnackbarType.success,
        );
      }
    }
  }

  void _showMoveToNoteDialog(String noteId, String headlineId, TextEntry entry) async {
    await HapticService.light();
    final provider = context.read<NotesProvider>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MoveEntrySheet(
        notes: provider.allNotes,
        currentNoteId: noteId,
        entry: entry,
        onMoveSelected: (destNoteId, destHeadlineId) async {
          Navigator.pop(context);
          
          // Check if it's a move to a different note or same note different section
          if (destNoteId == noteId) {
            // Same note, different section
            await provider.moveEntry(noteId, headlineId, destHeadlineId, entry.id);
          } else {
            // Different note
            await provider.moveEntryBetweenNotes(
              noteId,
              headlineId,
              entry.id,
              destNoteId,
              destHeadlineId,
            );
          }
          
          await HapticService.success();
          if (mounted) {
            CustomSnackbar.show(
              context,
              message: 'Entry moved successfully',
              type: SnackbarType.success,
            );
            // Navigate back if entry was moved to a different note
            if (destNoteId != noteId) {
              Navigator.pop(context);
            }
          }
        },
        onCreateNote: () async {
          Navigator.pop(context);
          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (context) => const CreateNoteDialog(),
          );

          if (result != null && mounted) {
            final newNote = Note(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: result['name']!,
              icon: result['icon']!,
              headlines: [
                Headline(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'General',
                  entries: [],
                  createdAt: DateTime.now(),
                ),
              ],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            await provider.addNote(newNote);
            await provider.moveEntryBetweenNotes(
              noteId,
              headlineId,
              entry.id,
              newNote.id,
              newNote.headlines.first.id,
            );
            
            await HapticService.success();
            if (mounted) {
              CustomSnackbar.show(
                context,
                message: 'Entry moved to new note',
                type: SnackbarType.success,
              );
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }

  void _showHeadlineOptions(String noteId, Headline headline) async {
    await HapticService.light();
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
                    icon: headline.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    title: headline.isPinned ? 'Unpin Section' : 'Pin Section',
                    themeConfig: themeConfig,
                    onTap: () async {
                      Navigator.pop(context);
                      final provider = context.read<NotesProvider>();
                      await provider.toggleHeadlinePin(noteId, headline.id);
                      await HapticService.medium();
                      if (mounted) {
                        CustomSnackbar.show(
                          context,
                          message: headline.isPinned ? 'Section unpinned' : 'Section pinned',
                          type: SnackbarType.success,
                        );
                      }
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.edit,
                    title: 'Rename Section',
                    themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                      _showRenameHeadlineDialog(noteId, headline);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    title: 'Delete Section',
                    themeConfig: themeConfig,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteHeadlineConfirmation(noteId, headline.id, headline.title);
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

  void _showRenameHeadlineDialog(String noteId, Headline headline) async {
    await HapticService.light();
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
    final controller = TextEditingController(text: headline.title);

    final result = await showDialog<String>(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rename Section',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Section name...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                      filled: true,
                      fillColor: AppTheme.glassSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: const BorderSide(color: AppTheme.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide:
                            const BorderSide(color: AppTheme.glassBorder, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide:
                            BorderSide(color: themeConfig.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
          Navigator.pop(context);
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
                            Navigator.pop(context, controller.text);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeConfig.primaryColor,
                                  themeConfig.primaryColor.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: Center(
                              child: Text(
                                'Save',
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

    if (result != null && result.trim().isNotEmpty && mounted) {
      final provider = context.read<NotesProvider>();
      await provider.updateHeadlineTitle(noteId, headline.id, result.trim());
      await HapticService.success();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Section renamed',
          type: SnackbarType.success,
        );
      }
    }
  }

  void _showDeleteHeadlineConfirmation(String noteId, String headlineId, String headlineTitle) async {
    await HapticService.light();
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
                    'Delete Section?',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'This will permanently delete "$headlineTitle" and all its entries.',
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
      await provider.deleteHeadline(noteId, headlineId);
      await HapticService.heavy();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Section deleted',
          type: SnackbarType.info,
        );
      }
    }
  }

  Future<void> _startRecording() async {
    HapticService.medium();
    final result = await RecordingService().startRecording(_audioRecorder);

    if (!result.success) {
      if (mounted) {
        final errorMessage = result.errorType == RecordingErrorType.permissionDeniedPermanently
            ? 'Microphone permission required'
            : result.errorType == RecordingErrorType.permissionDenied
                ? 'Microphone permission required'
                : 'Failed to start recording: ${result.errorMessage}';
        
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
        );
      }
      return;
    }

    _recordingPath = result.recordingPath;
  }

  Future<void> _stopRecording() async {
    HapticService.medium();
    
    final stoppedPath = await RecordingService().stopRecording(_audioRecorder);

    if (stoppedPath == null && _recordingPath == null) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Failed to stop recording',
          type: SnackbarType.error,
        );
      }
      return;
    }

    _processRecording();
  }

  Future<void> _processRecording() async {
    if (_recordingPath == null) return;

    try {
      setState(() {
        _isTranscribing = true;
      });

      final provider = context.read<NotesProvider>();
      final transcribedText = await provider.transcribeAudio(_recordingPath!);

      if (transcribedText.isEmpty) {
        throw Exception('Transcription returned empty text');
      }

      // Add transcription to note
      await provider.addTranscriptionToNote(transcribedText, widget.noteId);

      if (mounted) {
        HapticService.success();
        CustomSnackbar.show(
          context,
          message: 'Entry added',
          type: SnackbarType.success,
        );
      }

      _recordingPath = null;
    } catch (e) {
      if (mounted) {
        HapticService.error();
        CustomSnackbar.show(
          context,
          message: 'Error processing recording: $e',
          type: SnackbarType.error,
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

  void _showAddEntryOptions() {
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
                    icon: Icons.keyboard,
                    title: 'Write Entry',
                    themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                      _showWriteEntryDialog();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.mic,
                    title: 'Record Entry',
                    themeConfig: themeConfig,
                    onTap: () {
                      Navigator.pop(context);
                      _showRecordingDialog();
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

  void _showWriteEntryDialog() async {
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
    final controller = TextEditingController();

    final result = await showDialog<String>(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Write Entry',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 5,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Type your note here...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                      filled: true,
                      fillColor: AppTheme.glassSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: const BorderSide(color: AppTheme.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: const BorderSide(color: AppTheme.glassBorder, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide(color: themeConfig.primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticService.light();
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.glassSurface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(color: AppTheme.glassBorder, width: 1.5),
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
                            Navigator.pop(context, controller.text);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacing16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeConfig.primaryColor,
                                  themeConfig.primaryColor.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: Center(
                              child: Text(
                                'Add',
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

    if (result != null && result.trim().isNotEmpty && mounted) {
      final provider = context.read<NotesProvider>();
      await provider.addTranscriptionToNote(result.trim(), widget.noteId);
      
      HapticService.success();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Entry added',
          type: SnackbarType.success,
        );
      }
    }
  }

  void _showRecordingDialog() async {
    final themeConfig = context.read<SettingsProvider>().currentThemeConfig;
    bool isRecording = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
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
                    if (_isTranscribing)
                      Column(
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
                            'Processing...',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          GestureDetector(
                            onTapDown: (_) async {
                              setState(() => isRecording = true);
                              await _startRecording();
                            },
                            onTapUp: (_) async {
                              setState(() => isRecording = false);
                              await _stopRecording();
                              Navigator.pop(context);
                            },
                            onTapCancel: () async {
                              setState(() => isRecording = false);
                              await _stopRecording();
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isRecording
                                      ? [
                                          const Color(0xFFef4444),
                                          const Color(0xFFdc2626),
                                        ]
                                      : [
                                          themeConfig.primaryColor,
                                          themeConfig.primaryColor.withValues(alpha: 0.8),
                                        ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isRecording ? const Color(0xFFef4444) : themeConfig.primaryColor)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isRecording ? Icons.stop : Icons.mic,
                                size: 40,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          Text(
                            isRecording ? 'Recording...' : 'Hold to Record',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            isRecording ? 'Release to stop' : 'Press and hold the button',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          GestureDetector(
                            onTap: () {
                              HapticService.light();
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Cancel',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textSecondary,
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
      ),
    );
  }

  void _showDeleteEntryConfirmation(String noteId, String headlineId, String entryId) async {
    await HapticService.light();
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
                    'Delete Entry?',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    'This will permanently delete this entry.',
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
      await provider.deleteEntry(noteId, headlineId, entryId);
      await HapticService.heavy();
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'Entry deleted',
          type: SnackbarType.info,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, child) {
        // Find the note with the given ID
        final note = provider.notes.firstWhere(
          (n) => n.id == widget.noteId,
          orElse: () => Note(
            id: widget.noteId,
            name: 'Not Found',
            icon: '📝',
            headlines: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

            return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, _) {
            final themeConfig = settingsProvider.currentThemeConfig;
            return Scaffold(
              body: GestureDetector(
                onTap: () {
                  // Unfocus when tapping background
                  FocusScope.of(context).unfocus();
                },
                child: AnimatedBackground(
                  style: settingsProvider.settings.backgroundStyle,
                  themeConfig: settingsProvider.currentThemeConfig,
                  child: SafeArea(
                    top: false, // Allow header to extend into safe area
                    child: Stack(
                    children: [
                      // Main scrollable content with CustomScrollView
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, child) {
                          if (settingsProvider.settings.useUnifiedNoteView) {
                            // Unified flowing document view - needs CustomScrollView wrapper for header
                            return CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                // Animated Header with smooth collapsing effect
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _NoteDetailHeaderDelegate(
                                    note: note,
                                    isEditingTitle: _isEditingTitle,
                                    titleController: _titleController,
                                    titleFocusNode: _titleFocusNode,
                                    onBackPressed: () {
                                      HapticService.light();
                                      Navigator.pop(context);
                                    },
                                    onTitleTap: () {
                                      HapticService.light();
                                      _startEditingTitle(note.name);
                                    },
                                    onTitleSubmitted: (_) => _saveTitle(note.id, note.name),
                                    expandedHeight: 120.0 + MediaQuery.of(context).padding.top,
                                    collapsedHeight: 60.0 + MediaQuery.of(context).padding.top,
                                    themeConfig: settingsProvider.currentThemeConfig,
                                  ),
                                ),
                                // Unified Note View as sliver
                                SliverToBoxAdapter(
                                  child: UnifiedNoteView(
                                    note: note,
                                    onEntryLongPress: _showEntryOptions,
                                    onHeadlineLongPress: _showHeadlineOptions,
                                    highlightLastEntry: widget.highlightLastEntry,
                                  ),
                                ),
                                // Add bottom padding to prevent cropping
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
                            );
                          } else {
                            // Traditional card-based view
                            if (note.headlines.isEmpty) {
                              return CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: [
                                  // Animated Header
                                  SliverPersistentHeader(
                                    pinned: true,
                                    delegate: _NoteDetailHeaderDelegate(
                                      note: note,
                                      isEditingTitle: _isEditingTitle,
                                      titleController: _titleController,
                                      titleFocusNode: _titleFocusNode,
                                      onBackPressed: () {
                                        HapticService.light();
                                        Navigator.pop(context);
                                      },
                                      onTitleTap: () {
                                        HapticService.light();
                                        _startEditingTitle(note.name);
                                      },
                                      onTitleSubmitted: (_) => _saveTitle(note.id, note.name),
                                      expandedHeight: 120.0 + MediaQuery.of(context).padding.top,
                                      collapsedHeight: 60.0 + MediaQuery.of(context).padding.top,
                                      themeConfig: settingsProvider.currentThemeConfig,
                                    ),
                                  ),
                                  SliverFillRemaining(
                                    child: Center(
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
                                                    Icons.notes,
                                                    size: 40,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: AppTheme.spacing24),
                                            Text(
                                              'No entries yet',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: AppTheme.textSecondary,
                                                  ),
                                            ),
                                            const SizedBox(height: AppTheme.spacing8),
                                            Text(
                                              'Start recording to add entries\nto this note',
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Add bottom padding to prevent cropping
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 100),
                                  ),
                                ],
                              );
                            }
                            
                            // Separate pinned and unpinned headlines
                            final pinnedHeadlines = note.headlines.where((h) => h.isPinned).toList();
                            final unpinnedHeadlines = note.headlines.where((h) => !h.isPinned).toList();
                            final allHeadlines = [...pinnedHeadlines, ...unpinnedHeadlines];
                            
                            return CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                // Animated Header with smooth collapsing effect
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _NoteDetailHeaderDelegate(
                                    note: note,
                                    isEditingTitle: _isEditingTitle,
                                    titleController: _titleController,
                                    titleFocusNode: _titleFocusNode,
                                    onBackPressed: () {
                                      HapticService.light();
                                      Navigator.pop(context);
                                    },
                                    onTitleTap: () {
                                      HapticService.light();
                                      _startEditingTitle(note.name);
                                    },
                                    onTitleSubmitted: (_) => _saveTitle(note.id, note.name),
                                    expandedHeight: 120.0 + MediaQuery.of(context).padding.top,
                                    collapsedHeight: 60.0 + MediaQuery.of(context).padding.top,
                                    themeConfig: settingsProvider.currentThemeConfig,
                                  ),
                                ),
                                // Add spacing between header and notes
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: AppTheme.spacing16),
                                ),
                                // Notes list
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing24,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        // Show "Pinned Sections" label first
                                        if (index == 0 && pinnedHeadlines.isNotEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: AppTheme.spacing8,
                                              bottom: AppTheme.spacing16,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: AppTheme.spacing12,
                                                    vertical: AppTheme.spacing4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        themeConfig.primaryColor.withValues(alpha: 0.3),
                                                        themeConfig.primaryColor.withValues(alpha: 0.15),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                                    border: Border.all(
                                                      color: themeConfig.primaryColor.withValues(alpha: 0.4),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.push_pin,
                                                        size: 12,
                                                        color: themeConfig.primaryColor,
                                                      ),
                                                      const SizedBox(width: AppTheme.spacing4),
                                                      Text(
                                                        'PINNED SECTIONS',
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                              color: themeConfig.primaryColor,
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 10,
                                                              letterSpacing: 0.8,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: AppTheme.spacing12),
                                                Expanded(
                                                  child: Container(
                                                    height: 1,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.centerLeft,
                                                        end: Alignment.centerRight,
                                                        colors: [
                                                          themeConfig.primaryColor.withValues(alpha: 0.3),
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
                                        
                                        // Calculate adjusted index for headlines
                                        int adjustedIndex = index;
                                        if (pinnedHeadlines.isNotEmpty) {
                                          adjustedIndex -= 1; // Account for pinned label
                                        }
                                        
                                        // Show divider between pinned and unpinned
                                        if (pinnedHeadlines.isNotEmpty && 
                                            unpinnedHeadlines.isNotEmpty && 
                                            adjustedIndex == pinnedHeadlines.length) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                                            child: Container(
                                              height: 1,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    Colors.transparent,
                                                    AppTheme.glassBorder.withValues(alpha: 0.3),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        
                                        // Adjust index again for divider
                                        if (pinnedHeadlines.isNotEmpty && 
                                            unpinnedHeadlines.isNotEmpty && 
                                            adjustedIndex > pinnedHeadlines.length) {
                                          adjustedIndex -= 1; // Account for divider
                                        }
                                        
                                        final headline = allHeadlines[adjustedIndex];
                                        final isLastHeadline = adjustedIndex == allHeadlines.length - 1;
                                        return RepaintBoundary(
                                          child: _buildHeadlineSection(
                                            note.id,
                                            headline,
                                            isLastHeadline && widget.highlightLastEntry,
                                            themeConfig,
                                          ),
                                        );
                                      },
                                      childCount: allHeadlines.length + 
                                          (pinnedHeadlines.isNotEmpty ? 1 : 0) + 
                                          (pinnedHeadlines.isNotEmpty && unpinnedHeadlines.isNotEmpty ? 1 : 0),
                                      addAutomaticKeepAlives: true,
                                      addRepaintBoundaries: true,
                                    ),
                                  ),
                                ),
                                // Add bottom padding to prevent cropping
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      // Floating + button
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: GestureDetector(
                              onTap: _showAddEntryOptions,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      themeConfig.primaryColor,
                                      themeConfig.primaryColor.withValues(alpha: 0.8),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeConfig.primaryColor.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 32,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
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
      },
    );
  }

  Widget _buildHeadlineSection(
    String noteId, 
    Headline headline, 
    bool shouldHighlight,
    ThemeConfig themeConfig,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline title with tap-to-edit, long-press, and pin indicator
        GestureDetector(
          onTap: () {
            if (_editingHeadlineId != headline.id) {
              HapticService.light();
              _startEditingHeadline(headline);
            }
          },
          onLongPress: () => _showHeadlineOptions(noteId, headline),
          child: Padding(
          padding: const EdgeInsets.only(
            bottom: AppTheme.spacing24,
            top: AppTheme.spacing32,
            ),
            child: Row(
              children: [
                if (headline.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.spacing8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeConfig.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: themeConfig.primaryColor,
                      ),
                    ),
                  ),
                Expanded(
                  child: _editingHeadlineId == headline.id
                      ? TextField(
                          controller: _headlineControllers[headline.id],
                          focusNode: _headlineFocusNodes[headline.id],
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppTheme.glassBorder.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: themeConfig.primaryColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _saveHeadlineEdit(noteId, headline),
                        )
                      : Text(
            headline.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Entries
        ...headline.entries.asMap().entries.map((entry) {
          final entryIndex = entry.key;
          final textEntry = entry.value;
          final isLastEntry = entryIndex == headline.entries.length - 1;
          final highlight = shouldHighlight && isLastEntry;
          final isEditing = _editingEntryId == textEntry.id;

          final container = GestureDetector(
            onTap: () {
              if (!isEditing) {
                HapticService.light();
                _startEditing(textEntry);
              }
            },
            onLongPress: () => _showEntryOptions(noteId, headline.id, textEntry, headline),
            child: Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing24,
                    vertical: AppTheme.spacing20,
                  ),
                  decoration: BoxDecoration(
                    gradient: highlight
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              themeConfig.primaryColor,
                              themeConfig.primaryColor.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: highlight ? null : AppTheme.glassStrongSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: isEditing
                          ? themeConfig.primaryColor.withOpacity(0.5)
                          : (highlight ? themeConfig.primaryColor : AppTheme.glassBorder.withOpacity(0.2)),
                      width: isEditing ? 1.5 : (highlight ? 2 : 1),
                    ),
                    boxShadow: highlight ? AppTheme.buttonShadow : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isEditing)
                        TextField(
                          controller: _editControllers[textEntry.id],
                          focusNode: _focusNodes[textEntry.id],
                          maxLines: null,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                height: 1.7,
                                letterSpacing: 0.2,
                              ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        )
                      else
                        Text(
                          textEntry.text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                height: 1.65,
                                letterSpacing: 0.1,
                              ),
                        ),
                      const SizedBox(height: AppTheme.spacing16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: highlight
                                ? AppTheme.textPrimary.withOpacity(0.6)
                                : AppTheme.textTertiary.withOpacity(0.6),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            _formatDate(textEntry.createdAt),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: highlight
                                      ? AppTheme.textPrimary.withOpacity(0.6)
                                      : AppTheme.textTertiary.withOpacity(0.6),
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ],
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          );
          
          // Only apply animations to highlighted entries
          if (highlight) {
            return container
                .animate()
                .fadeIn(duration: AppTheme.animationNormal)
                .slideY(
                  begin: 0.2,
                  end: 0,
                  duration: AppTheme.animationNormal,
                )
                .shimmer(
                  duration: const Duration(seconds: 2),
                  color: Colors.white.withValues(alpha: 0.3),
                );
          }
          
          return container;
        }),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Custom SliverPersistentHeaderDelegate for animated note detail header
class _NoteDetailHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Note note;
  final bool isEditingTitle;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final VoidCallback onBackPressed;
  final VoidCallback onTitleTap;
  final ValueChanged<String> onTitleSubmitted;
  final double expandedHeight;
  final double collapsedHeight;
  final ThemeConfig themeConfig;

  _NoteDetailHeaderDelegate({
    required this.note,
    required this.isEditingTitle,
    required this.titleController,
    required this.titleFocusNode,
    required this.onBackPressed,
    required this.onTitleTap,
    required this.onTitleSubmitted,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.themeConfig,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate progress based on how much the header has shrunk
    final double shrinkProgress = (shrinkOffset / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
    
    // Get safe area insets
    final safePadding = MediaQuery.of(context).padding.top;
    
    // Interpolate values based on scroll progress
    final double fontSize = 32 - (shrinkProgress * 10); // 32 -> 22
    final double topPadding = 56 - (shrinkProgress * 40); // 56 -> 16
    final double bottomPadding = 24 - (shrinkProgress * 8); // 24 -> 16
    final double horizontalPadding = 24 - (shrinkProgress * 4); // 24 -> 20
    final double backButtonSize = 46 - (shrinkProgress * 6); // 46 -> 40
    
    // Background opacity increases as we scroll - only show when scrolling
    final double backgroundOpacity = shrinkProgress * 0.4; // 0 -> 0.4 (starts transparent, becomes glass)
    final double blurAmount = shrinkProgress * 20; // 0 -> 20 (no blur at top, full blur when scrolled)
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            safePadding + topPadding, // Add safe area to top padding
            horizontalPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            // White glassmorphism like microphone button - only visible when scrolling
            color: AppTheme.glassStrongSurface.withValues(alpha: backgroundOpacity),
            border: shrinkProgress > 0.5 ? const Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder,
                width: 1.5,
              ),
            ) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button - clean and properly sized
              GestureDetector(
                onTap: onBackPressed,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: backButtonSize,
                      height: backButtonSize,
                      decoration: AppTheme.glassDecoration(
                        radius: AppTheme.radiusMedium,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Note title
              Expanded(
                child: RepaintBoundary(
                  child: isEditingTitle
                      ? TextField(
                          controller: titleController,
                          focusNode: titleFocusNode,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppTheme.glassBorder.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: themeConfig.primaryColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onSubmitted: onTitleSubmitted,
                        )
                      : GestureDetector(
                          onTap: onTitleTap,
                          child: Text(
                            note.name,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                  height: 1.2,
                                  color: AppTheme.textPrimary,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _NoteDetailHeaderDelegate oldDelegate) {
    return note.name != oldDelegate.note.name ||
        note.icon != oldDelegate.note.icon ||
        isEditingTitle != oldDelegate.isEditingTitle;
  }
}

