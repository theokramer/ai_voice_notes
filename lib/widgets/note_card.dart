import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/note_actions_service.dart';
import '../utils/date_utils.dart' as date_utils;

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final String? searchQuery;
  final List<String>? matchedSnippets;
  final int index;
  final bool isGridView;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.searchQuery,
    this.matchedSnippets,
    this.index = 0,
    this.isGridView = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return RepaintBoundary(
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onLongPress: () => NoteActionsService.showActionsSheet(
              context: context,
              note: widget.note,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, -_elevationAnimation.value / 2),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              _isPressed ? 0.3 : 0.2,
                            ),
                            blurRadius: 20 + _elevationAnimation.value,
                            offset: Offset(0, 10 + _elevationAnimation.value),
                          ),
                          if (_isPressed)
                            BoxShadow(
                              color: themeConfig.accentColor.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.glassStrongSurface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                              border: Border.all(
                                color: _isPressed
                                    ? themeConfig.accentColor.withOpacity(0.4)
                                    : AppTheme.glassBorder.withOpacity(0.25),
                                width: 1,
                              ),
                              // Animated gradient accent on the side
                              gradient: _isPressed
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        themeConfig.accentColor.withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                    )
                                  : null,
                            ),
                            padding: widget.isGridView
                                ? const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing16,
                                    vertical: AppTheme.spacing12,
                                  )
                                : const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacing20,
                                    vertical: AppTheme.spacing16,
                                  ),
                            child: Row(
                              children: [
                                // Content  
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.note.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontSize: widget.isGridView ? 15 : 17,
                                                    fontWeight: widget.isGridView ? FontWeight.w500 : FontWeight.w600,
                                                    letterSpacing: -0.2,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (widget.note.isPinned)
                                            Padding(
                                              padding: const EdgeInsets.only(left: AppTheme.spacing4),
                                              child: Icon(
                                                Icons.push_pin,
                                                size: 14,
                                                color: themeConfig.primaryColor.withOpacity(0.7),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppTheme.spacing4),
                                      Text(
                                        _formatDate(widget.note.updatedAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textTertiary.withOpacity(0.6),
                                              fontSize: 13,
                                              letterSpacing: 0.2,
                                            ),
                                      ),
                                      // Show first sentence in grid view (no max lines for dynamic height)
                                      if (widget.isGridView) ...[
                                        const SizedBox(height: AppTheme.spacing8),
                                        Text(
                                          _getFirstSentence(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppTheme.textSecondary.withOpacity(0.8),
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                        ),
                                      ],
                                      // Show search snippets
                                      if (widget.matchedSnippets != null &&
                                          widget.matchedSnippets!.isNotEmpty) ...[
                                        const SizedBox(height: AppTheme.spacing4),
                                        ...widget.matchedSnippets!
                                            .take(1)
                                            .map((snippet) => Padding(
                                                  padding: const EdgeInsets.only(
                                                    bottom: AppTheme.spacing4,
                                                  ),
                                                  child: _buildHighlightedSnippet(
                                                    snippet,
                                                    widget.searchQuery ?? '',
                                                    themeConfig,
                                                  ),
                                                ))
                                            .toList(),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        )
            .animate(delay: (widget.index * 50).ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
      },
    );
  }

  Widget _buildHighlightedSnippet(
    String snippet,
    String searchQuery,
    ThemeConfig themeConfig,
  ) {
    if (searchQuery.isEmpty) {
      return Text(
        snippet,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondary,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerSnippet = snippet.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < snippet.length) {
      final matchIndex = lowerSnippet.indexOf(lowerQuery, currentIndex);

      if (matchIndex == -1) {
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: snippet.substring(currentIndex),
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ));
        break;
      }

      // Add text before match
      if (matchIndex > currentIndex) {
        spans.add(TextSpan(
          text: snippet.substring(currentIndex, matchIndex),
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: snippet.substring(matchIndex, matchIndex + searchQuery.length),
        style: TextStyle(
          fontSize: 11,
          color: themeConfig.accentColor,
          fontWeight: FontWeight.w700,
          backgroundColor: themeConfig.accentColor.withValues(alpha: 0.2),
        ),
      ));

      currentIndex = matchIndex + searchQuery.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDate(DateTime date) {
    return date_utils.DateUtils.formatRelativeDate(date);
  }

  String _getFirstSentence() {
    // Use contentPreview which handles JSON extraction properly
    final preview = widget.note.contentPreview;
    if (preview.isEmpty) {
      return 'No content';
    }
    
    // Split into words
    final words = preview.split(RegExp(r'\s+'));
    
    // If less than 35 words, return everything
    if (words.length <= 35) {
      return preview.trim();
    }
    
    // Get first 35 words
    final first35Words = words.take(35).join(' ');
    
    // Find the last sentence-ending punctuation within the 35-word range
    final sentenceEndPattern = RegExp(r'[.!?]');
    final matches = sentenceEndPattern.allMatches(first35Words);
    
    if (matches.isNotEmpty) {
      // Get the last match within the 35-word range
      final lastMatch = matches.last;
      return first35Words.substring(0, lastMatch.end).trim();
    }
    
    // If no sentence end found in 35 words, return 35 words with ellipsis
    return '$first35Words...';
  }
}



