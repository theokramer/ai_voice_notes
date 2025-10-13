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
    final groupedNotes = provider.groupNotesByTimePeriod(notes);
    final todayCount = groupedNotes['Today']!.length;
    final thisWeekCount = groupedNotes['This Week']!.length;
    final moreCount = groupedNotes['More']!.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Today section
          if (todayCount > 0 && index == 0) {
            return _buildSectionHeader(context, LocalizationService().t('today'));
          }
          if (index > 0 && index <= todayCount) {
            final note = groupedNotes['Today']![index - 1];
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
          if (thisWeekCount > 0 && index == weekStartIndex) {
            return _buildSectionHeader(context, LocalizationService().t('this_week'));
          }
          if (index > weekStartIndex && index <= weekStartIndex + thisWeekCount) {
            final note = groupedNotes['This Week']![index - weekStartIndex - 1];
            return GestureDetector(
              onLongPress: () => onShowNoteOptions(note),
              child: MinimalisticNoteCard(
                note: note,
                index: index - weekStartIndex - 1,
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
          if (moreCount > 0 && index == moreStartIndex) {
            return _buildSectionHeader(context, LocalizationService().t('more'));
          }
          if (index > moreStartIndex) {
            final note = groupedNotes['More']![index - moreStartIndex - 1];
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
        childCount: (todayCount > 0 ? todayCount + 1 : 0) +
            (thisWeekCount > 0 ? thisWeekCount + 1 : 0) +
            (moreCount > 0 ? moreCount + 1 : 0),
      ),
    );
  }
}

