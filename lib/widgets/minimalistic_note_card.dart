import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/folders_provider.dart';
import '../providers/notes_provider.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'quick_move_dialog.dart';
import 'custom_snackbar.dart';

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

  /// Show action menu with Move, Pin/Unpin, Delete options
  Future<void> _showNoteActions(BuildContext context) async {
    HapticService.light();
    
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xEE1A1F2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Move to folder'),
                onTap: () => Navigator.of(context).pop('move'),
              ),
              ListTile(
                leading: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
                onTap: () => Navigator.of(context).pop('pin'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete note', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return;

    if (action == 'move') {
      await _showMoveDialog(context);
    } else if (action == 'pin') {
      await _togglePin(context);
    } else if (action == 'delete') {
      await _deleteNote(context);
    }
  }

  Future<void> _showMoveDialog(BuildContext context) async {
    final foldersProvider = context.read<FoldersProvider>();
    final notesProvider = context.read<NotesProvider>();

    // Include unorganized folder in the list
    final allFolders = [
      if (foldersProvider.unorganizedFolder != null) foldersProvider.unorganizedFolder!,
      ...foldersProvider.userFolders,
    ];

    final selectedFolderId = await QuickMoveDialog.show(
      context: context,
      folders: allFolders,
      currentFolderId: note.folderId,
      noteIcon: note.icon,
      noteName: note.name,
      unorganizedFolderId: foldersProvider.unorganizedFolderId,
    );

    if (selectedFolderId != null && context.mounted) {
      await notesProvider.moveNoteToFolder(note.id, selectedFolderId);
      
      final folder = foldersProvider.getFolderById(selectedFolderId);
      if (context.mounted) {
        CustomSnackbar.show(
          context,
          message: 'Note moved to ${folder?.name ?? "folder"}',
          type: SnackbarType.success,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _togglePin(BuildContext context) async {
    final notesProvider = context.read<NotesProvider>();
    HapticService.success();
    
    final updatedNote = note.copyWith(isPinned: !note.isPinned);
    await notesProvider.updateNote(updatedNote);
    
    if (context.mounted) {
      CustomSnackbar.show(
        context,
        message: note.isPinned ? 'Note unpinned' : 'Note pinned',
        type: SnackbarType.success,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _deleteNote(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notesProvider = context.read<NotesProvider>();
      HapticService.success();
      await notesProvider.deleteNote(note.id);
      
      if (context.mounted) {
        CustomSnackbar.show(
          context,
          message: 'Note deleted',
          type: SnackbarType.success,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get first line of text from latest entry
    final firstLine = _getFirstLine();
    final timeText = _formatTime(note.lastAccessedAt ?? note.updatedAt);

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showNoteActions(context),
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
    if (note.content.isEmpty) return null;
    
    // Get first line of text
    final lines = note.content.split('\n');
    return lines.first.trim();
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Normalize dates to compare calendar days (ignoring time)
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final daysDifference = today.difference(dateDay).inDays;

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (daysDifference == 0) {
      // Same calendar day
      return '${difference.inHours}h';
    } else if (daysDifference == 1) {
      // Yesterday
      return 'yesterday';
    } else if (daysDifference < 7) {
      // Within the last week
      return '${daysDifference}d';
    } else {
      // Older than a week
      return '${date.day}/${date.month}';
    }
  }
}

