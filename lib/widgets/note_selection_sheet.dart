import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';

class NoteSelectionSheet extends StatelessWidget {
  final List<Note> notes;
  final Function(Note) onNoteSelected;
  final VoidCallback onCreateNote;

  const NoteSelectionSheet({
    super.key,
    required this.notes,
    required this.onNoteSelected,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    // Sort notes by last accessed (most recent first)
    final sortedNotes = List<Note>.from(notes);
    sortedNotes.sort((a, b) {
      final aTime = a.lastAccessedAt ?? a.updatedAt;
      final bTime = b.lastAccessedAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    // Split into recent (accessed in last 7 days) and others
    final now = DateTime.now();
    final recentNotes = sortedNotes.where((note) {
      final lastTime = note.lastAccessedAt ?? note.updatedAt;
      return now.difference(lastTime).inDays < 7;
    }).toList();
    
    final otherNotes = sortedNotes.where((note) {
      final lastTime = note.lastAccessedAt ?? note.updatedAt;
      return now.difference(lastTime).inDays >= 7;
    }).toList();

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
                Text(
                  'Select a note',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          // Notes list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              children: [
                if (recentNotes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppTheme.spacing12,
                      left: AppTheme.spacing8,
                    ),
                    child: Text(
                      'RECENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...recentNotes.map((note) => _buildNoteItem(context, note)),
                ],
                if (otherNotes.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      top: recentNotes.isNotEmpty ? AppTheme.spacing16 : 0,
                      bottom: AppTheme.spacing12,
                      left: AppTheme.spacing8,
                    ),
                    child: Text(
                      'OTHER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textTertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...otherNotes.map((note) => _buildNoteItem(context, note)),
                ],
                if (recentNotes.isEmpty && otherNotes.isEmpty)
                  ...notes.map((note) => _buildNoteItem(context, note)),
                const SizedBox(height: AppTheme.spacing8),
                _buildCreateNoteButton(context),
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
  }

  Widget _buildNoteItem(BuildContext context, Note note) {
    return GestureDetector(
      onTap: () => onNoteSelected(note),
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
                    child: Text(
                      note.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
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

  Widget _buildCreateNoteButton(BuildContext context) {
    return GestureDetector(
      onTap: onCreateNote,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.buttonShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              'Create new note',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

