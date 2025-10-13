import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Empty state widget for home screen
class HomeEmptyState extends StatelessWidget {
  final bool hasSearchQuery;
  final String searchQuery;

  const HomeEmptyState({
    super.key,
    required this.hasSearchQuery,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!hasSearchQuery) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  decoration: BoxDecoration(
                    color: AppTheme.glassSurface.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sticky_note_2_outlined,
                    size: 40,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],
              Text(
                hasSearchQuery ? 'No results found' : 'No notes yet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                hasSearchQuery
                    ? 'Try different search terms'
                    : 'Press and hold the microphone\nto record your first note',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(
            duration: AppTheme.animationSlow,
            delay: 200.ms,
          )
          .slideY(
            begin: 0.1,
            end: 0,
            duration: AppTheme.animationSlow,
            delay: 200.ms,
          ),
    );
  }
}

