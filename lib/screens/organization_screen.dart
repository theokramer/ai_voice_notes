import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/organization_suggestion.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../services/openai_service.dart';
import '../services/haptic_service.dart';
import '../widgets/loading_indicator.dart';

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  bool _isLoading = false;
  List<NoteOrganizationSuggestion> _suggestions = [];
  final Set<String> _processedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  /// Consolidate similar new folder suggestions into one generic folder
  List<NoteOrganizationSuggestion> _consolidateSimilarFolders(List<NoteOrganizationSuggestion> suggestions) {
    // Find all unique new folder names suggested
    final newFolderNames = <String>{};
    for (final suggestion in suggestions) {
      if (suggestion.isCreatingNewFolder && suggestion.newFolderName != null) {
        newFolderNames.add(suggestion.newFolderName!.toLowerCase());
      }
    }
    
    if (newFolderNames.length <= 1) {
      // No consolidation needed
      return suggestions;
    }
    
    // Group similar folder names
    final Map<String, List<String>> similarGroups = {};
    final List<String> processedNames = [];
    
    for (final name1 in newFolderNames) {
      if (processedNames.contains(name1)) continue;
      
      final similarNames = <String>[name1];
      
      for (final name2 in newFolderNames) {
        if (name1 == name2 || processedNames.contains(name2)) continue;
        
        // Check if names are similar
        if (_areFolderNamesSimilar(name1, name2)) {
          similarNames.add(name2);
        }
      }
      
      if (similarNames.length > 1) {
        // Found a group of similar names
        final mostGeneric = _getMostGenericName(similarNames);
        similarGroups[mostGeneric] = similarNames;
        processedNames.addAll(similarNames);
        debugPrint('📁 Consolidating similar folders: ${similarNames.join(", ")} → $mostGeneric');
      }
    }
    
    if (similarGroups.isEmpty) {
      // No similar folders found
      return suggestions;
    }
    
    // Update suggestions to use the most generic name AND icon
    // First pass: collect the icon for each consolidated name (use first occurrence)
    final Map<String, String> consolidatedIcons = {};
    for (final suggestion in suggestions) {
      if (suggestion.isCreatingNewFolder && suggestion.newFolderName != null) {
        final lowerName = suggestion.newFolderName!.toLowerCase();
        
        // Check if this is a consolidated name
        for (final entry in similarGroups.entries) {
          if (entry.value.contains(lowerName)) {
            // Use the icon from the most generic name if not set yet
            if (!consolidatedIcons.containsKey(entry.key)) {
              consolidatedIcons[entry.key] = suggestion.newFolderIcon ?? '📁';
            }
            break;
          }
        }
      }
    }
    
    // Second pass: update suggestions with consolidated names and icons
    final updatedSuggestions = <NoteOrganizationSuggestion>[];
    for (final suggestion in suggestions) {
      if (suggestion.isCreatingNewFolder && suggestion.newFolderName != null) {
        final lowerName = suggestion.newFolderName!.toLowerCase();
        
        // Check if this folder name should be consolidated
        String? replacementName;
        String? replacementIcon;
        for (final entry in similarGroups.entries) {
          if (entry.value.contains(lowerName)) {
            replacementName = entry.key;
            replacementIcon = consolidatedIcons[entry.key];
            break;
          }
        }
        
        if (replacementName != null && replacementName != lowerName) {
          // Capitalize properly
          final capitalizedName = replacementName.split(' ')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' ');
          
          // Create a new suggestion with the consolidated folder name AND icon
          updatedSuggestions.add(NoteOrganizationSuggestion(
            noteId: suggestion.noteId,
            type: suggestion.type,
            targetFolderId: suggestion.targetFolderId,
            targetFolderName: suggestion.targetFolderName,
            newFolderName: capitalizedName,
            newFolderIcon: replacementIcon ?? suggestion.newFolderIcon ?? '📁',
            reasoning: suggestion.reasoning,
            confidence: suggestion.confidence,
            userSelectedFolderId: suggestion.userSelectedFolderId,
            userSelectedFolderName: suggestion.userSelectedFolderName,
            userModified: suggestion.userModified,
          ));
          debugPrint('  📎 Updated suggestion for note ${suggestion.noteId}: $lowerName → $capitalizedName (icon: ${replacementIcon ?? '📁'})');
        } else {
          updatedSuggestions.add(suggestion);
        }
      } else {
        updatedSuggestions.add(suggestion);
      }
    }
    
    return updatedSuggestions;
  }
  
  /// Check if two folder names are semantically similar
  bool _areFolderNamesSimilar(String name1, String name2) {
    // Define groups of similar keywords
    final similarityGroups = [
      ['journal', 'diary', 'reflection', 'reflections', 'thoughts', 'personal', 'daily'],
      ['work', 'business', 'professional', 'job', 'career'],
      ['idea', 'ideas', 'brainstorm', 'concept', 'concepts'],
      ['learning', 'study', 'education', 'course', 'notes'],
      ['project', 'projects', 'task', 'tasks'],
      ['meeting', 'meetings', 'discussion', 'discussions'],
    ];
    
    final n1 = name1.toLowerCase();
    final n2 = name2.toLowerCase();
    
    // Check if both names contain keywords from the same group
    for (final group in similarityGroups) {
      bool n1InGroup = group.any((keyword) => n1.contains(keyword));
      bool n2InGroup = group.any((keyword) => n2.contains(keyword));
      
      if (n1InGroup && n2InGroup) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Get the most generic name from a list of similar names
  String _getMostGenericName(List<String> names) {
    // Prefer names that are shorter and more general
    final genericityScores = <String, int>{};
    
    for (final name in names) {
      int score = 0;
      
      // Shorter names are often more generic
      score += (20 - name.length).clamp(0, 20);
      
      // Prefer certain generic terms
      if (name.contains('personal') || name.contains('thoughts')) score += 15;
      if (name.contains('work')) score += 10;
      if (name.contains('ideas')) score += 10;
      if (name.contains('learning')) score += 10;
      
      // Penalize very specific terms
      if (name.contains('daily')) score -= 5;
      if (name.contains('weekly')) score -= 5;
      if (name.contains('meeting')) score -= 5;
      
      genericityScores[name] = score;
    }
    
    // Return name with highest genericity score
    return genericityScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final notesProvider = context.read<NotesProvider>();
      final foldersProvider = context.read<FoldersProvider>();
      
      // Get unorganized notes
      final unorganizedFolderId = foldersProvider.unorganizedFolderId;
      final unorganizedNotes = notesProvider.notes.where((note) {
        return (note.folderId == null || note.folderId == unorganizedFolderId) &&
               !_processedNoteIds.contains(note.id);
      }).toList();

      debugPrint('OrganizationScreen: Found ${unorganizedNotes.length} unorganized notes');

      if (unorganizedNotes.isEmpty) {
        debugPrint('OrganizationScreen: No unorganized notes to organize');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get API key from environment
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        debugPrint('ERROR: No OpenAI API key found in environment');
        throw Exception('OpenAI API key not configured');
      }

      debugPrint('OrganizationScreen: API key loaded, calling AI service...');
      final openAIService = OpenAIService(apiKey: apiKey);

      final suggestions = await openAIService.generatePerNoteOrganizationSuggestions(
        unorganizedNotes: unorganizedNotes,
        folders: foldersProvider.folders,
      );

      debugPrint('OrganizationScreen: Received ${suggestions.length} suggestions from AI');

      // Post-process: Consolidate similar new folder suggestions
      final consolidatedSuggestions = _consolidateSimilarFolders(suggestions);
      debugPrint('OrganizationScreen: After consolidation: ${consolidatedSuggestions.length} suggestions');

      if (!mounted) return;
      setState(() {
        _suggestions = consolidatedSuggestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyAllSuggestions() async {
    // Check if there are any low-confidence suggestions that haven't been reviewed
    final unclearSuggestions = _suggestions
        .where((s) => s.needsUserAction && !_processedNoteIds.contains(s.noteId))
        .toList();

    if (unclearSuggestions.isNotEmpty) {
      // Show warning dialog
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unklare Notizen'),
          content: Text(
            '${unclearSuggestions.length} Notizen haben keine klare Zuordnung.\n\n'
            'Bitte überprüfe diese Notizen manuell, bevor du alle Vorschläge anwendest.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    HapticService.medium();
    
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    
    int processed = 0;
    
    // Group suggestions by destination folder to create folders efficiently
    // Use lowercase keys for case-insensitive matching
    final newFolders = <String, Folder>{};
    
    for (final suggestion in _suggestions) {
      if (_processedNoteIds.contains(suggestion.noteId)) continue;
      
      try {
        String? targetFolderId;
        
        if (suggestion.isCreatingNewFolder) {
          final folderName = suggestion.effectiveFolderName!;
          final folderNameLower = folderName.toLowerCase();
          
          // Check if we already created this folder in this batch
          if (newFolders.containsKey(folderNameLower)) {
            targetFolderId = newFolders[folderNameLower]!.id;
            debugPrint('Reusing folder from batch: ${newFolders[folderNameLower]!.name} (${targetFolderId})');
          } else {
            // Check if folder already exists in provider (case-insensitive)
            final existingFolder = foldersProvider.getFolderByName(folderName);
            
            if (existingFolder != null) {
              // Reuse existing folder
              targetFolderId = existingFolder.id;
              newFolders[folderNameLower] = existingFolder;
              debugPrint('Reusing existing folder: ${existingFolder.name} (${existingFolder.id})');
            } else {
              // Create new folder
              final newFolder = await foldersProvider.createFolder(
                name: folderName,
                icon: suggestion.newFolderIcon ?? '📁',
                aiCreated: true,
              );
              newFolders[folderNameLower] = newFolder;
              targetFolderId = newFolder.id;
              debugPrint('Created new folder: ${newFolder.name} (${newFolder.id})');
            }
          }
        } else {
          targetFolderId = suggestion.effectiveFolderId;
        }
        
        if (targetFolderId != null) {
          await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId);
          if (!mounted) return;
          setState(() {
            _processedNoteIds.add(suggestion.noteId);
          });
          processed++;
        }
      } catch (e) {
        debugPrint('Error processing suggestion for note ${suggestion.noteId}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$processed Notizen organisiert!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload to get updated list
      await _loadSuggestions();
    }
  }

  void _updateSuggestion(NoteOrganizationSuggestion oldSuggestion, NoteOrganizationSuggestion newSuggestion) {
    setState(() {
      final index = _suggestions.indexWhere((s) => s.noteId == oldSuggestion.noteId);
      if (index != -1) {
        _suggestions[index] = newSuggestion;
      }
    });
  }

  Future<void> _applySingleSuggestion(NoteOrganizationSuggestion suggestion) async {
    HapticService.light();
    
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    
    try {
      String? targetFolderId;
      
      if (suggestion.isCreatingNewFolder) {
        final folderName = suggestion.effectiveFolderName!;
        
        // Check if folder with this name already exists (case-insensitive)
        final existingFolder = foldersProvider.getFolderByName(folderName);
        
        if (existingFolder != null) {
          // Reuse existing folder
          targetFolderId = existingFolder.id;
          debugPrint('Reusing existing folder: ${existingFolder.name} (${existingFolder.id})');
        } else {
          // Create new folder
          final newFolder = await foldersProvider.createFolder(
            name: folderName,
            icon: suggestion.newFolderIcon ?? '📁',
            aiCreated: true,
          );
          targetFolderId = newFolder.id;
          debugPrint('Created new folder: ${newFolder.name} (${newFolder.id})');
        }
      } else {
        targetFolderId = suggestion.effectiveFolderId;
      }
      
      if (targetFolderId != null) {
        await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId);
        if (!mounted) return;
        setState(() {
          _processedNoteIds.add(suggestion.noteId);
        });
        
        HapticService.success();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notiz erfolgreich organisiert!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error applying suggestion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz löschen'),
        content: const Text('Möchtest du diese Notiz wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticService.success();
      final notesProvider = context.read<NotesProvider>();
      await notesProvider.deleteNote(noteId);
      
      if (!mounted) return;
      setState(() {
        _suggestions.removeWhere((s) => s.noteId == noteId);
        _processedNoteIds.add(noteId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final foldersProvider = context.watch<FoldersProvider>();
    
    final unorganizedFolderId = foldersProvider.unorganizedFolderId;
    final unorganizedNotes = notesProvider.getNotesInFolder(unorganizedFolderId)
        .where((note) => !_processedNoteIds.contains(note.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${unorganizedNotes.length} Notizen organisieren'),
        actions: [
          if (!_isLoading && _suggestions.isNotEmpty)
            TextButton.icon(
              onPressed: _applyAllSuggestions,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Alle anwenden'),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(unorganizedNotes, foldersProvider.folders),
          // Floating reorganize button at bottom
          if (unorganizedNotes.isNotEmpty && !_isLoading)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    // Clear processed notes and reload suggestions
                    setState(() {
                      _processedNoteIds.clear();
                    });
                    await _loadSuggestions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu organisieren'),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Note> unorganizedNotes, List<Folder> allFolders) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(
              size: 60,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Analysiere Notizen...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI findet die beste Organisation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (unorganizedNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Alles organisiert! 🎉',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Du hast keine unorganisierten Notizen',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Keine Vorschläge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Versuche mehr Notizen aufzunehmen',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Aktualisieren'),
            ),
          ],
        ),
      );
    }

    // Group suggestions by destination folder
    return _GroupedSuggestionsView(
      suggestions: _suggestions,
      notes: unorganizedNotes,
      folders: allFolders,
      processedNoteIds: _processedNoteIds,
      onUpdateSuggestion: _updateSuggestion,
      onDeleteNote: _deleteNote,
      onApplySuggestion: _applySingleSuggestion,
    );
  }
}

class _GroupedSuggestionsView extends StatelessWidget {
  final List<NoteOrganizationSuggestion> suggestions;
  final List<Note> notes;
  final List<Folder> folders;
  final Set<String> processedNoteIds;
  final Function(NoteOrganizationSuggestion, NoteOrganizationSuggestion) onUpdateSuggestion;
  final Function(String) onDeleteNote;
  final Function(NoteOrganizationSuggestion) onApplySuggestion;

  const _GroupedSuggestionsView({
    required this.suggestions,
    required this.notes,
    required this.folders,
    required this.processedNoteIds,
    required this.onUpdateSuggestion,
    required this.onDeleteNote,
    required this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    // Group suggestions by destination folder
    final Map<String, List<NoteOrganizationSuggestion>> groupedSuggestions = {};
    
    for (final suggestion in suggestions) {
      if (processedNoteIds.contains(suggestion.noteId)) continue;
      
      final key = suggestion.isCreatingNewFolder
          ? 'NEW:${suggestion.effectiveFolderName}'
          : 'EXISTING:${suggestion.effectiveFolderId}';
      
      if (!groupedSuggestions.containsKey(key)) {
        groupedSuggestions[key] = [];
      }
      groupedSuggestions[key]!.add(suggestion);
    }

    // Sort groups: new folders first, then existing folders
    final sortedKeys = groupedSuggestions.keys.toList()..sort((a, b) {
      if (a.startsWith('NEW:') && !b.startsWith('NEW:')) return -1;
      if (!a.startsWith('NEW:') && b.startsWith('NEW:')) return 1;
      return a.compareTo(b);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final groupSuggestions = groupedSuggestions[key]!;
        final firstSuggestion = groupSuggestions.first;
        
        return _FolderGroupCard(
          folderKey: key,
          suggestion: firstSuggestion,
          suggestions: groupSuggestions,
          allSuggestions: suggestions, // Pass ALL suggestions for pending folder detection
          notes: notes,
          folders: folders,
          onUpdateSuggestion: onUpdateSuggestion,
          onDeleteNote: onDeleteNote,
          onApplySuggestion: onApplySuggestion,
        );
      },
    );
  }
}

class _FolderGroupCard extends StatefulWidget {
  final String folderKey;
  final NoteOrganizationSuggestion suggestion;
  final List<NoteOrganizationSuggestion> suggestions; // Suggestions in this group
  final List<NoteOrganizationSuggestion> allSuggestions; // ALL suggestions globally
  final List<Note> notes;
  final List<Folder> folders;
  final Function(NoteOrganizationSuggestion, NoteOrganizationSuggestion) onUpdateSuggestion;
  final Function(String) onDeleteNote;
  final Function(NoteOrganizationSuggestion) onApplySuggestion;

  const _FolderGroupCard({
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
  State<_FolderGroupCard> createState() => _FolderGroupCardState();
}

class _FolderGroupCardState extends State<_FolderGroupCard> {
  bool _isExpanded = true;

  Future<void> _applyAllInGroup() async {
    final notesProvider = context.read<NotesProvider>();
    final foldersProvider = context.read<FoldersProvider>();
    
    // Use lowercase keys for case-insensitive matching
    final newFolders = <String, Folder>{};
    
    for (final suggestion in widget.suggestions) {
      try {
        String? targetFolderId;
        
        if (suggestion.isCreatingNewFolder) {
          final folderName = suggestion.effectiveFolderName!;
          final folderNameLower = folderName.toLowerCase();
          
          // Check if we already created this folder in this batch
          if (newFolders.containsKey(folderNameLower)) {
            targetFolderId = newFolders[folderNameLower]!.id;
            debugPrint('Reusing folder from group batch: ${newFolders[folderNameLower]!.name} (${targetFolderId})');
          } else {
            // Check if folder already exists in provider (case-insensitive)
            final existingFolder = foldersProvider.getFolderByName(folderName);
            
            if (existingFolder != null) {
              // Reuse existing folder
              targetFolderId = existingFolder.id;
              newFolders[folderNameLower] = existingFolder;
              debugPrint('Reusing existing folder in group: ${existingFolder.name} (${existingFolder.id})');
            } else {
              // Create new folder
              final newFolder = await foldersProvider.createFolder(
                name: folderName,
                icon: suggestion.newFolderIcon ?? '📁',
                aiCreated: true,
              );
              newFolders[folderNameLower] = newFolder;
              targetFolderId = newFolder.id;
              debugPrint('Created new folder in group: ${newFolder.name} (${newFolder.id})');
            }
          }
        } else {
          targetFolderId = suggestion.effectiveFolderId;
        }
        
        if (targetFolderId != null) {
          await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId);
        }
      } catch (e) {
        debugPrint('Error processing suggestion in group for note ${suggestion.noteId}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewFolder = widget.folderKey.startsWith('NEW:');
    final folderName = widget.suggestion.effectiveFolderName ?? 'Unbekannt';
    final folderIcon = isNewFolder ? widget.suggestion.newFolderIcon ?? '📁' : _getFolderIcon();
    
    final lowConfidenceCount = widget.suggestions.where((s) => s.isLowConfidence).length;
    final avgConfidence = widget.suggestions.map((s) => s.confidence).reduce((a, b) => a + b) / widget.suggestions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E), // Darker, consistent with app theme
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNewFolder ? Colors.green.shade700 : Colors.grey.shade700.withOpacity(0.5),
          width: isNewFolder ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isNewFolder 
                    ? Colors.green.shade900.withOpacity(0.3)
                    : const Color(0xFF242938), // Slightly lighter than background for contrast
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Folder icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNewFolder 
                          ? Colors.green.shade800.withOpacity(0.3)
                          : Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      folderIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Folder info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isNewFolder)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'NEU',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                folderName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${widget.suggestions.length} ${widget.suggestions.length == 1 ? "Notiz" : "Notizen"}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            if (lowConfidenceCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade900.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade700),
                                ),
                                child: Text(
                                  '$lowConfidenceCount unklar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade400,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getConfidenceColor(avgConfidence).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getConfidenceColor(avgConfidence)),
                              ),
                              child: Text(
                                '${(avgConfidence * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getConfidenceColor(avgConfidence),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Accept all in group button
                  IconButton(
                    onPressed: () async {
                      // Check if there are any low-confidence suggestions in this group
                      final unclearInGroup = widget.suggestions.where((s) => s.needsUserAction).toList();
                      
                      if (unclearInGroup.isNotEmpty) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Unklare Notizen'),
                            content: Text(
                              '${unclearInGroup.length} Notizen in dieser Gruppe haben keine klare Zuordnung.\n\n'
                              'Möchtest du trotzdem fortfahren?'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(foregroundColor: Colors.green),
                                child: const Text('Fortfahren'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed != true) return;
                      }
                      
                      await _applyAllInGroup();
                    },
                    icon: const Icon(Icons.done_all, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.green.shade400,
                      backgroundColor: Colors.green.shade900.withOpacity(0.2),
                    ),
                    tooltip: 'Alle in Gruppe akzeptieren',
                  ),
                  
                  // Expand/collapse icon
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: widget.suggestions.map((suggestion) {
                  final note = widget.notes.firstWhere(
                    (n) => n.id == suggestion.noteId,
                    orElse: () => widget.notes.first,
                  );
                  return _NoteOrganizationCard(
                    suggestion: suggestion,
                    note: note,
                    folders: widget.folders,
                    allSuggestions: widget.allSuggestions, // Pass ALL suggestions, not just group suggestions
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

  String _getFolderIcon() {
    if (!widget.folderKey.startsWith('EXISTING:')) return '📁';
    
    final folderId = widget.folderKey.substring(9);
    final folder = widget.folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => widget.folders.first,
    );
    return folder.icon;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade400;
    if (confidence >= 0.6) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}

class _NoteOrganizationCard extends StatelessWidget {
  final NoteOrganizationSuggestion suggestion;
  final Note note;
  final List<Folder> folders;
  final List<NoteOrganizationSuggestion> allSuggestions;
  final Function(NoteOrganizationSuggestion) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onApply;

  const _NoteOrganizationCard({
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
            : const Color(0xFF242938), // Darker for better contrast
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
                Text(note.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
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
                      const SizedBox(height: 2),
                      Text(
                        suggestion.reasoning,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
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
                      'Unsichere Zuordnung - Bitte überprüfen',
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
                    label: const Text('Akzeptieren'),
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
                      tooltip: 'Löschen',
                    ),
                    const SizedBox(width: 8),
                    
                    // Change folder button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFolderPicker(context),
                        icon: const Icon(Icons.folder_outlined, size: 16),
                        label: const Text(
                          'Ordner ändern',
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

  Future<void> _showFolderPicker(BuildContext context) async {
    final foldersProvider = context.read<FoldersProvider>();
    
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _FolderPickerDialog(
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

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade400;
    if (confidence >= 0.6) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}

class _FolderPickerDialog extends StatefulWidget {
  final List<Folder> folders;
  final NoteOrganizationSuggestion currentSuggestion;
  final List<NoteOrganizationSuggestion> allSuggestions;

  const _FolderPickerDialog({
    required this.folders,
    required this.currentSuggestion,
    required this.allSuggestions,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  final TextEditingController _newFolderController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingNew = false;
  String _searchQuery = '';
  
  /// Get filtered folders based on search
  List<Folder> get _filteredFolders {
    if (_searchQuery.isEmpty) {
      // Show top 5-7 folders by note count
      final sorted = List<Folder>.from(widget.folders)
        ..sort((a, b) => b.noteCount.compareTo(a.noteCount));
      return sorted.take(7).toList();
    }
    
    // Search in all folders
    final query = _searchQuery.toLowerCase();
    return widget.folders.where((folder) {
      return folder.name.toLowerCase().contains(query);
    }).toList();
  }
  
  /// Extract pending new folders from all suggestions
  List<Map<String, String>> get _pendingFolders {
    final Map<String, Map<String, String>> uniqueFolders = {};
    
    for (final suggestion in widget.allSuggestions) {
      if (suggestion.isCreatingNewFolder && 
          suggestion.newFolderName != null &&
          suggestion.noteId != widget.currentSuggestion.noteId) {
        final folderName = suggestion.newFolderName!;
        final folderIcon = suggestion.newFolderIcon ?? '📁';
        final lowerKey = folderName.toLowerCase();
        
        // Use case-insensitive key for deduplication, but keep original name
        if (!uniqueFolders.containsKey(lowerKey)) {
          uniqueFolders[lowerKey] = {
            'name': folderName,  // Keep original casing
            'icon': folderIcon,
          };
        }
      }
    }
    
    return uniqueFolders.values.toList();
  }

  /// Create folder immediately and return its ID
  Future<void> _createFolderAndReturn(BuildContext context, String folderName) async {
    try {
      final foldersProvider = context.read<FoldersProvider>();
      
      // Check if folder already exists
      final existingFolder = foldersProvider.getFolderByName(folderName);
      if (existingFolder != null) {
        // Folder already exists, just return it
        if (context.mounted) {
          Navigator.of(context).pop({
            'folderId': existingFolder.id,
            'folderName': existingFolder.name,
          });
        }
        return;
      }
      
      // Create new folder immediately
      final newFolder = await foldersProvider.createFolder(
        name: folderName,
        icon: '📁',
        aiCreated: false, // User created manually
      );
      
      debugPrint('✅ Manually created folder: ${newFolder.name} (${newFolder.id})');
      
      // Return the newly created folder
      if (context.mounted) {
        Navigator.of(context).pop({
          'folderId': newFolder.id,
          'folderName': newFolder.name,
        });
      }
    } catch (e) {
      debugPrint('Error creating folder: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen des Ordners: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  /// Get current folder name (where the note currently is)
  String? get _currentFolderName {
    if (widget.currentSuggestion.effectiveFolderId != null) {
      final folder = widget.folders.firstWhere(
        (f) => f.id == widget.currentSuggestion.effectiveFolderId,
        orElse: () => widget.folders.first,
      );
      return folder.name;
    } else if (widget.currentSuggestion.isCreatingNewFolder) {
      return widget.currentSuggestion.effectiveFolderName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pendingFolders = _pendingFolders;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xEE1A1F2E), // 93% opacity - consistent with app
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Ordner wählen',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                // Show current folder
                if (_currentFolderName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Aktuell: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _currentFolderName!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ordner suchen...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Content
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
            // Show count info for existing folders
            if (_searchQuery.isEmpty && _filteredFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Top ${_filteredFolders.length} Ordner',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            
            // Create new folder option
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.green),
              title: const Text('Neuen Ordner erstellen'),
              onTap: () {
                setState(() {
                  _isCreatingNew = !_isCreatingNew;
                });
              },
            ),
            
            if (_isCreatingNew) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _newFolderController,
                  decoration: const InputDecoration(
                    labelText: 'Ordnername',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  onSubmitted: (value) async {
                    if (value.isNotEmpty) {
                      await _createFolderAndReturn(context, value);
                    }
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_newFolderController.text.isNotEmpty) {
                    await _createFolderAndReturn(context, _newFolderController.text);
                  }
                },
                child: const Text('Erstellen'),
              ),
              const Divider(),
            ],
            
            // Folders list
            Expanded(
              child: _filteredFolders.isEmpty && pendingFolders.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Keine Ordner gefunden',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView(
                children: [
                  // Suggested New Folders section (only when not searching)
                  if (_searchQuery.isEmpty && pendingFolders.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(
                        'Vorgeschlagene neue Ordner',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...pendingFolders.map((folderData) {
                      return ListTile(
                        leading: Text(folderData['icon']!, style: const TextStyle(fontSize: 24)),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                folderData['name']!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.withOpacity(0.5)),
                              ),
                              child: const Text(
                                'Vorgeschlagen',
                                style: TextStyle(fontSize: 10, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text('Von anderen Notizen'),
                        onTap: () {
                          Navigator.of(context).pop({
                            'folderId': null,
                            'folderName': folderData['name'],
                          });
                        },
                      );
                    }).toList(),
                    const Divider(),
                  ],
                  
                  // Existing folders section (filtered)
                  if (_filteredFolders.isNotEmpty) ...[
                    if (_searchQuery.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Text(
                          'Vorhandene Ordner',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ..._filteredFolders.map((folder) {
                      return ListTile(
                        leading: Text(folder.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(
                          folder.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${folder.noteCount} ${folder.noteCount == 1 ? 'Notiz' : 'Notizen'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () {
                          Navigator.of(context).pop({
                            'folderId': folder.id,
                            'folderName': folder.name,
                          });
                        },
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
                      ],
                    ),
                  ),
                ),
            
            // Cancel button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
