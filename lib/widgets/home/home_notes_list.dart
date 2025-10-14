import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../services/haptic_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import '../minimalistic_note_card.dart';
import '../hero_page_route.dart';
import '../../screens/note_detail_screen.dart';

/// Minimalistic list view for notes with time-based grouping
class HomeNotesList extends StatelessWidget {
  final List<Note> notes;
  final NotesProvider provider;
  final String searchQuery;
  final VoidCallback onHideSearchOverlay;
  final Function(Note) onShowNoteOptions;

  const HomeNotesList({
    super.key,
    required this.notes,
    required this.provider,
    required this.searchQuery,
    required this.onHideSearchOverlay,
    required this.onShowNoteOptions,
  });

  Widget _buildSectionHeader(BuildContext context, String title) {
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

  @override
  Widget build(BuildContext context) {
    // Separate pinned and unpinned notes
    final pinnedNotes = notes.where((n) => n.isPinned).toList();
    final unpinnedNotes = notes.where((n) => !n.isPinned).toList();
    final hasPinned = pinnedNotes.isNotEmpty;
    
    // Group unpinned notes by time period
    final groupedNotes = provider.groupNotesByTimePeriod(unpinnedNotes);
    final todayCount = groupedNotes['Today']!.length;
    final thisWeekCount = groupedNotes['This Week']!.length;
    final moreCount = groupedNotes['More']!.length;

    // Calculate indices with pinned section
    final pinnedCount = pinnedNotes.length;
    final pinnedSectionCount = hasPinned ? pinnedCount + 1 : 0; // +1 for header

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Pinned section
          if (hasPinned && index == 0) {
            return _buildSectionHeader(context, 'Pinned');
          }
          if (hasPinned && index > 0 && index <= pinnedCount) {
            final note = pinnedNotes[index - 1];
            return GestureDetector(
              onLongPress: () => onShowNoteOptions(note),
              child: MinimalisticNoteCard(
                note: note,
                index: index - 1,
                onTap: () async {
                  await HapticService.light();
                  provider.markNoteAsAccessed(note.id);
                  if (searchQuery.isNotEmpty) {
                    onHideSearchOverlay();
                  }
                  await context.pushHero(
                    NoteDetailScreen(noteId: note.id),
                  );
                },
              ),
            );
          }
          
          // Adjust index for remaining sections
          final adjustedIndex = index - pinnedSectionCount;
          
          // Today section
          if (todayCount > 0 && adjustedIndex == 0) {
            return _buildSectionHeader(context, LocalizationService().t('today'));
          }
          if (adjustedIndex > 0 && adjustedIndex <= todayCount) {
            final note = groupedNotes['Today']![adjustedIndex - 1];
            return GestureDetector(
              onLongPress: () => onShowNoteOptions(note),
              child: MinimalisticNoteCard(
                note: note,
                index: index - 1,
                onTap: () async {
                  await HapticService.light();
                  provider.markNoteAsAccessed(note.id);
                  if (searchQuery.isNotEmpty) {
                    onHideSearchOverlay();
                  }
                  await context.pushHero(
                    NoteDetailScreen(noteId: note.id),
                  );
                },
              ),
            );
          }

          // This Week section
          int weekStartIndex = todayCount > 0 ? todayCount + 1 : 0;
          if (thisWeekCount > 0 && adjustedIndex == weekStartIndex) {
            return _buildSectionHeader(context, LocalizationService().t('this_week'));
          }
          if (adjustedIndex > weekStartIndex && adjustedIndex <= weekStartIndex + thisWeekCount) {
            final note = groupedNotes['This Week']![adjustedIndex - weekStartIndex - 1];
            return GestureDetector(
              onLongPress: () => onShowNoteOptions(note),
              child: MinimalisticNoteCard(
                note: note,
                index: adjustedIndex - weekStartIndex - 1,
                onTap: () async {
                  await HapticService.light();
                  provider.markNoteAsAccessed(note.id);
                  if (searchQuery.isNotEmpty) {
                    onHideSearchOverlay();
                  }
                  await context.pushHero(
                    NoteDetailScreen(noteId: note.id),
                  );
                },
              ),
            );
          }

          // More section
          int moreStartIndex = weekStartIndex + (thisWeekCount > 0 ? thisWeekCount + 1 : 0);
          if (moreCount > 0 && adjustedIndex == moreStartIndex) {
            return _buildSectionHeader(context, LocalizationService().t('more'));
          }
          if (adjustedIndex > moreStartIndex) {
            final note = groupedNotes['More']![adjustedIndex - moreStartIndex - 1];
            return GestureDetector(
              onLongPress: () => onShowNoteOptions(note),
              child: MinimalisticNoteCard(
                note: note,
                index: index - moreStartIndex - 1,
                onTap: () async {
                  await HapticService.light();
                  provider.markNoteAsAccessed(note.id);
                  if (searchQuery.isNotEmpty) {
                    onHideSearchOverlay();
                  }
                  await context.pushHero(
                    NoteDetailScreen(noteId: note.id),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
        childCount: pinnedSectionCount +
            (todayCount > 0 ? todayCount + 1 : 0) +
            (thisWeekCount > 0 ? thisWeekCount + 1 : 0) +
            (moreCount > 0 ? moreCount + 1 : 0),
      ),
    );
  }
}

