import 'package:flutter/foundation.dart';
import '../models/folder.dart';
import '../services/storage_service.dart';

class FoldersProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<Folder> _folders = [];
  bool _isLoading = false;
  String? _unorganizedFolderId;

  List<Folder> get folders => _folders;
  bool get isLoading => _isLoading;
  String? get unorganizedFolderId => _unorganizedFolderId;

  // Get the Unorganized folder
  Folder? get unorganizedFolder {
    if (_unorganizedFolderId == null) return null;
    try {
      return _folders.firstWhere((f) => f.id == _unorganizedFolderId);
    } catch (e) {
      return null;
    }
  }

  // Get all user-created folders (not system folders)
  List<Folder> get userFolders {
    return _folders.where((f) => !f.isSystem).toList();
  }

  // Initialize provider and create Unorganized folder if needed
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _folders = await _storageService.loadFolders();
    _unorganizedFolderId = await _storageService.getUnorganizedFolderId();

    // Clean up any duplicate Unorganized folders
    await _ensureSingleUnorganizedFolder();

    // Create Unorganized folder if it doesn't exist
    if (_unorganizedFolderId == null || unorganizedFolder == null) {
      await _createUnorganizedFolder();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Ensure there's only one Unorganized folder
  Future<void> _ensureSingleUnorganizedFolder() async {
    // Find all system folders
    final systemFolders = _folders.where((f) => f.isSystem).toList();
    
    if (systemFolders.length <= 1) {
      // No duplicates, we're good
      return;
    }
    
    debugPrint('⚠️ Found ${systemFolders.length} Unorganized folders, cleaning up...');
    
    // Keep the one that matches our stored ID, or the first one
    final Folder validFolder;
    if (_unorganizedFolderId != null) {
      validFolder = systemFolders.firstWhere(
        (f) => f.id == _unorganizedFolderId,
        orElse: () => systemFolders.first,
      );
    } else {
      validFolder = systemFolders.first;
    }
    
    // Remove all other system folders
    _folders.removeWhere((f) => f.isSystem && f.id != validFolder.id);
    
    // Update the stored ID
    _unorganizedFolderId = validFolder.id;
    
    // Ensure it has the correct icon
    if (validFolder.icon != '📋') {
      final index = _folders.indexWhere((f) => f.id == validFolder.id);
      if (index != -1) {
        _folders[index] = validFolder.copyWith(icon: '📋');
      }
    }
    
    // Save the cleaned up folders
    await _storageService.saveFolders(_folders);
    await _storageService.saveUnorganizedFolderId(_unorganizedFolderId!);
    
    debugPrint('✅ Cleaned up duplicate Unorganized folders');
  }

  // Create the system Unorganized folder
  Future<void> _createUnorganizedFolder() async {
    final now = DateTime.now();
    final folder = Folder(
      id: 'unorganized_${now.millisecondsSinceEpoch}',
      name: 'Unorganized',
      icon: '📋',
      isSystem: true,
      createdAt: now,
      updatedAt: now,
      noteCount: 0,
    );

    _folders.add(folder);
    _unorganizedFolderId = folder.id;

    await _storageService.saveFolders(_folders);
    await _storageService.saveUnorganizedFolderId(folder.id);
  }

  // Create a new folder
  Future<Folder> createFolder({
    required String name,
    required String icon,
    String? colorHex,
    bool aiCreated = false,
  }) async {
    final now = DateTime.now();
    final folder = Folder(
      id: 'folder_${now.millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      colorHex: colorHex,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
      aiCreated: aiCreated,
      noteCount: 0,
    );

    _folders.add(folder);
    notifyListeners();

    // Save in background
    _storageService.saveFolders(_folders).catchError((e) {
      debugPrint('Error saving folders: $e');
    });

    return folder;
  }

  // Update an existing folder
  Future<void> updateFolder(Folder folder) async {
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      _folders[index] = folder.copyWith(updatedAt: DateTime.now());
      notifyListeners();

      _storageService.saveFolders(_folders).catchError((e) {
        debugPrint('Error saving folders: $e');
      });
    }
  }

  // Delete a folder
  // Notes in this folder should be moved to Unorganized by NotesProvider
  Future<void> deleteFolder(String folderId) async {
    // Cannot delete system folders
    final folder = _folders.firstWhere((f) => f.id == folderId, orElse: () => throw Exception('Folder not found'));
    if (folder.isSystem) {
      throw Exception('Cannot delete system folders');
    }

    _folders.removeWhere((f) => f.id == folderId);
    notifyListeners();

    _storageService.saveFolders(_folders).catchError((e) {
      debugPrint('Error saving folders: $e');
    });
  }

  // Get folder by ID
  Folder? getFolderById(String folderId) {
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (e) {
      return null;
    }
  }

  // Get folder by name (case-insensitive)
  Folder? getFolderByName(String name) {
    try {
      return _folders.firstWhere(
        (f) => f.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Update note count for a folder
  void updateNoteCount(String folderId, int count) {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index].noteCount = count;
      notifyListeners();

      // Save in background
      _storageService.saveFolders(_folders).catchError((e) {
        debugPrint('Error saving folders: $e');
      });
    }
  }

  // Increment note count for a folder
  void incrementNoteCount(String folderId) {
    final folder = getFolderById(folderId);
    if (folder != null) {
      updateNoteCount(folderId, folder.noteCount + 1);
    }
  }

  // Decrement note count for a folder
  void decrementNoteCount(String folderId) {
    final folder = getFolderById(folderId);
    if (folder != null && folder.noteCount > 0) {
      updateNoteCount(folderId, folder.noteCount - 1);
    }
  }
}

