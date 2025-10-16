import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../models/organization_suggestion.dart';
import '../../providers/folders_provider.dart';
import '../../services/haptic_service.dart';
import '../../services/localization_service.dart';
import 'folder_picker_dialog.dart';

/// Displays a single note organization suggestion with actions
class NoteOrganizationCard extends StatelessWidget {
  final NoteOrganizationSuggestion suggestion;
  final Note note;
  final List<Folder> folders;
  final List<NoteOrganizationSuggestion> allSuggestions;
  final Function(NoteOrganizationSuggestion) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onApply;

  const NoteOrganizationCard({
    super.key,
    required this.suggestion,
    required this.note,
    required this.folders,
    required this.allSuggestions,
    required this.onUpdate,
    required this.onDelete,
    required this.onApply,
  });

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade400;
    if (confidence >= 0.6) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  Future<void> _showFolderPicker(BuildContext context) async {
    final foldersProvider = context.read<FoldersProvider>();
    
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => FolderPickerDialog(
        folders: foldersProvider.userFolders,
        currentSuggestion: suggestion,
        allSuggestions: allSuggestions,
      ),
    );

    if (result != null) {
      HapticService.light();
      final updated = suggestion.copyWith(
        userSelectedFolderId: result['folderId'],
        userSelectedFolderName: result['folderName'],
        userModified: true,
      );
      onUpdate(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAction = suggestion.needsUserAction;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: needsAction 
            ? Colors.orange.shade900.withOpacity(0.2)
            : const Color(0xFF242938),
        borderRadius: BorderRadius.circular(12),
        border: needsAction 
            ? Border.all(color: Colors.orange.shade700, width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          // Note info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Confidence badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(suggestion.confidence).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _getConfidenceColor(suggestion.confidence)),
                  ),
                  child: Text(
                    '${(suggestion.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(suggestion.confidence),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Warning for low confidence
          if (needsAction)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withOpacity(0.3),
                border: Border(
                  top: BorderSide(color: Colors.orange.shade700),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uncertain assignment - Please review',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Actions
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Primary action: Accept suggestion
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(LocalizationService().t('accept')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Secondary actions
                Row(
                  children: [
                    // Delete button
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        backgroundColor: Colors.red.shade900.withOpacity(0.2),
                      ),
                      tooltip: 'Delete',
                    ),
                    const SizedBox(width: 8),
                    
                    // Change folder button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFolderPicker(context),
                        icon: const Icon(Icons.folder_outlined, size: 16),
                        label: const Text(
                          'Change Folder',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

