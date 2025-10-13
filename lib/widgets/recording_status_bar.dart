import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/recording_queue_service.dart';
import '../services/localization_service.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../models/folder.dart';
import '../screens/note_detail_screen.dart';
import 'custom_snackbar.dart';

class RecordingStatusBar extends StatefulWidget {
  const RecordingStatusBar({super.key});

  @override
  State<RecordingStatusBar> createState() => _RecordingStatusBarState();
}

class _RecordingStatusBarState extends State<RecordingStatusBar> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingQueueService>(
      builder: (context, queueService, child) {
        final queue = queueService.queue;
        
        // Don't show if queue is empty
        if (queue.isEmpty) {
          return const SizedBox.shrink();
        }

        final isProcessing = queueService.isProcessing;
        final completedCount = queueService.completedCount;
        final errorCount = queueService.errorCount;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Collapsed header - always visible
              _buildCollapsedHeader(
                context,
                isProcessing,
                completedCount,
                errorCount,
                queue.length,
              ),
              
              // Expanded content
              if (_isExpanded)
                _buildExpandedContent(context, queue, queueService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollapsedHeader(
    BuildContext context,
    bool isProcessing,
    int completedCount,
    int errorCount,
    int totalCount,
  ) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isProcessing) {
      statusText = 'Processing $totalCount notes...';
      statusIcon = Icons.sync;
      statusColor = Theme.of(context).primaryColor;
    } else if (errorCount > 0) {
      statusText = '$errorCount error${errorCount > 1 ? 's' : ''}, $completedCount saved';
      statusIcon = Icons.error_outline;
      statusColor = Colors.orange;
    } else {
      statusText = '$completedCount note${completedCount > 1 ? 's' : ''} saved';
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green;
    }

    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status icon with breathing animation if processing
            if (isProcessing)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 0.1),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 20,
                    ),
                  );
                },
                onEnd: () {
                  if (mounted && isProcessing) {
                    setState(() {});
                  }
                },
              )
            else
              Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    List<RecordingQueueItem> queue,
    RecordingQueueService queueService,
  ) {
    return SizeTransition(
      sizeFactor: _animation,
      child: Column(
        children: [
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: queue.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = queue[index];
              return _buildQueueItem(context, item, queueService);
            },
          ),
          if (queueService.completedCount > 0 || queueService.errorCount > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () {
                  queueService.clearCompleted();
                },
                child: Text(LocalizationService().t('dismiss_all')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(
    BuildContext context,
    RecordingQueueItem item,
    RecordingQueueService queueService,
  ) {
    IconData icon;
    Color iconColor;
    String statusText;
    Widget trailing;

    switch (item.status) {
      case RecordingStatus.transcribing:
        icon = Icons.mic;
        iconColor = Theme.of(context).primaryColor;
        statusText = 'Transcribing...';
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        );
        break;
      case RecordingStatus.organizing:
        icon = Icons.folder_outlined;
        iconColor = Colors.orange;
        statusText = 'Organizing...';
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
        break;
      case RecordingStatus.complete:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        statusText = item.folderName != null
            ? '📁 ${item.folderName}'
            : 'Saved';
        trailing = PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'move',
              child: Text(LocalizationService().t('move_to_folder')),
            ),
            PopupMenuItem(
              value: 'view',
              child: Text(LocalizationService().t('view_note')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(LocalizationService().t('delete')),
            ),
          ],
          onSelected: (value) async {
            if (value == 'delete') {
              queueService.removeRecording(item.id);
            } else if (value == 'move' && item.noteId != null) {
              await _showFolderMoveDialog(context, item);
            } else if (value == 'view' && item.noteId != null) {
              await _navigateToNote(context, item.noteId!);
            }
          },
        );
        break;
      case RecordingStatus.error:
        icon = Icons.error;
        iconColor = Colors.red;
        statusText = item.errorMessage ?? 'Error';
        trailing = IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () {
            queueService.removeRecording(item.id);
          },
        );
        break;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        queueService.removeRecording(item.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.transcription != null && item.transcription!.isNotEmpty
                        ? item.transcription!.length > 50
                            ? '${item.transcription!.substring(0, 50)}...'
                            : item.transcription!
                        : 'Note ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  /// Show folder picker dialog and move note to selected folder
  Future<void> _showFolderMoveDialog(BuildContext context, RecordingQueueItem item) async {
    if (item.noteId == null) return;

    final foldersProvider = context.read<FoldersProvider>();
    final notesProvider = context.read<NotesProvider>();

    // Include unorganized folder in the list
    final allFolders = [
      if (foldersProvider.unorganizedFolder != null) foldersProvider.unorganizedFolder!,
      ...foldersProvider.userFolders,
    ];

    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (context) => _FolderPickerDialog(
        folders: allFolders,
        currentFolderId: item.assignedFolderId,
        unorganizedFolderId: foldersProvider.unorganizedFolderId,
      ),
    );

    if (selectedFolderId != null && context.mounted) {
      // Move the note to the selected folder
      await notesProvider.moveNoteToFolder(item.noteId!, selectedFolderId);
      
      // Update the recording item to reflect the new folder
      final folder = foldersProvider.getFolderById(selectedFolderId);
      if (folder != null) {
        final queueService = context.read<RecordingQueueService>();
        queueService.updateRecording(
          item.id,
          assignedFolderId: selectedFolderId,
          folderName: folder.name,
        );
      }

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

  /// Navigate to note detail screen
  Future<void> _navigateToNote(BuildContext context, String noteId) async {
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteDetailScreen(noteId: noteId),
        ),
      );
    }
  }
}

/// Simple folder picker dialog for moving notes
class _FolderPickerDialog extends StatefulWidget {
  final List<Folder> folders;
  final String? currentFolderId;
  final String? unorganizedFolderId;

  const _FolderPickerDialog({
    required this.folders,
    this.currentFolderId,
    this.unorganizedFolderId,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xEE1A1F2E), // 93% opacity dark blue-grey - consistent with other modals
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
                Text(
                  LocalizationService().t('move_to_folder'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                
                // Show count info
                if (_searchQuery.isEmpty && _filteredFolders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Top ${_filteredFolders.length} Ordner nach Anzahl',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
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
                            child: Text(LocalizationService().t('no_folders_found')),
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
                                      child: Text(
                                        LocalizationService().t('default'),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${folder.noteCount} ${folder.noteCount == 1 ? 'Notiz' : 'Notizen'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              selected: isSelected,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () {
                                Navigator.of(context).pop(folder.id);
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
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

