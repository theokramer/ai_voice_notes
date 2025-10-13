import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
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

    // Group notes into columns for masonry effect with balanced heights
    final columns = List.generate(crossAxisCount, (_) => <Note>[]);
    final columnHeights = List.generate(crossAxisCount, (_) => 0.0);

    // Distribute notes by adding each to the shortest column
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final estimatedHeight = _estimateNoteCardHeight(note);

      // Find the shortest column
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
        child: Row(
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

                          if (sq != null) {
                            onHideSearchOverlay();
                          }

                          await context.pushHero(
                            NoteDetailScreen(
                              noteId: note.id,
                              searchQuery: sq,
                            ),
                          );
                        },
                      ),
                    )
                        .animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        )
                        .shimmer(
                          duration: 2000.ms,
                          delay: (index * 100 + 2000).ms,
                          color: Colors.white.withValues(alpha: 0.3),
                        );
                  }).toList(),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

