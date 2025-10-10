import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';

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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing20,
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
                          fontSize: 14,
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
                            fontSize: 11,
                            height: 1.3,
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
    if (note.headlines.isEmpty) return null;
    
    // Find the most recent entry
    TextEntry? latestEntry;
    DateTime? latestTime;
    
    for (final headline in note.headlines) {
      if (headline.entries.isEmpty) continue;
      
      for (final entry in headline.entries) {
        if (latestTime == null || entry.createdAt.isAfter(latestTime)) {
          latestEntry = entry;
          latestTime = entry.createdAt;
        }
      }
    }
    
    if (latestEntry == null) return null;
    
    // Get first line of text
    final lines = latestEntry.text.split('\n');
    return lines.first.trim();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}

