import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/openai_service.dart';
import '../ai_chat_overlay.dart';
import '../note_citation_chip.dart';

/// Individual chat message bubble widget
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;
  final ThemeConfig themeConfig;
  final Function(String noteId)? onNoteTap;
  final Function(ChatAction action)? onAction;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.index,
    required this.themeConfig,
    this.onNoteTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppTheme.spacing12,
          left: message.isUser ? 50 : 0,
          right: message.isUser ? 0 : 50,
        ),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: message.isUser
              ? themeConfig.primaryColor.withValues(alpha: 0.2)
              : AppTheme.glassStrongSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: message.isUser
                ? themeConfig.primaryColor.withValues(alpha: 0.3)
                : AppTheme.glassBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
            ),
            
            // Note citations
            if (message.noteCitations != null && message.noteCitations!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: message.noteCitations!.map((citation) {
                  return NoteCitationChip(
                    citation: citation,
                    onTap: onNoteTap != null ? () => onNoteTap!(citation.noteId) : null,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(delay: (index * 100).ms, duration: 300.ms)
          .slideX(
            begin: message.isUser ? 0.3 : -0.3,
            end: 0,
            delay: (index * 100).ms,
          ),
    );
  }
}

