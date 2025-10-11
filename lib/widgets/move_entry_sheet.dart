import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';

class MoveEntrySheet extends StatefulWidget {
  final List<Note> notes;
  final String currentNoteId;
  final TextEntry entry;
  final Function(String noteId, String headlineId) onMoveSelected;
  final VoidCallback onCreateNote;

  const MoveEntrySheet({
    super.key,
    required this.notes,
    required this.currentNoteId,
    required this.entry,
    required this.onMoveSelected,
    required this.onCreateNote,
  });

  @override
  State<MoveEntrySheet> createState() => _MoveEntrySheetState();
}

class _MoveEntrySheetState extends State<MoveEntrySheet> {
  Note? _selectedNote;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return ClipRRect(
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
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
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
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drive_file_move_outline,
                          color: themeConfig.primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            LocalizationService().t('move_entry'),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: AppTheme.spacing16),
              // Entry preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: AppTheme.glassSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Text(
                        widget.entry.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              // Selection area
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                  children: [
                    if (_selectedNote == null) ...[
                      // Note selection
                      Text(
                        'Select destination note',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      ...widget.notes.map((note) => _buildNoteItem(note)),
                      const SizedBox(height: AppTheme.spacing8),
                      _buildCreateNoteButton(themeConfig),
                    ] else ...[
                      // Headline selection
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              setState(() {
                                _selectedNote = null;
                              });
                            },
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Expanded(
                            child: Text(
                              'Select section in "${_selectedNote!.name}"',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      if (_selectedNote!.headlines.isEmpty)
                        _buildCreateHeadlineButton(themeConfig)
                      else
                        ..._selectedNote!.headlines.map((headline) => _buildHeadlineItem(headline, themeConfig)),
                      const SizedBox(height: AppTheme.spacing8),
                      _buildCreateHeadlineButton(themeConfig),
                    ],
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
        )
            .animate()
            .slideY(begin: 0.3, end: 0, duration: AppTheme.animationNormal, curve: Curves.easeOutCubic)
            .fadeIn(duration: AppTheme.animationNormal);
      },
    );
  }

  Widget _buildNoteItem(Note note) {
    // Don't show the current note in the list
    if (note.id == widget.currentNoteId) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNote = note;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.glassSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    note.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${note.headlines.length} sections',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadlineItem(Headline headline, ThemeConfig themeConfig) {
    return GestureDetector(
      onTap: () {
        widget.onMoveSelected(_selectedNote!.id, headline.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.glassSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.glassBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${headline.entries.length} entries',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: themeConfig.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNoteButton(ThemeConfig themeConfig) {
    return GestureDetector(
      onTap: widget.onCreateNote,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeConfig.primaryColor,
              themeConfig.primaryColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.getThemedShadow(themeConfig),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              'Create new note',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateHeadlineButton(ThemeConfig themeConfig) {
    return GestureDetector(
      onTap: () {
        // Create a new headline and move entry there
        final newHeadlineId = DateTime.now().millisecondsSinceEpoch.toString();
        widget.onMoveSelected(_selectedNote!.id, newHeadlineId);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeConfig.primaryColor.withValues(alpha: 0.6),
              themeConfig.primaryColor.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: themeConfig.primaryColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              color: themeConfig.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              'Create new section',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: themeConfig.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

