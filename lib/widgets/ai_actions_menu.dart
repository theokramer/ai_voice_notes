import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class AIAction {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final String example;

  const AIAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.example,
  });
}

class AIActionsMenu extends StatelessWidget {
  final Function(AIAction) onActionSelected;
  final VoidCallback onClose;

  const AIActionsMenu({
    super.key,
    required this.onActionSelected,
    required this.onClose,
  });

  static final List<AIAction> actions = [
    // Note Management
    AIAction(
      id: 'consolidate',
      title: 'Consolidate Entries',
      description: 'Merge similar entries across notes into organized sections',
      icon: Icons.merge,
      category: 'Note Management',
      example: 'Combine all meeting notes into a single document',
    ),
    AIAction(
      id: 'move_entries',
      title: 'Move Entries',
      description: 'Intelligently suggest where entries should be moved',
      icon: Icons.drive_file_move_outline,
      category: 'Note Management',
      example: 'Move related entries to appropriate notes',
    ),
    AIAction(
      id: 'create_note',
      title: 'Create Note from Chat',
      description: 'Turn this conversation into a structured note',
      icon: Icons.note_add,
      category: 'Note Management',
      example: 'Create a note with all discussed points',
    ),
    // Content Analysis
    AIAction(
      id: 'summarize',
      title: 'Create Summary',
      description: 'Generate a concise summary of selected notes',
      icon: Icons.summarize,
      category: 'Content Analysis',
      example: 'Summarize all notes from this week',
    ),
    AIAction(
      id: 'extract_actions',
      title: 'Extract Action Items',
      description: 'Find and list all action items from your notes',
      icon: Icons.checklist,
      category: 'Content Analysis',
      example: 'List all TODOs mentioned in notes',
    ),
    AIAction(
      id: 'find_insights',
      title: 'Find Insights',
      description: 'Discover patterns and connections in your notes',
      icon: Icons.lightbulb_outline,
      category: 'Content Analysis',
      example: 'Show recurring themes in my project notes',
    ),
    // Organization
    AIAction(
      id: 'suggest_tags',
      title: 'Suggest Tags',
      description: 'Recommend relevant tags for better organization',
      icon: Icons.label_outline,
      category: 'Organization',
      example: 'Tag all notes with relevant topics',
    ),
    AIAction(
      id: 'search_notes',
      title: 'Smart Search',
      description: 'Search across all notes with natural language',
      icon: Icons.search,
      category: 'Organization',
      example: 'Find notes about design decisions',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Group actions by category
    final groupedActions = <String, List<AIAction>>{};
    for (final action in actions) {
      groupedActions.putIfAbsent(action.category, () => []).add(action);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glassStrongSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
        border: Border.all(color: AppTheme.glassBorder, width: 1.5),
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
          const SizedBox(height: AppTheme.spacing16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'Choose what AI should help with',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  iconSize: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          // Actions list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              children: groupedActions.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing8,
                      ),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                    ...entry.value.map((action) => _buildActionCard(context, action)),
                    const SizedBox(height: AppTheme.spacing12),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
      ),
    )
        .animate()
        .slideY(
          begin: 0.3,
          end: 0,
          duration: AppTheme.animationNormal,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: AppTheme.animationNormal);
  }

  Widget _buildActionCard(BuildContext context, AIAction action) {
    return GestureDetector(
      onTap: () => onActionSelected(action),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.glassSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      action.icon,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
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
}

