import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// Dropdown selector for choosing which folder to view
class FolderSelector extends StatelessWidget {
  final String? selectedFolderId; // null = "All Notes"
  final List<Folder> folders;
  final Folder unorganizedFolder;
  final Function(String? folderId) onFolderSelected;
  final VoidCallback onManageFolders;

  const FolderSelector({
    super.key,
    required this.selectedFolderId,
    required this.folders,
    required this.unorganizedFolder,
    required this.onFolderSelected,
    required this.onManageFolders,
  });

  String get _selectedFolderName {
    if (selectedFolderId == null) {
      return 'All Notes';
    }
    
    final folder = folders.firstWhere(
      (f) => f.id == selectedFolderId,
      orElse: () => unorganizedFolder,
    );
    
    return folder.name;
  }

  String get _selectedFolderIcon {
    if (selectedFolderId == null) {
      return '📚';
    }
    
    final folder = folders.firstWhere(
      (f) => f.id == selectedFolderId,
      orElse: () => unorganizedFolder,
    );
    
    return folder.icon;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFolderMenu(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(_selectedFolderIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFolderName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).iconTheme.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu(BuildContext context) async {
    HapticService.light();
    
    final result = await showModalBottomSheet<_FolderMenuResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FolderMenuSheet(
        folders: folders,
        unorganizedFolder: unorganizedFolder,
        selectedFolderId: selectedFolderId,
      ),
    );

    if (result == null) return;

    if (result.isManageAction) {
      onManageFolders();
    } else {
      onFolderSelected(result.folderId);
    }
  }
}

class _FolderMenuResult {
  final String? folderId; // null = All Notes
  final bool isManageAction;

  _FolderMenuResult({this.folderId, this.isManageAction = false});
}

class _FolderMenuSheet extends StatefulWidget {
  final List<Folder> folders;
  final Folder unorganizedFolder;
  final String? selectedFolderId;

  const _FolderMenuSheet({
    required this.folders,
    required this.unorganizedFolder,
    required this.selectedFolderId,
  });

  @override
  State<_FolderMenuSheet> createState() => _FolderMenuSheetState();
}

class _FolderMenuSheetState extends State<_FolderMenuSheet> {
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Separate user-created folders from system folders
    final userFolders = widget.folders.where((f) => !f.isSystem).toList();
    
    // Filter folders based on search query
    final filteredFolders = _searchQuery.isEmpty
        ? userFolders
        : userFolders.where((f) => 
            f.name.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Select Folder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search folders...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const Divider(height: 1),

            // Folder list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Only show "All Notes" and "Unorganized" when not searching
                  if (_searchQuery.isEmpty) ...[
                    // All Notes
                    _FolderMenuItem(
                      icon: '📚',
                      name: 'All Notes',
                      isSelected: widget.selectedFolderId == null,
                      onTap: () {
                        Navigator.of(context).pop(_FolderMenuResult(folderId: null));
                      },
                    ),

                    // Unorganized
                    _FolderMenuItem(
                      icon: widget.unorganizedFolder.icon,
                      name: widget.unorganizedFolder.name,
                      noteCount: widget.unorganizedFolder.noteCount,
                      isSelected: widget.selectedFolderId == widget.unorganizedFolder.id,
                      onTap: () {
                        Navigator.of(context).pop(
                          _FolderMenuResult(folderId: widget.unorganizedFolder.id),
                        );
                      },
                    ),

                    const Divider(height: 1),
                  ],
                  
                  // User folders (filtered)
                  if (filteredFolders.isNotEmpty)
                    ...filteredFolders.map((folder) => _FolderMenuItem(
                      icon: folder.icon,
                      name: folder.name,
                      noteCount: folder.noteCount,
                      colorHex: folder.colorHex,
                      isSelected: widget.selectedFolderId == folder.id,
                      onTap: () {
                        Navigator.of(context).pop(
                          _FolderMenuResult(folderId: folder.id),
                        );
                      },
                    ))
                  else if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No folders found',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  if (_searchQuery.isEmpty) ...[
                    const Divider(height: 1),

                    // Manage folders
                    ListTile(
                      leading: const Icon(Icons.settings, size: 24),
                      title: const Text('Manage Folders'),
                      onTap: () {
                        Navigator.of(context).pop(
                          _FolderMenuResult(isManageAction: true),
                        );
                      },
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
    ),
    );
  }
}

class _FolderMenuItem extends StatelessWidget {
  final String icon;
  final String name;
  final int? noteCount;
  final String? colorHex;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderMenuItem({
    required this.icon,
    required this.name,
    this.noteCount,
    this.colorHex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 24)),
      title: Row(
        children: [
          Expanded(child: Text(name)),
          if (noteCount != null && noteCount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                noteCount.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      selected: isSelected,
      onTap: () {
        HapticService.light();
        onTap();
      },
    );
  }
}

