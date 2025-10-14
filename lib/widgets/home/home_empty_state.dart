import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Empty state widget for home screen
class HomeEmptyState extends StatelessWidget {
  final bool hasSearchQuery;
  final String searchQuery;
  final bool isViewingUnorganized;

  const HomeEmptyState({
    super.key,
    required this.hasSearchQuery,
    required this.searchQuery,
    this.isViewingUnorganized = false,
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
              Text(
                hasSearchQuery 
                    ? 'No results found' 
                    : isViewingUnorganized 
                        ? 'All Notes organized! 🎉'
                        : 'No notes yet',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                hasSearchQuery
                    ? 'Try different search terms'
                    : isViewingUnorganized
                        ? 'Great job! All your notes are organized into folders.'
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

