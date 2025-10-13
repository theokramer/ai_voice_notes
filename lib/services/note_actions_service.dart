import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/quick_move_dialog.dart';
import '../widgets/custom_snackbar.dart';

/// Centralized service for note actions (move, pin, delete)
/// Used by both NoteCard and MinimalisticNoteCard to eliminate duplication
class NoteActionsService {
  /// Show action menu with Move, Pin/Unpin, Delete options
  static Future<void> showActionsSheet({
    required BuildContext context,
    required Note note,
  }) async {
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

    switch (action) {
      case 'move':
        await moveNoteToFolder(context: context, note: note);
        break;
      case 'pin':
        await togglePin(context: context, note: note);
        break;
      case 'delete':
        await deleteNoteWithConfirmation(context: context, note: note);
        break;
    }
  }

  /// Show move dialog and move note to selected folder
  static Future<void> moveNoteToFolder({
    required BuildContext context,
    required Note note,
  }) async {
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

  /// Toggle note pin status
  static Future<void> togglePin({
    required BuildContext context,
    required Note note,
  }) async {
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

  /// Show confirmation dialog and delete note
  static Future<void> deleteNoteWithConfirmation({
    required BuildContext context,
    required Note note,
  }) async {
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
}

