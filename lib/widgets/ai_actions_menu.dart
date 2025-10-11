import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';

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

  static List<AIAction> getActions() {
    final loc = LocalizationService();
    return [
      // Note Management
      AIAction(
        id: 'consolidate',
        title: loc.t('consolidate_entries'),
        description: loc.t('action_consolidate_desc'),
        icon: Icons.merge,
        category: loc.t('note_management'),
        example: loc.t('action_consolidate_example'),
      ),
      AIAction(
        id: 'move_entries',
        title: loc.t('move_entries'),
        description: loc.t('action_move_entries_desc'),
        icon: Icons.drive_file_move_outline,
        category: loc.t('note_management'),
        example: loc.t('action_move_example'),
      ),
      AIAction(
        id: 'create_note',
        title: loc.t('action_create_note_from_chat'),
        description: loc.t('action_create_note_desc'),
        icon: Icons.note_add,
        category: loc.t('note_management'),
        example: loc.t('action_create_note_example'),
      ),
      // Content Analysis
      AIAction(
        id: 'summarize',
        title: loc.t('create_summary'),
        description: loc.t('action_summarize_desc'),
        icon: Icons.summarize,
        category: loc.t('content_analysis'),
        example: loc.t('action_summarize_example'),
      ),
      AIAction(
        id: 'extract_actions',
        title: loc.t('extract_action_items'),
        description: loc.t('action_extract_actions_desc'),
        icon: Icons.checklist,
        category: loc.t('content_analysis'),
        example: loc.t('action_extract_example'),
      ),
      AIAction(
        id: 'find_insights',
        title: loc.t('find_insights'),
        description: loc.t('action_find_insights_desc'),
        icon: Icons.lightbulb_outline,
        category: loc.t('content_analysis'),
        example: loc.t('action_insights_example'),
      ),
      // Organization
      AIAction(
        id: 'suggest_tags',
        title: loc.t('suggest_tags'),
        description: loc.t('action_suggest_tags_desc'),
        icon: Icons.label_outline,
        category: loc.t('organization'),
        example: loc.t('action_tags_example'),
      ),
      AIAction(
        id: 'search_notes',
        title: loc.t('smart_search'),
        description: loc.t('action_smart_search_desc'),
        icon: Icons.search,
        category: loc.t('organization'),
        example: loc.t('action_search_example'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        // Group actions by category
        final actions = getActions();
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
                            themeConfig.primaryColor,
                            themeConfig.primaryColor.withValues(alpha: 0.7),
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
                        LocalizationService().t('ai_actions'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        LocalizationService().t('ai_actions_subtitle'),
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
                        ...entry.value.map((action) => _buildActionCard(context, action, themeConfig)),
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
      },
    );
  }

  Widget _buildActionCard(BuildContext context, AIAction action, ThemeConfig themeConfig) {
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
                      color: themeConfig.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      action.icon,
                      color: themeConfig.primaryColor,
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

