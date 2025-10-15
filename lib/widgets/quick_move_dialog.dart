import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../providers/folders_provider.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'create_folder_dialog.dart';

/// Quick dialog to move a note to a different folder
class QuickMoveDialog extends StatefulWidget {
  final List<Folder> folders;
  final String? currentFolderId;
  final String noteIcon;
  final String noteName;
  final String? unorganizedFolderId;

  const QuickMoveDialog({
    super.key,
    required this.folders,
    required this.currentFolderId,
    required this.noteIcon,
    required this.noteName,
    this.unorganizedFolderId,
  });

  @override
  State<QuickMoveDialog> createState() => _QuickMoveDialogState();
  
  /// Show the dialog and return the selected folder ID
  static Future<String?> show({
    required BuildContext context,
    required List<Folder> folders,
    required String? currentFolderId,
    required String noteIcon,
    required String noteName,
    String? unorganizedFolderId,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => QuickMoveDialog(
        folders: folders,
        currentFolderId: currentFolderId,
        noteIcon: noteIcon,
        noteName: noteName,
        unorganizedFolderId: unorganizedFolderId,
      ),
    );
  }
}

class _QuickMoveDialogState extends State<QuickMoveDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<Folder> get _filteredFolders {
    if (_searchQuery.isEmpty) {
      // Sort folders alphabetically
      final sorted = List<Folder>.from(widget.folders)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return sorted.take(7).toList();
    }
    
    // Search in all folders
    final query = _searchQuery.toLowerCase();
    return widget.folders.where((folder) {
      return folder.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              border: Border.all(
                color: AppTheme.glassBorder.withOpacity(0.3),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(widget.noteIcon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move Note',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.noteName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            
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
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
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
            
            // Show count info
            if (_searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Top ${_filteredFolders.length} Ordner nach Anzahl',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),

            // Create New Folder Button
            InkWell(
              onTap: () async {
                await HapticService.light();
                if (!context.mounted) return;
                
                final result = await showDialog<Map<String, String?>>(
                  context: context,
                  builder: (context) => const CreateFolderDialog(),
                );
                
                if (result != null) {
                  if (!context.mounted) return;
                  
                  // Create the folder using FoldersProvider
                  final foldersProvider = context.read<FoldersProvider>();
                  final newFolder = await foldersProvider.createFolder(
                    name: result['name']!,
                    icon: result['icon']!,
                    colorHex: result['colorHex'],
                  );
                  
                  if (!context.mounted) return;
                  // Automatically select the newly created folder
                  Navigator.of(context).pop(newFolder.id);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.glassSurface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.glassBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.create_new_folder,
                      size: 24,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      LocalizationService().t('create_new_folder'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Folder list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: _filteredFolders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Keine Ordner gefunden',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredFolders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final folder = _filteredFolders[index];
                  final isSelected = folder.id == widget.currentFolderId;
                  final isUnorganized = folder.id == widget.unorganizedFolderId;
                  
                  return ListTile(
                    leading: Text(folder.icon, style: const TextStyle(fontSize: 24)),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            folder.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnorganized) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      folder.noteCount == 1 
                          ? LocalizationService().t('note_count_single')
                          : LocalizationService().t('note_count_plural', {'count': folder.noteCount.toString()}),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      HapticService.light();
                      Navigator.of(context).pop(folder.id);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(LocalizationService().t('cancel')),
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

