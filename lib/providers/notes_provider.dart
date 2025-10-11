import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/openai_service.dart';

enum SortOption {
  recentlyUpdated,
  recentlyAccessed,
  alphabetical,
  entryCount,
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
  String? _apiKey;
  OpenAIService? _openAIService;
  Note? _deletedNote;
  SortOption _sortOption = SortOption.recentlyUpdated;
  SortDirection _sortDirection = SortDirection.descending;
  NoteViewType _noteViewType = NoteViewType.standard;
  String _searchQuery = '';
  
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
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  SortOption get sortOption => _sortOption;
  SortDirection get sortDirection => _sortDirection;
  NoteViewType get noteViewType => _noteViewType;
  String get searchQuery => _searchQuery;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Load API key from .env file and pre-initialize service
    _apiKey = dotenv.env['OPENAI_API_KEY'];
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _openAIService = OpenAIService(apiKey: _apiKey!);
    }
    
    _notes = await _storageService.loadNotes();
    
    // Load saved view type preference
    try {
      final savedViewType = await _storageService.loadViewType();
      if (savedViewType != null) {
        _noteViewType = NoteViewType.values.firstWhere(
          (e) => e.name == savedViewType,
          orElse: () => NoteViewType.standard,
        );
      }
    } catch (e) {
      debugPrint('Error loading view type: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
  
  void _invalidateCache() {
    _cachedFilteredNotes = null;
    _lastSearchQuery = null;
    _lastSortOption = null;
    _lastSortDirection = null;
  }

  Future<void> addNote(Note note) async {
    // Optimistic update - update UI immediately
    _notes.insert(0, note);
    _invalidateCache();
    notifyListeners();
    
    // Save to storage in background (fire-and-forget)
    _storageService.saveNotes(_notes).catchError((e) {
      debugPrint('Error saving notes: $e');
    });
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

  Future<void> deleteNote(String noteId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex != -1) {
      // Optimistic update - update UI immediately
      _deletedNote = _notes[noteIndex];
      _notes.removeAt(noteIndex);
      _invalidateCache();
      notifyListeners();
      
      // Save to storage in background (fire-and-forget)
      _storageService.saveNotes(_notes).catchError((e) {
        debugPrint('Error saving notes: $e');
      });
    }
  }

  Future<void> undoDelete() async {
    if (_deletedNote != null) {
      // Optimistic update - update UI immediately
      _notes.insert(0, _deletedNote!);
      _deletedNote = null;
      _invalidateCache();
      notifyListeners();
      
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
  }

  void setSortDirection(SortDirection direction) {
    _sortDirection = direction;
    _invalidateCache();
    notifyListeners();
  }

  void setSorting(SortOption option, SortDirection direction) {
    _sortOption = option;
    _sortDirection = direction;
    _invalidateCache();
    notifyListeners();
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
    
    // Apply search filter with optimizations
    if (_searchQuery.isNotEmpty && _searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = [];
      
      // Optimized search with early exit
      for (final note in _notes) {
        // Quick check: name match (most common)
        if (note.name.toLowerCase().contains(query)) {
          filtered.add(note);
          continue; // Early exit - no need to check further
        }
        
        // Check tags (less common, smaller list)
        bool found = false;
        for (final tag in note.tags) {
          if (tag.toLowerCase().contains(query)) {
            filtered.add(note);
            found = true;
            break; // Early exit from tag loop
          }
        }
        if (found) continue;
        
        // Check content (most expensive, check last)
        for (final headline in note.headlines) {
          if (headline.title.toLowerCase().contains(query)) {
            filtered.add(note);
            found = true;
            break; // Early exit from headline loop
          }
          
          for (final entry in headline.entries) {
            if (entry.text.toLowerCase().contains(query)) {
              filtered.add(note);
              found = true;
              break; // Early exit from entry loop
            }
          }
          if (found) break;
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
      case SortOption.entryCount:
        filtered.sort((a, b) {
          // Pinned notes always come first
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          final aCount = a.headlines.fold<int>(0, (sum, h) => sum + h.entries.length);
          final bCount = b.headlines.fold<int>(0, (sum, h) => sum + h.entries.length);
          final comparison = bCount.compareTo(aCount);
          return _sortDirection == SortDirection.descending ? comparison : -comparison;
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
      final accessDate = DateTime(accessTime.year, accessTime.month, accessTime.day);
      
      if (accessDate.isAtSameMomentAs(today) || accessDate.isAfter(today)) {
        grouped['Today']!.add(note);
      } else if (accessDate.isAfter(weekAgo) || accessDate.isAtSameMomentAs(weekAgo)) {
        grouped['This Week']!.add(note);
      } else {
        grouped['More']!.add(note);
      }
    }
    
    return grouped;
  }

  Future<void> deleteEntry(String noteId, String headlineId, String entryId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == headlineId) {
        final updatedEntries = headline.entries.where((e) => e.id != entryId).toList();
        return headline.copyWith(entries: updatedEntries);
      }
      return headline;
    }).where((headline) => headline.entries.isNotEmpty).toList();

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  Future<void> updateEntry(String noteId, String headlineId, String entryId, String newText) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == headlineId) {
        final updatedEntries = headline.entries.map((entry) {
          if (entry.id == entryId) {
            return TextEntry(
              id: entry.id,
              text: newText,
              createdAt: entry.createdAt,
            );
          }
          return entry;
        }).toList();
        return headline.copyWith(entries: updatedEntries);
      }
      return headline;
    }).toList();

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
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

  Future<void> toggleHeadlinePin(String noteId, String headlineId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == headlineId) {
        return headline.copyWith(isPinned: !headline.isPinned);
      }
      return headline;
    }).toList();

    // Sort headlines: pinned first, then unpinned
    updatedHeadlines.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  Future<void> updateHeadlineTitle(String noteId, String headlineId, String newTitle) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == headlineId) {
        return headline.copyWith(title: newTitle);
      }
      return headline;
    }).toList();

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  Future<void> deleteHeadline(String noteId, String headlineId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.where((h) => h.id != headlineId).toList();

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  Future<void> duplicateEntry(String noteId, String headlineId, String entryId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == headlineId) {
        final entryIndex = headline.entries.indexWhere((e) => e.id == entryId);
        if (entryIndex != -1) {
          final originalEntry = headline.entries[entryIndex];
          final duplicatedEntry = TextEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: originalEntry.text,
            createdAt: DateTime.now(),
          );
          final updatedEntries = List<TextEntry>.from(headline.entries);
          updatedEntries.insert(entryIndex + 1, duplicatedEntry);
          return headline.copyWith(entries: updatedEntries);
        }
      }
      return headline;
    }).toList();

    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote);
  }

  Future<void> moveEntry(String noteId, String fromHeadlineId, String toHeadlineId, String entryId) async {
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = _notes[noteIndex];
    TextEntry? entryToMove;
    
    final updatedHeadlines = note.headlines.map((headline) {
      if (headline.id == fromHeadlineId) {
        final entry = headline.entries.firstWhere((e) => e.id == entryId);
        entryToMove = entry;
        final updatedEntries = headline.entries.where((e) => e.id != entryId).toList();
        return headline.copyWith(entries: updatedEntries);
      }
      return headline;
    }).where((headline) => headline.entries.isNotEmpty || headline.id == toHeadlineId).toList();

    if (entryToMove != null) {
      final finalHeadlines = updatedHeadlines.map((headline) {
        if (headline.id == toHeadlineId) {
          return headline.copyWith(entries: [...headline.entries, entryToMove!]);
        }
        return headline;
      }).toList();

      final updatedNote = note.copyWith(
        headlines: finalHeadlines,
        updatedAt: DateTime.now(),
      );

      await updateNote(updatedNote);
    }
  }

  /// Move entry between different notes
  Future<void> moveEntryBetweenNotes(
    String sourceNoteId,
    String sourceHeadlineId,
    String entryId,
    String destNoteId,
    String destHeadlineId,
  ) async {
    final sourceNoteIndex = _notes.indexWhere((n) => n.id == sourceNoteId);
    final destNoteIndex = _notes.indexWhere((n) => n.id == destNoteId);
    
    if (sourceNoteIndex == -1 || destNoteIndex == -1) return;

    final sourceNote = _notes[sourceNoteIndex];
    final destNote = _notes[destNoteIndex];
    
    // Find the entry to move
    TextEntry? entryToMove;
    for (final headline in sourceNote.headlines) {
      if (headline.id == sourceHeadlineId) {
        try {
          entryToMove = headline.entries.firstWhere((e) => e.id == entryId);
        } catch (e) {
          return; // Entry not found
        }
        break;
      }
    }
    
    if (entryToMove == null) return;
    
    // Remove entry from source note
    final updatedSourceHeadlines = sourceNote.headlines.map((headline) {
      if (headline.id == sourceHeadlineId) {
        final updatedEntries = headline.entries.where((e) => e.id != entryId).toList();
        return headline.copyWith(entries: updatedEntries);
      }
      return headline;
    }).where((headline) => headline.entries.isNotEmpty).toList();
    
    final updatedSourceNote = sourceNote.copyWith(
      headlines: updatedSourceHeadlines,
      updatedAt: DateTime.now(),
    );
    
    // Add entry to destination note
    final updatedDestHeadlines = destNote.headlines.map((headline) {
      if (headline.id == destHeadlineId) {
        return headline.copyWith(entries: [...headline.entries, entryToMove!]);
      }
      return headline;
    }).toList();
    
    final updatedDestNote = destNote.copyWith(
      headlines: updatedDestHeadlines,
      updatedAt: DateTime.now(),
    );
    
    // Update both notes
    await updateNote(updatedSourceNote, notify: false);
    await updateNote(updatedDestNote, notify: true);
  }

  Future<String> transcribeAudio(String audioPath) async {
    if (_openAIService == null) throw Exception('API key not set');
    return await _openAIService!.transcribeAudio(audioPath);
  }

  /// Find the best matching headline using fuzzy string matching
  /// Returns the index of the best match, or -1 if no good match is found
  int _findBestHeadlineMatch(String targetHeadline, List<Headline> headlines) {
    if (headlines.isEmpty) return -1;
    
    // Minimum similarity threshold (85%)
    const threshold = 0.85;
    
    int bestIndex = -1;
    double bestSimilarity = 0.0;
    
    for (int i = 0; i < headlines.length; i++) {
      final similarity = targetHeadline.similarityTo(headlines[i].title);
      if (similarity > bestSimilarity && similarity >= threshold) {
        bestSimilarity = similarity;
        bestIndex = i;
      }
    }
    
    if (bestIndex != -1) {
      print('🔍 Fuzzy match found: "$targetHeadline" → "${headlines[bestIndex].title}" (${(bestSimilarity * 100).toStringAsFixed(1)}% similar)');
    }
    
    return bestIndex;
  }

  Future<String?> addTranscriptionToNote(
    String transcribedText,
    String noteId,
  ) async {
    if (_openAIService == null) throw Exception('API key not set');

    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return null;

    final note = _notes[noteIndex];

    // Find or create headline
    final headlineMatch = await _openAIService!.findOrCreateHeadline(
      transcribedText,
      note,
    );

    // Create text entry
    final textEntry = TextEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: transcribedText,
      createdAt: DateTime.now(),
    );

    List<Headline> updatedHeadlines = List.from(note.headlines);

    if (headlineMatch.action == HeadlineAction.useExisting) {
      // First, try exact match (case-insensitive)
      var headlineIndex = updatedHeadlines.indexWhere(
        (h) => h.title.toLowerCase() == headlineMatch.headline.toLowerCase(),
      );

      // If exact match fails, try fuzzy matching
      if (headlineIndex == -1) {
        print('⚠️ Exact match failed for "${headlineMatch.headline}", trying fuzzy match...');
        headlineIndex = _findBestHeadlineMatch(
          headlineMatch.headline,
          updatedHeadlines,
        );
      }

      if (headlineIndex != -1) {
        // Found a match (exact or fuzzy) - add entry to existing headline
        final headline = updatedHeadlines[headlineIndex];
        updatedHeadlines[headlineIndex] = headline.copyWith(
          entries: [...headline.entries, textEntry],
        );
        print('✅ Added entry to existing headline: "${headline.title}"');
      } else {
        // No match found even with fuzzy matching - create new headline
        print('⚠️ No match found, creating new headline: "${headlineMatch.headline}"');
        updatedHeadlines.add(
          Headline(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: headlineMatch.headline,
            entries: [textEntry],
            createdAt: DateTime.now(),
          ),
        );
      }
    } else {
      // Create new headline
      print('✅ Creating new headline: "${headlineMatch.headline}"');
      updatedHeadlines.add(
        Headline(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: headlineMatch.headline,
          entries: [textEntry],
          createdAt: DateTime.now(),
        ),
      );
    }

    // Update note (this will notify listeners once)
    final updatedNote = note.copyWith(
      headlines: updatedHeadlines,
      updatedAt: DateTime.now(),
    );

    await updateNote(updatedNote, notify: true);
    
    // Generate tags asynchronously (don't block the UI, don't notify immediately)
    _generateAndUpdateTags(updatedNote.id);
    
    // Return the created entry ID
    return textEntry.id;
  }

  Future<void> _generateAndUpdateTags(String noteId) async {
    try {
      if (_openAIService == null) return;
      
      final noteIndex = _notes.indexWhere((n) => n.id == noteId);
      if (noteIndex == -1) return;

      final note = _notes[noteIndex];
      final tags = await _openAIService!.generateTags(note);

      if (tags.isNotEmpty) {
        final updatedNote = note.copyWith(tags: tags);
        // Notify silently since user may have navigated away
        await updateNote(updatedNote, notify: false);
        // Only notify if we're still on the same screen
        notifyListeners();
      }
    } catch (e) {
      // Silently fail tag generation - it's not critical
      if (kDebugMode) {
        print('Tag generation failed: $e');
      }
    }
  }

  /// Find all search matches within a specific note
  List<SearchMatch> findSearchMatches(String noteId, String searchQuery) {
    final matches = <SearchMatch>[];
    
    if (searchQuery.trim().isEmpty) return matches;
    
    final noteIndex = _notes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return matches;
    
    final note = _notes[noteIndex];
    final query = searchQuery.toLowerCase().trim();
    
    // Search through all headlines and entries
    for (final headline in note.headlines) {
      for (final entry in headline.entries) {
        final text = entry.text.toLowerCase();
        int startIndex = 0;
        
        // Find all occurrences in this entry
        while (true) {
          final index = text.indexOf(query, startIndex);
          if (index == -1) break;
          
          matches.add(SearchMatch(
            headlineId: headline.id,
            headlineTitle: headline.title,
            entryId: entry.id,
            entryText: entry.text,
            matchStartIndex: index,
            matchEndIndex: index + query.length,
          ));
          
          startIndex = index + 1; // Move past this match to find next one
        }
      }
    }
    
    return matches;
  }
}

