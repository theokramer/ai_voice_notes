import 'package:flutter/material.dart';
import '../../models/note.dart';
import '../../models/folder.dart';
import '../../models/organization_suggestion.dart';

/// Reusable card for displaying a single note organization suggestion
class OrganizationSuggestionCard extends StatelessWidget {
  final NoteOrganizationSuggestion suggestion;
  final Note note;
  final List<Folder> folders;
  final List<NoteOrganizationSuggestion> allSuggestions;
  final Function(NoteOrganizationSuggestion) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onApply;

  const OrganizationSuggestionCard({
    super.key,
    required this.suggestion,
    required this.note,
    required this.folders,
    required this.allSuggestions,
    required this.onUpdate,
    required this.onDelete,
    required this.onApply,
  });

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
          // Note info section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                // Note content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (note.content.isNotEmpty)
                        Text(
                          note.content,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Anwenden'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade400,
                      side: BorderSide(color: Colors.green.shade700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red.shade400,
                  tooltip: 'Ablehnen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

