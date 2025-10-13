import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../models/organization_suggestion.dart';
import '../../providers/notes_provider.dart';
import '../../providers/folders_provider.dart';
import '../../services/localization_service.dart';
import '../../services/recording_queue_service.dart';
import 'note_organization_card.dart';

/// Groups organization suggestions by folder with expand/collapse functionality
class FolderGroupCard extends StatefulWidget {
  final String folderKey;
  final NoteOrganizationSuggestion suggestion;
  final List<NoteOrganizationSuggestion> suggestions;
  final List<NoteOrganizationSuggestion> allSuggestions;
  final List<Note> notes;
  final List<Folder> folders;
  final Function(NoteOrganizationSuggestion, NoteOrganizationSuggestion) onUpdateSuggestion;
  final Function(String) onDeleteNote;
  final Function(NoteOrganizationSuggestion) onApplySuggestion;

  const FolderGroupCard({
    super.key,
    required this.folderKey,
    required this.suggestion,
    required this.suggestions,
    required this.allSuggestions,
    required this.notes,
    required this.folders,
    required this.onUpdateSuggestion,
    required this.onDeleteNote,
    required this.onApplySuggestion,
  });

  @override
  State<FolderGroupCard> createState() => _FolderGroupCardState();
}

class _FolderGroupCardState extends State<FolderGroupCard> {
  bool _isExpanded = true;

  Future<void> _applyAllInGroup() async {
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    
    final newFolders = <String, Folder>{};
    
    for (final suggestion in widget.suggestions) {
      try {
        String? targetFolderId;
        
        if (suggestion.isCreatingNewFolder) {
          final folderName = suggestion.effectiveFolderName!;
          final folderNameLower = folderName.toLowerCase();
          
          if (newFolders.containsKey(folderNameLower)) {
            targetFolderId = newFolders[folderNameLower]!.id;
          } else {
            final existingFolder = foldersProvider.getFolderByName(folderName);
            
            if (existingFolder != null) {
              targetFolderId = existingFolder.id;
              newFolders[folderNameLower] = existingFolder;
            } else {
              final smartIcon = suggestion.newFolderIcon ?? getSmartEmojiForFolder(folderName);
              final newFolder = await foldersProvider.createFolder(
                name: folderName,
                icon: smartIcon,
                aiCreated: true,
              );
              newFolders[folderNameLower] = newFolder;
              targetFolderId = newFolder.id;
            }
          }
        } else {
          targetFolderId = suggestion.effectiveFolderId;
        }
        
        if (targetFolderId != null) {
          await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId);
        }
      } catch (e) {
        debugPrint('Error processing suggestion: $e');
      }
    }
  }

  String _getFolderIcon() {
    if (!widget.folderKey.startsWith('EXISTING:')) return '📁';
    
    final folderId = widget.folderKey.substring(9);
    final folder = widget.folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => widget.folders.first,
    );
    return folder.icon;
  }

  @override
  Widget build(BuildContext context) {
    final isNewFolder = widget.folderKey.startsWith('NEW:');
    final folderName = widget.suggestion.effectiveFolderName ?? 'Unknown';
    final folderIcon = isNewFolder ? widget.suggestion.newFolderIcon ?? '📁' : _getFolderIcon();
    
    final lowConfidenceCount = widget.suggestions.where((s) => s.isLowConfidence).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1f2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isNewFolder
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.blue.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(folderIcon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isNewFolder)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(LocalizationService().t('new'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            Expanded(
                              child: Text(
                                folderName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.suggestions.length} notes',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        ),
                        if (lowConfidenceCount > 0)
                          Text(
                            '$lowConfidenceCount needs review',
                            style: TextStyle(color: Colors.orange.shade400, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _applyAllInGroup,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Apply all in group',
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.suggestions.map((suggestion) {
                  final note = widget.notes.firstWhere(
                    (n) => n.id == suggestion.noteId,
                    orElse: () => widget.notes.first,
                  );
                  return NoteOrganizationCard(
                    suggestion: suggestion,
                    note: note,
                    folders: widget.folders,
                    allSuggestions: widget.allSuggestions,
                    onUpdate: (updated) => widget.onUpdateSuggestion(suggestion, updated),
                    onDelete: () => widget.onDeleteNote(suggestion.noteId),
                    onApply: () => widget.onApplySuggestion(suggestion),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

