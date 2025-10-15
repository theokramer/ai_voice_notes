import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// Stunning search overlay with integrated Ask AI button
class HomeSearchOverlay extends StatelessWidget {
  final Animation<double> animation;
  final TextEditingController searchController;
  final bool isInChatMode;
  final Color primaryColor;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAskAI;
  final bool hasSearchQuery;

  const HomeSearchOverlay({
    super.key,
    required this.animation,
    required this.searchController,
    required this.isInChatMode,
    required this.primaryColor,
    required this.onClose,
    required this.onChanged,
    required this.onSubmitted,
    required this.onAskAI,
    required this.hasSearchQuery,
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
                    margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                isInChatMode
                                    ? primaryColor.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.12),
                                isInChatMode
                                    ? primaryColor.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isInChatMode
                                  ? primaryColor.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isInChatMode
                                    ? primaryColor.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Search icon
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  top: 14,
                                  bottom: 14,
                                  right: 8,
                                ),
                                child: Icon(
                                  isInChatMode ? Icons.auto_awesome_rounded : Icons.search_rounded,
                                  color: isInChatMode
                                      ? primaryColor.withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.9),
                                  size: 22,
                                ),
                              ),
                              
                              // Text field
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  autofocus: true,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isInChatMode
                                        ? 'Ask AI anything...'
                                        : LocalizationService().t('search_notes'),
                                    hintStyle: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                          fontSize: 16,
                                        ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: onChanged,
                                  onSubmitted: onSubmitted,
                                ),
                              ),
                              
                              // Ask AI button (compact, integrated)
                              if (!isInChatMode && hasSearchQuery)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: onAskAI,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              primaryColor.withValues(alpha: 0.9),
                                              primaryColor.withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Ask AI',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Close button
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: isInChatMode
                                        ? primaryColor.withValues(alpha: 0.9)
                                        : Colors.white.withValues(alpha: 0.8),
                                    size: 22,
                                  ),
                                  onPressed: onClose,
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                  splashRadius: 20,
                                ),
                              ),
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
