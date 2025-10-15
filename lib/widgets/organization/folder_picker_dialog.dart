import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/folder.dart';
import '../../models/organization_suggestion.dart';
import '../../providers/folders_provider.dart';
import '../../services/localization_service.dart';
import '../../services/recording_queue_service.dart';

/// Dialog for picking or creating a folder for organization
class FolderPickerDialog extends StatefulWidget {
  final List<Folder> folders;
  final NoteOrganizationSuggestion currentSuggestion;
  final List<NoteOrganizationSuggestion> allSuggestions;

  const FolderPickerDialog({
    super.key,
    required this.folders,
    required this.currentSuggestion,
    required this.allSuggestions,
  });

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  final TextEditingController _newFolderController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingNew = false;
  String _searchQuery = '';
  
  List<Folder> get _filteredFolders {
    if (_searchQuery.isEmpty) {
      // Sort folders alphabetically
      final sorted = List<Folder>.from(widget.folders)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted;
    }
    
    final query = _searchQuery.toLowerCase();
    final filtered = widget.folders.where((folder) {
      return folder.name.toLowerCase().contains(query);
    }).toList();
    
    // Sort search results alphabetically
    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }
  
  List<Map<String, String>> get _pendingFolders {
    final Map<String, Map<String, String>> uniqueFolders = {};
    
    for (final suggestion in widget.allSuggestions) {
      if (suggestion.isCreatingNewFolder && 
          suggestion.newFolderName != null &&
          suggestion.noteId != widget.currentSuggestion.noteId) {
        final folderName = suggestion.newFolderName!;
        final folderIcon = suggestion.newFolderIcon ?? '📁';
        final lowerKey = folderName.toLowerCase();
        
        if (!uniqueFolders.containsKey(lowerKey)) {
          uniqueFolders[lowerKey] = {
            'name': folderName,
            'icon': folderIcon,
          };
        }
      }
    }
    
    return uniqueFolders.values.toList();
  }

  Future<void> _createFolderAndReturn(BuildContext context, String folderName) async {
    try {
      final foldersProvider = context.read<FoldersProvider>();
      
      final existingFolder = foldersProvider.getFolderByName(folderName);
      if (existingFolder != null) {
        if (context.mounted) {
          Navigator.of(context).pop({
            'folderId': existingFolder.id,
            'folderName': existingFolder.name,
          });
        }
        return;
      }
      
      final newFolder = await foldersProvider.createFolder(
        name: folderName,
        icon: getSmartEmojiForFolder(folderName),
        aiCreated: false,
      );
      
      if (context.mounted) {
        Navigator.of(context).pop({
          'folderId': newFolder.id,
          'folderName': newFolder.name,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService().t('error_creating_folder')}: $e'),
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
              color: const Color(0xEE1A1F2E),
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
                const Text(
                  'Choose folder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                
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
                        Text('${LocalizationService().t('current')}: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_currentFolderName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search folders...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ..._filteredFolders.map((folder) => ListTile(
                        leading: Text(folder.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(folder.name),
                        subtitle: Text('${folder.noteCount} notes'),
                        onTap: () => Navigator.of(context).pop({
                          'folderId': folder.id,
                          'folderName': folder.name,
                        }),
                      )),
                      
                      if (pendingFolders.isNotEmpty) ...[
                        const Divider(),
                        ...pendingFolders.map((pending) => ListTile(
                          leading: Text(pending['icon']!, style: const TextStyle(fontSize: 24)),
                          title: Text(pending['name']!),
                          trailing: const Chip(label: Text('NEW', style: TextStyle(fontSize: 10))),
                          onTap: () => Navigator.of(context).pop({
                            'folderId': null,
                            'folderName': pending['name'],
                          }),
                        )),
                      ],
                      
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline),
                        title: Text(LocalizationService().t('create_new_folder')),
                        onTap: () => setState(() => _isCreatingNew = true),
                      ),
                      
                      if (_isCreatingNew) ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextField(
                                controller: _newFolderController,
                                decoration: const InputDecoration(
                                  hintText: 'Folder name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => _isCreatingNew = false),
                                    child: Text(LocalizationService().t('cancel')),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: () => _createFolderAndReturn(context, _newFolderController.text),
                                    child: Text(LocalizationService().t('create')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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

