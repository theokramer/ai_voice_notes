import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// Ask AI button widget with dynamic states
class HomeAskAIButton extends StatelessWidget {
  final String searchQuery;
  final bool hasResults;
  final Color primaryColor;
  final VoidCallback onTap;

  const HomeAskAIButton({
    super.key,
    required this.searchQuery,
    required this.hasResults,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchQuery.isNotEmpty;
    final noResults = hasQuery && !hasResults;
    
    final buttonText = hasQuery 
        ? LocalizationService().t('ask_ai_about', {'query': searchQuery})
        : LocalizationService().t('ask_ai');
    
    return AnimatedContainer(
      duration: AppTheme.animationNormal,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing24,
          0,
          AppTheme.spacing24,
          AppTheme.spacing16,
        ),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppTheme.animationNormal,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: primaryColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppTheme.animationNormal,
                  child: Icon(
                    Icons.psychology,
                    key: ValueKey(hasQuery),
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: AppTheme.animationNormal,
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                    child: Text(
                      buttonText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              )
              .shimmer(
                duration: noResults ? 1500.ms : 3000.ms,
                delay: noResults ? 0.ms : 5000.ms,
              ),
        ),
      ),
    );
  }
}

