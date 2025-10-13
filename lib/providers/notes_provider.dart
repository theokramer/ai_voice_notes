import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../utils/markdown_to_delta_converter.dart';
import 'folders_provider.dart';

enum SortOption {
  recentlyUpdated,
  recentlyAccessed,
  alphabetical,
  dateCreated,
}

enum SortDirection {
  ascending,
  descending,
}

enum NoteViewType {
  minimalisticList,
  grid,
  standard,
}

class NotesProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<Note> _notes = [];
  bool _isLoading = false;
  Note? _deletedNote;
  SortOption _sortOption = SortOption.recentlyUpdated;
  SortDirection _sortDirection = SortDirection.descending;
  NoteViewType _noteViewType = NoteViewType.grid;
  String _searchQuery = '';
  
  // AI processing state tracking
  final Map<String, bool> _aiProcessingStates = {};
  
  // Performance optimizations
  List<Note>? _cachedFilteredNotes;
  String? _lastSearchQuery;
  SortOption? _lastSortOption;
  SortDirection? _lastSortDirection;
  NoteViewType? _lastNoteViewType;
  Timer? _searchDebounceTimer;

  List<Note> get notes {
    // Return cached results if nothing changed
    if (_cachedFilteredNotes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSortOption == _sortOption &&
        _lastSortDirection == _sortDirection &&
        _lastNoteViewType == _noteViewType) {
      return _cachedFilteredNotes!;
    }
    
    // Compute and cache new results
    _cachedFilteredNotes = _getFilteredAndSortedNotes();
    _lastSearchQuery = _searchQuery;
    _lastSortOption = _sortOption;
    _lastSortDirection = _sortDirection;
    _lastNoteViewType = _noteViewType;
    return _cachedFilteredNotes!;
  }
  
  List<Note> get allNotes => _notes;
  bool get isLoading => _isLoading;
  SortOption get sortOption => _sortOption;
  SortDirection get sortDirection => _sortDirection;
  NoteViewType get noteViewType => _noteViewType;
  String get searchQuery => _searchQuery;
  
  /// Check if AI is processing for a specific note
  bool isAIProcessing(String noteId) => _aiProcessingStates[noteId] ?? false;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    _notes = await _storageService.loadNotes();
    
    // Migrate markdown notes to Quill Delta format
    bool needsMigration = false;
    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      
      // Check if content looks like markdown (not JSON)
      // JSON starts with '[' or '{', markdown typically has text or '#'
      if (note.content.isNotEmpty && 
          !note.content.trim().startsWith('[') && 
          !note.content.trim().startsWith('{')) {
        try {
          // Try to parse as JSON first to be sure
          jsonDecode(note.content);
        } catch (e) {
          // Not valid JSON, so it's markdown - convert it
          debugPrint('Migrating note ${note.id} from markdown to Quill format');
          final delta = MarkdownToDeltaConverter.convert(note.content);
          _notes[i] = note.copyWith(
            content: jsonEncode(delta.toJson()),
          );
          needsMigration = true;
        }
      }
    }
    
    if (needsMigration) {
      debugPrint('Saving migrated notes...');
      await _storageService.saveNotes(_notes);
    }
    
    // Load saved view type preference
    try {
      final savedViewType = await _storageService.loadViewType();
      if (savedViewType != null) {
        _noteViewType = NoteViewType.values.firstWhere(
          (e) => e.name == savedViewType,
          orElse: () => NoteViewType.grid,
        );
      }
    } catch (e) {
      debugPrint('Error loading view type: $e');
    }

    // Load saved sort preferences
    try {
      final savedSortOption = await _storageService.loadSortOption();
      if (savedSortOption != null) {
        _sortOption = SortOption.values.firstWhere(
          (e) => e.name == savedSortOption,
          orElse: () => SortOption.recentlyUpdated,
        );
      }
      
      final savedSortDirection = await _storageService.loadSortDirection();
      if (savedSortDirection != null) {
        _sortDirection = SortDirection.values.firstWhere(
          (e) => e.name == savedSortDirection,
          orElse: () => SortDirection.descending,
        );
      }
    } catch (e) {
      debugPrint('Error loading sort preferences: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
  
  /// Migrate notes with null folderId or orphaned folder IDs to the unorganized folder
  /// This should be called after FoldersProvider is initialized
  /// Also migrates notes with folder IDs that no longer exist (orphaned)
  Future<void> migrateUnorganizedNotes(String unorganizedFolderId, {List<String>? validFolderIds}) async {
    bool needsMigration = false;
    int nullMigrated = 0;
    int orphanedMigrated = 0;
    
    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      
      // Migrate notes with null folderId
      if (note.folderId == null) {
        debugPrint('Migrating note ${note.id} (null folderId) to unorganized folder');
        _notes[i] = note.copyWith(folderId: unorganizedFolderId);
        needsMigration = true;
        nullMigrated++;
      }
      // Migrate notes with orphaned folder IDs (folder no longer exists)
      else if (validFolderIds != null && 
               note.folderId != unorganizedFolderId && 
               !validFolderIds.contains(note.folderId)) {
        debugPrint('Migrating note ${note.id} (orphaned folderId: ${note.folderId}) to unorganized folder');
        _notes[i] = note.copyWith(folderId: unorganizedFolderId);
        needsMigration = true;
        orphanedMigrated++;
      }
    }
    
    if (needsMigration) {
      if (nullMigrated > 0) {
        debugPrint('✅ Migrated $nullMigrated notes with null folderId to unorganized folder');
      }
      if (orphanedMigrated > 0) {
        debugPrint('✅ Migrated $orphanedMigrated notes with orphaned folderId to unorganized folder');
      }
      await _storageService.saveNotes(_notes);
      _invalidateCache(); // Clear cache to refresh views
      notifyListeners();
    }
  }
  
  void _invalidateCache() {
    _cachedFilteredNotes = null;
    _lastSearchQuery = null;
    _lastSortOption = null;
    _lastSortDirection = null;
  }

  // NEW: Add note with folder context support
  Future<void> addNote(Note note, {String? folderContext, FoldersProvider? foldersProvider}) async {
    // If folderContext provided, use it
    final noteToAdd = folderContext != null 
        ? note.copyWith(folderId: folderContext)
        : note;
    
    // Optimistic update - update UI immediately
    _notes.insert(0, noteToAdd);
    _invalidateCache();
    notifyListeners();
    
    // Update folder count if foldersProvider is provided
    if (foldersProvider != null && noteToAdd.folderId != null) {
      foldersProvider.incrementNoteCount(noteToAdd.folderId!);
    }
    
    // Save to storage in background (fire-and-forget)
    _storageService.saveNotes(_notes).catchError((e) {
      debugPrint('Error saving notes: $e');
    });
  }

  Note? getNoteById(String noteId) {
    try {
      return _notes.firstWhere((n) => n.id == noteId);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateNote(Note note, {bool notify = true}) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      // Optimistic update - update UI immediately
      _notes[index] = note.copyWith(updatedAt: DateTime.now());
      _invalidateCache();
      if (notify) {
        notifyListeners();
      }
      
      // Save to storage in background (fire-and-forget)
      _storageService.saveNotes(_notes).catchError((e) {
        debugPrint('Error saving notes: $e');
      });
    }
  }

  Future<void> deleteNote(String noteId, {FoldersProvider? foldersProvider}) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      // Optimistic update - update UI immediately
      _deletedNote = _notes[noteIndex];
      final deletedFolderId = _deletedNote!.folderId;
      _notes.removeAt(noteIndex);
      _invalidateCache();
      notifyListeners();
      
      // Update folder count if foldersProvider is provided
      if (foldersProvider != null && deletedFolderId != null) {
        foldersProvider.decrementNoteCount(deletedFolderId);
      }
      
      // Save to storage in background (fire-and-forget)
      _storageService.saveNotes(_notes).catchError((e) {
        debugPrint('Error saving notes: $e');
      });
    }
  }

  Future<void> undoDelete({FoldersProvider? foldersProvider}) async {
    if (_deletedNote != null) {
      // Optimistic update - update UI immediately
      final restoredNote = _deletedNote!;
      _notes.insert(0, restoredNote);
      _deletedNote = null;
      _invalidateCache();
      notifyListeners();
      
      // Update folder count if foldersProvider is provided
      if (foldersProvider != null && restoredNote.folderId != null) {
        foldersProvider.incrementNoteCount(restoredNote.folderId!);
      }
      
      // Save to storage in background (fire-and-forget)
      _storageService.saveNotes(_notes).catchError((e) {
        debugPrint('Error saving notes: $e');
      });
    }
  }

  Future<void> deleteAllNotes() async {
    // Optimistic update - update UI immediately
    _notes.clear();
    _deletedNote = null;
    _invalidateCache();
    notifyListeners();
    
    // Save to storage in background (fire-and-forget)
    _storageService.saveNotes(_notes).catchError((e) {
      debugPrint('Error saving notes: $e');
    });
  }

  void markNoteAsAccessed(String noteId) {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        lastAccessedAt: DateTime.now(),
      );
      
      // Save to storage in background (fire-and-forget)
      _storageService.saveNotes(_notes).catchError((e) {
        debugPrint('Error saving notes: $e');
      });
      
      // Don't invalidate cache or notify for access tracking (performance)
      // Only invalidate if sort is by recently accessed
      if (_sortOption == SortOption.recentlyAccessed) {
        _invalidateCache();
        notifyListeners();
      }
    }
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _invalidateCache();
    notifyListeners();
    
    // Persist sort option preference (fire-and-forget)
    _storageService.saveSortOption(option.name).catchError((e) {
      debugPrint('Error saving sort option: $e');
    });
  }

  void setSortDirection(SortDirection direction) {
    _sortDirection = direction;
    _invalidateCache();
    notifyListeners();
    
    // Persist sort direction preference (fire-and-forget)
    _storageService.saveSortDirection(direction.name).catchError((e) {
      debugPrint('Error saving sort direction: $e');
    });
  }

  void setSorting(SortOption option, SortDirection direction) {
    _sortOption = option;
    _sortDirection = direction;
    _invalidateCache();
    notifyListeners();
    
    // Persist both sort preferences (fire-and-forget)
    _storageService.saveSortOption(option.name).catchError((e) {
      debugPrint('Error saving sort option: $e');
    });
    _storageService.saveSortDirection(direction.name).catchError((e) {
      debugPrint('Error saving sort direction: $e');
    });
  }

  void setNoteViewType(NoteViewType type) {
    _noteViewType = type;
    _invalidateCache();
    notifyListeners();
    
    // Persist view type preference (fire-and-forget)
    _storageService.saveViewType(type.name).catchError((e) {
      debugPrint('Error saving view type: $e');
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    
    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();
    
    // Debounce search for better performance (300ms delay)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _invalidateCache();
      notifyListeners();
    });
  }

  List<Note> _getFilteredAndSortedNotes() {
    // Start with the original list
    List<Note> filtered;
    
    // Apply search filter - simplified for content field
    if (_searchQuery.isNotEmpty && _searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = [];
      
      // Check if this is a tag-only search (starts with #)
      final isTagSearch = query.startsWith('#');
      final searchTerm = isTagSearch ? query.substring(1) : query;
      
      // If tag-only search, skip (tags removed)
      if (isTagSearch && searchTerm.isNotEmpty) {
        // Tags feature removed - no results for tag searches
      } else {
        // Normal search: name and content
        for (final note in _notes) {
          // Quick check: name match (most common)
          if (note.name.toLowerCase().contains(query)) {
            filtered.add(note);
            continue;
          }
          
          // Check content
          if (note.content.toLowerCase().contains(query)) {
                filtered.add(note);
          }
        }
      }
    } else {
      // No search query - use shallow copy only
      filtered = _notes;
    }

    // Apply sorting - only create new list if we need to sort
    if (filtered.isEmpty) {
      return filtered;
    }
    
    // Create a mutable copy only if we're filtering or need to sort
    if (filtered == _notes) {
      filtered = List<Note>.from(_notes);
    }
    
    switch (_sortOption) {
      case SortOption.recentlyUpdated:
        filtered.sort((a, b) {
          // Pinned notes always come first
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          final comparison = b.updatedAt.compareTo(a.updatedAt);
          return _sortDirection == SortDirection.descending ? comparison : -comparison;
        });
        break;
      case SortOption.recentlyAccessed:
        filtered.sort((a, b) {
          // Pinned notes always come first
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          final aTime = a.lastAccessedAt ?? a.createdAt;
          final bTime = b.lastAccessedAt ?? b.createdAt;
          final comparison = bTime.compareTo(aTime);
          return _sortDirection == SortDirection.descending ? comparison : -comparison;
        });
        break;
      case SortOption.alphabetical:
        filtered.sort((a, b) {
          // Pinned notes always come first
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          final comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return _sortDirection == SortDirection.descending ? -comparison : comparison;
        });
        break;
      case SortOption.dateCreated:
        filtered.sort((a, b) {
          // Pinned notes always come first
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          final comparison = b.createdAt.compareTo(a.createdAt);
          return _sortDirection == SortDirection.descending ? comparison : -comparison;
        });
        break;
    }

    return filtered;
  }

  /// Group notes by time period for minimalistic view
  Map<String, List<Note>> groupNotesByTimePeriod(List<Note> notes) {
    // Use current phone's local time
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    
    final Map<String, List<Note>> grouped = {
      'Today': [],
      'This Week': [],
      'More': [],
    };
    
    for (final note in notes) {
      final accessTime = note.lastAccessedAt ?? note.createdAt;
      // Normalize to start of day for comparison
      final accessDate = DateTime(accessTime.year, accessTime.month, accessTime.day);
      
      // Check if note was accessed today (same calendar day)
      if (accessDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(note);
      }
      // Check if note was accessed in the last 7 days (but not today)
      else if (accessDate.isBefore(today) && (accessDate.isAfter(weekAgo) || accessDate.isAtSameMomentAs(weekAgo))) {
        grouped['This Week']!.add(note);
      }
      // Everything else (older than 7 days or future dates)
      else {
        grouped['More']!.add(note);
      }
    }
    
    return grouped;
  }

  Future<void> toggleNotePin(String noteId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedNote = note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  // Folder-related methods
  
  /// Get all notes in a specific folder
  /// Also includes notes with null folderId when querying for the unorganized folder
  /// Pinned notes are always shown at the top
  List<Note> getNotesInFolder(String? folderId) {
    final filtered = _notes.where((note) {
      // Include notes with null folderId when querying for unorganized folder
      if (note.folderId == null) {
        return folderId == null;
      }
      return note.folderId == folderId;
    }).toList();
    
    // Sort to show pinned notes first, then by updated date
    filtered.sort((a, b) {
      // Pinned notes always come first
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // Then sort by most recently updated
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    return filtered;
  }

  /// Move a note to a different folder
  Future<void> moveNoteToFolder(String noteId, String? folderId, {FoldersProvider? foldersProvider}) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final oldFolderId = note.folderId;
    
    final updatedNote = note.copyWith(
      folderId: folderId,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
    
    // Update folder counts if foldersProvider is provided
    if (foldersProvider != null) {
      if (oldFolderId != null) {
        foldersProvider.decrementNoteCount(oldFolderId);
      }
      if (folderId != null) {
        foldersProvider.incrementNoteCount(folderId);
      }
    }
  }

  /// Move all notes from a deleted folder to the unorganized folder
  Future<void> moveNotesToUnorganized(String deletedFolderId, String unorganizedFolderId) async {
    bool needsUpdate = false;
    
    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      if (note.folderId == deletedFolderId) {
        _notes[i] = note.copyWith(folderId: unorganizedFolderId);
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      debugPrint('✅ Moved notes from deleted folder to unorganized');
      await _storageService.saveNotes(_notes);
      _invalidateCache();
      notifyListeners();
    }
  }
}
