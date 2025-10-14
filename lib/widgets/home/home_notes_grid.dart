import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../note_card.dart';
import '../hero_page_route.dart';
import '../../screens/note_detail_screen.dart';

/// Grid view for notes with masonry layout
class HomeNotesGrid extends StatelessWidget {
  final List<Note> notes;
  final NotesProvider provider;
  final String searchQuery;
  final VoidCallback onHideSearchOverlay;
  final Function(Note) onShowNoteOptions;
  final Function(Note, String) extractSnippets;

  const HomeNotesGrid({
    super.key,
    required this.notes,
    required this.provider,
    required this.searchQuery,
    required this.onHideSearchOverlay,
    required this.onShowNoteOptions,
    required this.extractSnippets,
  });

  double _estimateNoteCardHeight(Note note) {
    // Base structure for grid view (reduced padding):
    // top padding (12) + icon (48) + name row (16) + spacing (4) + date (13) + spacing (8)
    double height = 12.0 + 48.0 + 16.0 + 4.0 + 13.0 + 8.0; // ~101px

    // Get the content text
    final latestText = note.content;

    if (latestText.isEmpty) {
      // "No content" text
      height += 12.0 * 1.4; // fontSize 12, height 1.4
      height += 12.0; // bottom padding (reduced)
      return height + 12.0; // margin bottom
    }

    // Calculate text that will actually be shown (first 35 words or less)
    final words = latestText.split(RegExp(r'\s+'));
    final maxWords = 35;
    final visibleWords = words.take(maxWords).toList();
    final visibleText = visibleWords.join(' ');

    // Calculate lines needed
    // ~30 chars per line in grid view, fontSize 12
    final charsPerLine = 30;
    final estimatedLines = (visibleText.length / charsPerLine).ceil();

    // Line height = fontSize * height multiplier
    final lineHeight = 12.0 * 1.4;
    height += estimatedLines * lineHeight;

    height += 12.0; // bottom padding (reduced)
    return height + 12.0; // margin bottom
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 3 : 2;

    // Separate pinned and unpinned notes
    final pinnedNotes = notes.where((n) => n.isPinned).toList();
    final unpinnedNotes = notes.where((n) => !n.isPinned).toList();
    final hasPinned = pinnedNotes.isNotEmpty;

    // Create columns for pinned notes
    final pinnedColumns = List.generate(crossAxisCount, (_) => <Note>[]);
    final pinnedColumnHeights = List.generate(crossAxisCount, (_) => 0.0);

    for (var note in pinnedNotes) {
      final estimatedHeight = _estimateNoteCardHeight(note);
      var shortestColumnIndex = 0;
      var shortestHeight = pinnedColumnHeights[0];

      for (var col = 1; col < crossAxisCount; col++) {
        if (pinnedColumnHeights[col] < shortestHeight) {
          shortestHeight = pinnedColumnHeights[col];
          shortestColumnIndex = col;
        }
      }

      pinnedColumns[shortestColumnIndex].add(note);
      pinnedColumnHeights[shortestColumnIndex] += estimatedHeight;
    }

    // Create columns for unpinned notes
    final columns = List.generate(crossAxisCount, (_) => <Note>[]);
    final columnHeights = List.generate(crossAxisCount, (_) => 0.0);

    for (var note in unpinnedNotes) {
      final estimatedHeight = _estimateNoteCardHeight(note);
      var shortestColumnIndex = 0;
      var shortestHeight = columnHeights[0];

      for (var col = 1; col < crossAxisCount; col++) {
        if (columnHeights[col] < shortestHeight ||
            (columnHeights[col] == shortestHeight &&
                columns[col].length < columns[shortestColumnIndex].length)) {
          shortestHeight = columnHeights[col];
          shortestColumnIndex = col;
        }
      }

      columns[shortestColumnIndex].add(note);
      columnHeights[shortestColumnIndex] += estimatedHeight;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned section
            if (hasPinned) ...[
              Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  final themeConfig = settingsProvider.currentThemeConfig;
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: AppTheme.spacing8,
                      top: AppTheme.spacing8,
                      bottom: AppTheme.spacing16,
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
                      ],
                    ),
                  );
                },
              ),
              // Pinned notes grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(crossAxisCount, (columnIndex) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: columnIndex == 0 ? 0 : AppTheme.spacing4,
                        right: columnIndex == crossAxisCount - 1 ? 0 : AppTheme.spacing4,
                      ),
                      child: Column(
                        children: pinnedColumns[columnIndex].map((note) {
                          final index = notes.indexOf(note);
                          final snippets = extractSnippets(note, searchQuery);

                          return GestureDetector(
                            onLongPress: () => onShowNoteOptions(note),
                            child: NoteCard(
                              note: note,
                              searchQuery: searchQuery,
                              matchedSnippets: snippets,
                              index: index,
                              isGridView: true,
                              onTap: () async {
                                await HapticService.light();
                                provider.markNoteAsAccessed(note.id);
                                final sq = searchQuery.isNotEmpty ? searchQuery : null;
                                if (sq != null) onHideSearchOverlay();
                                await context.pushHero(
                                  NoteDetailScreen(noteId: note.id, searchQuery: sq),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              ),
              // Divider
              if (unpinnedNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacing16,
                    bottom: AppTheme.spacing24,
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
                ),
            ],
            // Unpinned notes grid
            Row(
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
                        final snippets = extractSnippets(note, searchQuery);

                        return GestureDetector(
                          onLongPress: () => onShowNoteOptions(note),
                          child: NoteCard(
                            note: note,
                            searchQuery: searchQuery,
                            matchedSnippets: snippets,
                            index: index,
                            isGridView: true,
                            onTap: () async {
                              await HapticService.light();
                              provider.markNoteAsAccessed(note.id);
                              final sq = searchQuery.isNotEmpty ? searchQuery : null;
                              if (sq != null) onHideSearchOverlay();
                              await context.pushHero(
                                NoteDetailScreen(noteId: note.id, searchQuery: sq),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

