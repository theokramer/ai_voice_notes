import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../services/note_actions_service.dart';
import '../utils/date_utils.dart' as date_utils;

class MinimalisticNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final int index;

  const MinimalisticNoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Get first line of text from latest entry
    final firstLine = _getFirstLine();
    final timeText = _formatTime(note.lastAccessedAt ?? note.updatedAt);

    return InkWell(
      onTap: onTap,
      onLongPress: () => NoteActionsService.showActionsSheet(
        context: context,
        note: note,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing24,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.glassBorder.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  // First line
                  if (firstLine != null)
                    Text(
                      firstLine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary.withValues(alpha: 0.7),
                            fontSize: 13,
                            height: 1.4,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Time
            Text(
              timeText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 30).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0, duration: 300.ms);
  }

  String? _getFirstLine() {
    // Use contentPreview which properly handles JSON/markdown extraction
    final preview = note.contentPreview;
    if (preview.isEmpty || preview == 'Unable to display content') return null;
    
    // Get first line from the preview
    final lines = preview.split('\n');
    final firstLine = lines.first.trim();
    
    // Limit length for display
    return firstLine.length > 80 ? '${firstLine.substring(0, 80)}...' : firstLine;
  }

  String _formatTime(DateTime date) {
    return date_utils.DateUtils.formatMinimalisticTime(date);
  }
}

