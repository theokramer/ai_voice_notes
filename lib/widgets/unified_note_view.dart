import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_snackbar.dart';

class UnifiedNoteView extends StatefulWidget {
  final Note note;
  final Function(String noteId, String headlineId, TextEntry entry, Headline headline) onEntryLongPress;
  final Function(String noteId, Headline headline) onHeadlineLongPress;
  final String? highlightedEntryId;
  final Map<String, GlobalKey>? entryKeys;

  const UnifiedNoteView({
    super.key,
    required this.note,
    required this.onEntryLongPress,
    required this.onHeadlineLongPress,
    this.highlightedEntryId,
    this.entryKeys,
  });

  @override
  State<UnifiedNoteView> createState() => _UnifiedNoteViewState();
}

class _UnifiedNoteViewState extends State<UnifiedNoteView> {
  String? _editingEntryId;
  String? _editingHeadlineId;
  final Map<String, TextEditingController> _entryControllers = {};
  final Map<String, FocusNode> _entryFocusNodes = {};
  final Map<String, TextEditingController> _headlineControllers = {};
  final Map<String, FocusNode> _headlineFocusNodes = {};
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Clean up controllers and focus nodes
    for (var controller in _entryControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _entryFocusNodes.values) {
      focusNode.dispose();
    }
    for (var controller in _headlineControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _headlineFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startEditingEntry(TextEntry entry, String headlineId) {
    setState(() {
      _editingEntryId = entry.id;
      if (!_entryControllers.containsKey(entry.id)) {
        final controller = TextEditingController(text: entry.text);
        _entryControllers[entry.id] = controller;
        final focusNode = FocusNode();
        _entryFocusNodes[entry.id] = focusNode;
        
        // Auto-save asynchronously on text change
        controller.addListener(() {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (_editingEntryId == entry.id) {
              _saveEntryEditSilently(headlineId, entry);
            }
          });
        });
        
        // Also save when focus is lost
        focusNode.addListener(() {
          if (!focusNode.hasFocus && _editingEntryId == entry.id) {
            _debounceTimer?.cancel();
            _saveEntryEdit(headlineId, entry);
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryFocusNodes[entry.id]?.requestFocus();
    });
  }
  
  Future<void> _saveEntryEditSilently(String headlineId, TextEntry entry) async {
    final controller = _entryControllers[entry.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newText = controller.text.trim();
      if (newText != entry.text) {
        final provider = context.read<NotesProvider>();
        await provider.updateEntry(widget.note.id, headlineId, entry.id, newText);
      }
    }
  }

  void _startEditingHeadline(Headline headline) {
    setState(() {
      _editingHeadlineId = headline.id;
      if (!_headlineControllers.containsKey(headline.id)) {
        _headlineControllers[headline.id] = TextEditingController(text: headline.title);
        _headlineFocusNodes[headline.id] = FocusNode();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headlineFocusNodes[headline.id]?.requestFocus();
    });
  }

  void _stopEditingEntry() {
    setState(() {
      _editingEntryId = null;
    });
  }

  void _stopEditingHeadline() {
    setState(() {
      _editingHeadlineId = null;
    });
  }

  Future<void> _saveEntryEdit(String headlineId, TextEntry entry) async {
    final controller = _entryControllers[entry.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newText = controller.text.trim();
      if (newText != entry.text) {
        final provider = context.read<NotesProvider>();
        await provider.updateEntry(widget.note.id, headlineId, entry.id, newText);
        await HapticService.light();
        // Silent save - no snackbar for elegant inline editing
      }
    }
    _stopEditingEntry();
  }

  Future<void> _saveHeadlineEdit(Headline headline) async {
    final controller = _headlineControllers[headline.id];
    if (controller != null && controller.text.trim().isNotEmpty) {
      final newTitle = controller.text.trim();
      if (newTitle != headline.title) {
        final provider = context.read<NotesProvider>();
        await provider.updateHeadlineTitle(widget.note.id, headline.id, newTitle);
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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final themeConfig = settingsProvider.currentThemeConfig;
    
    if (widget.note.headlines.isEmpty) {
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
                      border: Border.all(color: AppTheme.glassBorder, width: 2),
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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
      );
    }

    // Separate pinned and unpinned headlines
    final pinnedHeadlines = widget.note.headlines.where((h) => h.isPinned).toList();
    final unpinnedHeadlines = widget.note.headlines.where((h) => !h.isPinned).toList();
    final allHeadlines = [...pinnedHeadlines, ...unpinnedHeadlines];
    
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.spacing24),
      children: [
        // Build flowing document-style content
        ...allHeadlines.asMap().entries.expand((headlineEntry) {
          final headlineIndex = headlineEntry.key;
          final headline = headlineEntry.value;
          final isFirstPinned = headline.isPinned && headlineIndex == 0;
          final isFirstUnpinned = !headline.isPinned && headlineIndex == pinnedHeadlines.length;

          return [
            // Add "Pinned" label before first pinned section
            if (isFirstPinned && pinnedHeadlines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
              ),
            // Add divider before first unpinned section
            if (isFirstUnpinned && pinnedHeadlines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
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
              ),
            // Headline as section header
            GestureDetector(
              onTap: () {
                if (_editingHeadlineId != headline.id) {
                  HapticService.light();
                  _startEditingHeadline(headline);
                }
              },
              onLongPress: () => widget.onHeadlineLongPress(widget.note.id, headline),
              child: Padding(
                padding: EdgeInsets.only(
                  top: (headlineIndex == 0 || isFirstUnpinned) ? 0 : AppTheme.spacing24,
                  bottom: AppTheme.spacing16,
                ),
                child: Row(
                  children: [
                    if (headline.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: AppTheme.spacing8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: themeConfig.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.push_pin,
                          size: 12,
                          color: themeConfig.primaryColor,
                        ),
                      ),
                      ),
                    Expanded(
                      child: _editingHeadlineId == headline.id
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _headlineControllers[headline.id],
                                  focusNode: _headlineFocusNodes[headline.id],
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                        letterSpacing: -0.3,
                                      ),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                    borderSide: BorderSide(color: themeConfig.primaryColor, width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                    borderSide: BorderSide(color: themeConfig.primaryColor, width: 1.5),
                                  ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacing8,
                                      vertical: AppTheme.spacing8,
                                    ),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _saveHeadlineEdit(headline),
                                ),
                                const SizedBox(height: AppTheme.spacing8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticService.light();
                                        _stopEditingHeadline();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacing12,
                                          vertical: AppTheme.spacing4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.glassSurface,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                          border: Border.all(color: AppTheme.glassBorder),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacing8),
                                    GestureDetector(
                                      onTap: () => _saveHeadlineEdit(headline),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacing12,
                                          vertical: AppTheme.spacing4,
                                        ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            themeConfig.primaryColor,
                                            themeConfig.primaryColor.withValues(alpha: 0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                        ),
                                        child: Text(
                                          'Save',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Text(
                              headline.title,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Text entries flowing underneath
            ...headline.entries.asMap().entries.map((entryEntry) {
              final textEntry = entryEntry.value;
              final highlight = widget.highlightedEntryId == textEntry.id;
              final isEditing = _editingEntryId == textEntry.id;

              return Padding(
                key: widget.entryKeys?[textEntry.id],
                padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
                child: GestureDetector(
                  onTap: () {
                    if (!isEditing) {
                      HapticService.light();
                      _startEditingEntry(textEntry, headline.id);
                    }
                  },
                  onLongPress: () => widget.onEntryLongPress(widget.note.id, headline.id, textEntry, headline),
                  child: Container(
                    decoration: (highlight || isEditing)
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                themeConfig.primaryColor.withValues(alpha: 0.12),
                                themeConfig.primaryColor.withValues(alpha: 0.04),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: themeConfig.primaryColor.withValues(alpha: isEditing ? 0.4 : 0.25),
                              width: isEditing ? 1.5 : 1,
                            ),
                          )
                        : null,
                    padding: (highlight || isEditing)
                        ? const EdgeInsets.all(AppTheme.spacing8)
                        : EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEditing)
                          TextField(
                            controller: _entryControllers[textEntry.id],
                            focusNode: _entryFocusNodes[textEntry.id],
                            maxLines: null,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontSize: 17,
                                  height: 1.65,
                                  letterSpacing: 0.1,
                                  color: AppTheme.textPrimary,
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
                                  fontSize: 17,
                                  height: 1.65,
                                  letterSpacing: 0.1,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                        const SizedBox(height: AppTheme.spacing12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                            Icons.access_time,
                            size: 13,
                            color: highlight
                                ? themeConfig.primaryColor
                                : AppTheme.textTertiary.withOpacity(0.6),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            _formatDate(textEntry.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: highlight
                                      ? themeConfig.primaryColor
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
              );
            }),
            // Add subtle divider after each headline section except the last
            if (headlineIndex < allHeadlines.length - 1)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppTheme.spacing16,
                  bottom: AppTheme.spacing8,
                ),
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
              ),
          ];
        }),
        // Add bottom padding for better scrolling experience
        const SizedBox(height: AppTheme.spacing48),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Normalize dates to compare calendar days (ignoring time)
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(dateDay).inDays;

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (daysDifference == 0) {
      // Same calendar day
      return '${difference.inHours}h ago';
    } else if (daysDifference == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (daysDifference < 7) {
      // Within the last week
      return '${daysDifference}d ago';
    } else {
      // Older than a week
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

