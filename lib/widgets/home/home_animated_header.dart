import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';
import '../../widgets/hero_page_route.dart';
import '../../widgets/clean_search_bar.dart';
import '../../screens/settings_screen.dart';

/// Animated collapsing header for home screen
class HomeAnimatedHeader extends StatelessWidget {
  final double progress;
  final String greeting;
  final VoidCallback onSearchTap;
  final VoidCallback onOrganizeTap;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onAskAI;
  final bool hasSearchQuery;
  final bool isInChatMode;
  final bool isSearchFocused;
  final double pullDownOffset;

  const HomeAnimatedHeader({
    super.key,
    required this.progress,
    required this.greeting,
    required this.onSearchTap,
    required this.onOrganizeTap,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onAskAI,
    this.hasSearchQuery = false,
    this.isInChatMode = false,
    this.isSearchFocused = false,
    this.pullDownOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get safe area insets
    final safePadding = MediaQuery.of(context).padding.top;
    
    // Interpolate values based on scroll progress
    final double fontSize = 28 - (progress * 10); // 28 -> 18
    final double topPadding = 40 - (progress * 24); // 40 -> 16
    final double horizontalPadding = 24.0; // Fixed 24px to align with note cards
    final double iconOpacity = 0.85 + ((1 - progress) * 0.15);
    
    // Search bar and greeting scale down during transition
    final double searchBarHeight = 40 - (progress * 15); // 40 -> 25 (shrinks)
    final double greetingBottomPadding = 20 - (progress * 16); // 20 -> 4 (shrinks spacing)
    
    // Control when elements appear/disappear - better transition timing
    final double expandedOpacity = (1.0 - progress).clamp(0.0, 1.0);
    final double collapsedOpacity = ((progress - 0.7) * 3.33).clamp(0.0, 1.0);
    
    // Ensure opacity values are valid for Impeller
    final double safeExpandedOpacity = expandedOpacity.isNaN ? 0.0 : expandedOpacity;
    final double safeCollapsedOpacity = collapsedOpacity.isNaN ? 0.0 : collapsedOpacity;
    
    // Background opacity increases as we scroll
    final double backgroundOpacity = progress * 0.5;
    final double blurAmount = progress * 20;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassDarkSurface.withValues(alpha: backgroundOpacity),
            border: progress > 0.5 ? const Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder,
                width: 1.5,
              ),
            ) : null,
          ),
          child: Stack(
            children: [
              // EXPANDED STATE: Greeting + Search Bar
              if (expandedOpacity > 0)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  top: safePadding + topPadding,
                  child: Opacity(
                    opacity: safeExpandedOpacity,
                    child: IgnorePointer(
                      ignoring: expandedOpacity < 0.3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Greeting text with dynamic padding
                          Padding(
                            padding: EdgeInsets.only(bottom: greetingBottomPadding.clamp(4.0, 20.0)),
                            child: Text(
                              greeting,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                    color: AppTheme.textPrimary.withOpacity(0.9),
                                  ),
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                            ),
                          ),
                          // Search bar row with organize button
                          Row(
                            children: [
                              // New clean search bar
                              Expanded(
                                child: CleanSearchBar(
                                                      controller: searchController,
                                                      focusNode: searchFocusNode,
                                  onChanged: onSearchChanged,
                                  onSubmitted: onSearchSubmitted,
                                  onTap: onSearchTap,
                                  onAskAI: onAskAI,
                                                        hintText: isInChatMode
                                                            ? 'Chat with AI about notes...'
                                                            : 'Search notes',
                                  height: searchBarHeight.clamp(32.0, 44.0),
                                  showAIChatButton: !isInChatMode,
                                  hasSearchQuery: hasSearchQuery,
                                ),
                                  ),
                              const SizedBox(width: 8),
                              // Organize button
                              GestureDetector(
                                onTap: onOrganizeTap,
                                child: Container(
                                      width: searchBarHeight.clamp(32.0, 44.0),
                                      height: searchBarHeight.clamp(32.0, 44.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.more_horiz,
                                          size: 20,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            
              // COLLAPSED STATE: Home title with search and settings icons
              if (collapsedOpacity > 0)
                Positioned.fill(
                  top: safePadding,
                  child: Opacity(
                    opacity: safeCollapsedOpacity,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Search icon on left
                          GestureDetector(
                            onTap: onSearchTap,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isInChatMode ? Icons.auto_awesome : Icons.search,
                                size: 22,
                                color: AppTheme.textPrimary.withOpacity(iconOpacity),
                              ),
                            ),
                          ),
                          // "Home" title - centered
                          Expanded(
                            child: Text(
                              'Home',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: AppTheme.textPrimary,
                                  ),
                              overflow: TextOverflow.visible,
                              maxLines: 1,
                            ),
                          ),
                          // Settings icon on right
                          GestureDetector(
                            onTap: () async {
                              await HapticService.light();
                              await context.pushHero(const SettingsScreen());
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.settings_outlined,
                                size: 22,
                                color: AppTheme.textPrimary.withOpacity(iconOpacity),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            
              // Settings icon for expanded state (top-right)
              if (expandedOpacity > 0)
                Positioned(
                  top: safePadding + 8,
                  right: 24,
                  child: Opacity(
                    opacity: safeExpandedOpacity,
                    child: GestureDetector(
                      onTap: () async {
                        await HapticService.light();
                        await context.pushHero(const SettingsScreen());
                      },
                      child: Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: AppTheme.textPrimary.withOpacity(iconOpacity),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom SliverPersistentHeaderDelegate for animated header
class AnimatedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double) builder;
  final double expandedHeight;
  final double collapsedHeight;

  AnimatedHeaderDelegate({
    required this.builder,
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double shrinkProgress = (shrinkOffset / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
    return SizedBox.expand(
      child: builder(shrinkProgress),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant AnimatedHeaderDelegate oldDelegate) {
    return true; // Always rebuild for smooth animation
  }
}

