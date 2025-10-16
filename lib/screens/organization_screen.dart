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
import '../services/localization_service.dart';
import '../services/recording_queue_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/organization/folder_group_card.dart';

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
            content: Text('${LocalizationService().t('failed_to_load')}: $e'),
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
          title: Text(LocalizationService().t('unclear_notes')),
          content: Text(
            LocalizationService().t('unclear_notes_warning', {'count': unclearSuggestions.length.toString()})
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LocalizationService().t('ok')),
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
              // Create new folder with smart icon
              // Always use getSmartEmojiForFolder if AI returns null or default folder icon
              final aiIcon = suggestion.newFolderIcon;
              final smartIcon = (aiIcon == null || aiIcon == '📁') 
                  ? getSmartEmojiForFolder(folderName) 
                  : aiIcon;
              final newFolder = await foldersProvider.createFolder(
                name: folderName,
                icon: smartIcon,
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
          await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId, foldersProvider: foldersProvider);
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
          content: Text(LocalizationService().t('notes_organized_count', {'count': processed.toString()})),
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
          // Create new folder with smart icon
          // Always use getSmartEmojiForFolder if AI returns null or default folder icon
          final aiIcon = suggestion.newFolderIcon;
          final smartIcon = (aiIcon == null || aiIcon == '📁') 
              ? getSmartEmojiForFolder(folderName) 
              : aiIcon;
          final newFolder = await foldersProvider.createFolder(
            name: folderName,
            icon: smartIcon,
            aiCreated: true,
          );
          targetFolderId = newFolder.id;
          debugPrint('Created new folder: ${newFolder.name} (${newFolder.id})');
        }
      } else {
        targetFolderId = suggestion.effectiveFolderId;
      }
      
      if (targetFolderId != null) {
        await notesProvider.moveNoteToFolder(suggestion.noteId, targetFolderId, foldersProvider: foldersProvider);
        if (!mounted) return;
        setState(() {
          _processedNoteIds.add(suggestion.noteId);
        });
        
        HapticService.success();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService().t('note_organized_success')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error applying suggestion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().t('error')}: $e'),
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
        title: Text(LocalizationService().t('delete_note_confirm_title')),
        content: Text(LocalizationService().t('delete_note_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocalizationService().t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(LocalizationService().t('delete')),
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
        title: Text(unorganizedNotes.length == 1 
            ? '${unorganizedNotes.length} Note' 
            : '${unorganizedNotes.length} Notes'),
        actions: [
          if (!_isLoading && _suggestions.isNotEmpty)
            TextButton.icon(
              onPressed: _applyAllSuggestions,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(LocalizationService().t('apply_all')),
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
                  label: Text(LocalizationService().t('reorganize')),
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
              'Analyzing Notes...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AI finds the best organization',
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
              'All organized! 🎉',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no unorganized notes',
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
              'No Suggestions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try recording more notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _loadSuggestions,
              icon: const Icon(Icons.refresh),
              label: Text(LocalizationService().t('update')),
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
  final Function(NoteOrganizationSuggestion, NoteOrganizationSuggestion) onUpdateSuggestion;
  final Function(String) onDeleteNote;
  final Function(NoteOrganizationSuggestion) onApplySuggestion;

  const _GroupedSuggestionsView({
    required this.suggestions,
    required this.notes,
    required this.folders,
    required this.onUpdateSuggestion,
    required this.onDeleteNote,
    required this.onApplySuggestion,
  });

  @override
  Widget build(BuildContext context) {
    // Group suggestions by destination folder
    final Map<String, List<NoteOrganizationSuggestion>> groupedSuggestions = {};
    
    for (final suggestion in suggestions) {
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
        
        return FolderGroupCard(
          folderKey: key,
          suggestion: firstSuggestion,
          suggestions: groupSuggestions,
          allSuggestions: suggestions,
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
