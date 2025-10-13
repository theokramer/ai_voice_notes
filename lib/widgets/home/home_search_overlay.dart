import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// Search overlay widget with AI integration
class HomeSearchOverlay extends StatelessWidget {
  final Animation<double> animation;
  final TextEditingController searchController;
  final bool isInChatMode;
  final Color primaryColor;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final Widget askAIButton;

  const HomeSearchOverlay({
    super.key,
    required this.animation,
    required this.searchController,
    required this.isInChatMode,
    required this.primaryColor,
    required this.onClose,
    required this.onChanged,
    required this.onSubmitted,
    required this.askAIButton,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -100 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7 * animation.value),
                        Colors.black.withValues(alpha: 0.4 * animation.value),
                        Colors.black.withValues(alpha: 0.1 * animation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacing48,
                    bottom: AppTheme.spacing8,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.glassStrongSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: searchController,
                                autofocus: true,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  hintText: isInChatMode
                                      ? LocalizationService().t('ask_ai_hint')
                                      : LocalizationService().t('search_notes_or_ask_ai'),
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                  prefixIcon: Icon(
                                    isInChatMode ? Icons.psychology : Icons.search,
                                    color: isInChatMode ? primaryColor : AppTheme.textTertiary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: AppTheme.textTertiary,
                                    ),
                                    onPressed: onClose,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                                ),
                                onChanged: onChanged,
                                onSubmitted: onSubmitted,
                              ),
                              const SizedBox(height: AppTheme.spacing12),
                              // Ask AI button (passed as widget)
                              askAIButton,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

