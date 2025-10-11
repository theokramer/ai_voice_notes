import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';

class NoteOrganizationSheet extends StatelessWidget {
  const NoteOrganizationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotesProvider, SettingsProvider>(
      builder: (context, provider, settingsProvider, child) {
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
              ),
              child: SafeArea(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing24,
                      ),
                      child: Text(
                        LocalizationService().t('organize_notes'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    
                    // View Type Section
                    _buildSectionHeader(context, LocalizationService().t('view_type')),
                    const SizedBox(height: AppTheme.spacing12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildViewTypeIconButton(
                            context,
                            Icons.view_headline,
                            NoteViewType.minimalisticList,
                            provider.noteViewType == NoteViewType.minimalisticList,
                            provider,
                            themeConfig,
                          ),
                          _buildViewTypeIconButton(
                            context,
                            Icons.grid_view,
                            NoteViewType.grid,
                            provider.noteViewType == NoteViewType.grid,
                            provider,
                            themeConfig,
                          ),
                          _buildViewTypeIconButton(
                            context,
                            Icons.view_agenda,
                            NoteViewType.standard,
                            provider.noteViewType == NoteViewType.standard,
                            provider,
                            themeConfig,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacing24),
                    
                    // Sort By Section
                    _buildSectionHeader(context, LocalizationService().t('sort_by')),
                    const SizedBox(height: AppTheme.spacing12),
                    _buildSortOption(
                      context,
                      LocalizationService().t('date_updated'),
                      Icons.update,
                      SortOption.recentlyUpdated,
                      provider.sortOption == SortOption.recentlyUpdated,
                      provider,
                      themeConfig,
                    ),
                    _buildSortOption(
                      context,
                      LocalizationService().t('date_created'),
                      Icons.calendar_today,
                      SortOption.dateCreated,
                      provider.sortOption == SortOption.dateCreated,
                      provider,
                      themeConfig,
                    ),
                    
                    const SizedBox(height: AppTheme.spacing24),
                  ],
                ),
              ),
            ),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget _buildViewTypeIconButton(
    BuildContext context,
    IconData icon,
    NoteViewType viewType,
    bool isSelected,
    NotesProvider provider,
    ThemeConfig themeConfig,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticService.light();
          provider.setNoteViewType(viewType);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: isSelected
                ? themeConfig.primaryColor.withValues(alpha: 0.15)
                : AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected
                  ? themeConfig.primaryColor.withValues(alpha: 0.4)
                  : AppTheme.glassBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? themeConfig.primaryColor : AppTheme.textSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    String label,
    IconData icon,
    SortOption sortOption,
    bool isSelected,
    NotesProvider provider,
    ThemeConfig themeConfig,
  ) {
    return InkWell(
      onTap: () {
        HapticService.light();
        if (isSelected) {
          // Toggle direction
          final newDirection = provider.sortDirection == SortDirection.ascending
              ? SortDirection.descending
              : SortDirection.ascending;
          provider.setSortDirection(newDirection);
        } else {
          // Set new sort option with default descending direction
          provider.setSortOption(sortOption);
          provider.setSortDirection(SortDirection.descending);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? themeConfig.primaryColor.withValues(alpha: 0.15)
              : AppTheme.glassSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? themeConfig.primaryColor.withValues(alpha: 0.4)
                : AppTheme.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                color: isSelected
                    ? themeConfig.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.glassSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: isSelected ? themeConfig.primaryColor : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? themeConfig.primaryColor : AppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                provider.sortDirection == SortDirection.descending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 20,
                color: themeConfig.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

