import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder.dart';
import '../providers/folders_provider.dart';
import '../providers/notes_provider.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'create_folder_dialog.dart';

class FolderManagementDialog extends StatefulWidget {
  const FolderManagementDialog({super.key});

  @override
  State<FolderManagementDialog> createState() => _FolderManagementDialogState();
}

class _FolderManagementDialogState extends State<FolderManagementDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
            child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.folder_open),
                  const SizedBox(width: 12),
                  const Text(
                    'Manage Folders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
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
            ),

            // Folders list
            Expanded(
              child: Consumer<FoldersProvider>(
                builder: (context, foldersProvider, child) {
                  final allFolders = foldersProvider.userFolders;
                  
                  // Filter folders based on search query
                  final folders = _searchQuery.isEmpty
                      ? allFolders
                      : allFolders.where((folder) {
                          return folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
                        }).toList();

                  if (folders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_off_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'Keine Ordner gefunden' : 'No folders yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'Versuchen Sie eine andere Suche'
                                : 'Create your first folder to organize notes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: folders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return _FolderListItem(folder: folder);
                    },
                  );
                },
              ),
            ),

            // Create button
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    HapticService.light();
                    final result = await showDialog<Map<String, String?>>(
                      context: context,
                      builder: (context) => const CreateFolderDialog(),
                    );

                    if (result != null && context.mounted) {
                      HapticService.success();
                      final foldersProvider = context.read<FoldersProvider>();
                      await foldersProvider.createFolder(
                        name: result['name']!,
                        icon: result['icon']!,
                        colorHex: result['colorHex'],
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(LocalizationService().t('create_folder')),
                ),
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

class _FolderListItem extends StatefulWidget {
  final Folder folder;

  const _FolderListItem({required this.folder});

  @override
  State<_FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<_FolderListItem> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.folder.colorHex != null
        ? Color(int.parse(widget.folder.colorHex!, radix: 16))
        : null;

    return Card(
      elevation: 0,
      color: color?.withOpacity(0.1) ?? Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: color?.withOpacity(0.3) ?? Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Text(
          widget.folder.icon,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(
          widget.folder.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${widget.folder.noteCount} note${widget.folder.noteCount == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            // Prevent double-execution
            if (_isProcessing) {
              debugPrint('⚠️ Already processing action, ignoring duplicate');
              return;
            }

            setState(() {
              _isProcessing = true;
            });

            try {
              final foldersProvider = context.read<FoldersProvider>();
              
              if (value == 'rename') {
                HapticService.light();
                final result = await _showRenameDialog(context, widget.folder);
                if (result != null && context.mounted) {
                  HapticService.success();
                  await foldersProvider.updateFolder(
                    widget.folder.copyWith(name: result),
                  );
                }
              } else if (value == 'delete') {
                HapticService.light();
                final confirmed = await _showDeleteConfirmation(context, widget.folder);
                if (confirmed == true && context.mounted) {
                  HapticService.success();
                  // Move notes to unorganized folder before deleting
                  final notesProvider = context.read<NotesProvider>();
                  final unorganizedFolderId = foldersProvider.unorganizedFolderId;
                  if (unorganizedFolderId != null) {
                    await notesProvider.moveNotesToUnorganized(widget.folder.id, unorganizedFolderId);
                  }
                  await foldersProvider.deleteFolder(widget.folder.id);
                }
              } else if (value == 'changeColor') {
                HapticService.light();
                final newColor = await _showColorPicker(context, widget.folder);
                if (newColor != null && context.mounted) {
                  HapticService.success();
                  await foldersProvider.updateFolder(
                    widget.folder.copyWith(
                      colorHex: newColor.value.toRadixString(16).padLeft(8, '0'),
                    ),
                  );
                }
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                });
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 12),
                  Text(LocalizationService().t('rename')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'changeColor',
              child: Row(
                children: [
                  const Icon(Icons.color_lens, size: 20),
                  const SizedBox(width: 12),
                  Text(LocalizationService().t('change_color')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 12),
                  Text(LocalizationService().t('delete'), style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showRenameDialog(BuildContext context, Folder folder) {
    final controller = TextEditingController(text: folder.name);
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(
                  color: AppTheme.glassBorder.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rename Folder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Folder Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.of(context).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(LocalizationService().t('cancel')),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            Navigator.of(context).pop(name);
                          }
                        },
                        child: Text(LocalizationService().t('rename')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, Folder folder) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(
                  color: AppTheme.glassBorder.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delete Folder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to delete "${folder.name}"?\n\nNotes in this folder will be moved to Unorganized.',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(LocalizationService().t('cancel')),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text(LocalizationService().t('delete')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Color?> _showColorPicker(BuildContext context, Folder folder) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return showDialog<Color>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(
                  color: AppTheme.glassBorder.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Color',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // None option
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop(null);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ),
                      // Color options
                      ...colors.map((color) => InkWell(
                        onTap: () {
                          Navigator.of(context).pop(color);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(LocalizationService().t('cancel')),
                      ),
                    ],
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

