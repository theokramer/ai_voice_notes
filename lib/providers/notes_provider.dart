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
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
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

  /// Creates sample tutorial notes for first-time users
  List<Note> _createSampleNotes() {
    final now = DateTime.now();
    
    return [
      // Sample Note 1: Welcome & Tutorial
      Note(
        id: 'sample_${now.millisecondsSinceEpoch}_1',
        name: 'Welcome to Voice Notes',
        icon: '🎙️',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        headlines: [
          Headline(
            id: 'sample_headline_1_1',
            title: 'Getting Started',
            createdAt: now.subtract(const Duration(hours: 2)),
            entries: [
              TextEntry(
                id: 'sample_entry_1_1_1',
                text: 'Welcome to Voice Notes! This app is designed to capture your thoughts effortlessly through voice recording. Simply tap the microphone button at the bottom of the screen to start recording. The app will automatically transcribe your speech into text using advanced speech recognition technology, so you can focus on your ideas instead of typing.',
                createdAt: now.subtract(const Duration(hours: 2)),
              ),
              TextEntry(
                id: 'sample_entry_1_1_2',
                text: 'Your recordings are intelligently organized. The AI creates headlines that group related content together. This happens automatically. You can record continuously and let the AI handle the organization - it\'s designed to understand context and create meaningful sections from your speech.',
                createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
              ),
              TextEntry(
                id: 'sample_entry_1_1_3',
                text: 'The interface is clean. Minimalist. You can switch between different view modes using the button in the top right. Try the grid view for a visual overview, or the minimalistic list for focus. Both work great!',
                createdAt: now.subtract(const Duration(hours: 2, minutes: 45)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_1_2',
            title: 'Core Features',
            createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
            entries: [
              TextEntry(
                id: 'sample_entry_1_2_1',
                text: 'Search functionality allows you to quickly find any note or entry by typing keywords. The search works across all your content. You can also use the AI assistant by pulling down from the top. Just ask!',
                createdAt: now.subtract(const Duration(hours: 1, minutes: 45)),
              ),
              TextEntry(
                id: 'sample_entry_1_2_2',
                text: 'Pin important notes to keep them at the top. Perfect for ongoing projects or frequently referenced information. Pinned items stay at the top regardless of your sorting preferences, making them instantly accessible whenever you need them.',
                createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
              ),
              TextEntry(
                id: 'sample_entry_1_2_3',
                text: 'You have complete control. Tap any entry to edit it. Long-press to see more options including moving entries between sections or even to different notes. You can also manually create new sections by tapping on headline titles and reorganize everything.',
                createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
              ),
              TextEntry(
                id: 'sample_entry_1_2_4',
                text: 'The AI assistant is always available. Pull down from the top of the screen. Ask it to summarize your notes, find specific information, or create new notes from your questions. It has access to all your notes and provides contextual answers based on your content.',
                createdAt: now.subtract(const Duration(hours: 1, minutes: 5)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_1_3',
            title: 'Tips for Best Results',
            createdAt: now.subtract(const Duration(hours: 1)),
            entries: [
              TextEntry(
                id: 'sample_entry_1_3_1',
                text: 'For best transcription quality, speak clearly. Natural pace works best. The AI understands complete sentences better, but it also handles fragments and quick thoughts. If you\'re in a noisy environment, stay close to your device and speak slightly louder than usual.',
                createdAt: now.subtract(const Duration(hours: 1)),
              ),
              TextEntry(
                id: 'sample_entry_1_3_2',
                text: 'Create different notes for different contexts. Work meetings. Personal ideas. Project planning. Daily journals. Learning notes. This organization helps you find information later and keeps your thoughts categorized naturally.',
                createdAt: now.subtract(const Duration(minutes: 45)),
              ),
              TextEntry(
                id: 'sample_entry_1_3_3',
                text: 'The AI learns from your usage patterns. It recognizes how you organize content. Feel free to manually adjust the AI\'s suggestions. This helps the system improve over time and adapt to your unique workflow and thinking style!',
                createdAt: now.subtract(const Duration(minutes: 30)),
              ),
            ],
          ),
        ],
        isPinned: true,
      ),
      
      // Sample Note 2: Meeting Notes Example
      Note(
        id: 'sample_${now.millisecondsSinceEpoch}_2',
        name: 'Q4 Product Planning',
        icon: '📊',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        headlines: [
          Headline(
            id: 'sample_headline_2_1',
            title: 'Priority Action Items',
            createdAt: now.subtract(const Duration(days: 1)),
            entries: [
              TextEntry(
                id: 'sample_entry_2_1_1',
                text: 'Schedule a comprehensive review session with the design team. We need their feedback by end of week. This is critical for the Q4 launch timeline. Make sure to include both the senior designers and the UX research team so everyone is aligned.',
                createdAt: now.subtract(const Duration(days: 1)),
              ),
              TextEntry(
                id: 'sample_entry_2_1_2',
                text: 'Follow-up meeting next Tuesday at 2 PM. Send calendar invites to all stakeholders. Product, engineering, and marketing teams. Prepare a brief status update document beforehand to keep the meeting focused and efficient.',
                createdAt: now.subtract(const Duration(days: 1, hours: 1)),
              ),
              TextEntry(
                id: 'sample_entry_2_1_3',
                text: 'Begin drafting the technical specification document. Work with the engineering leads. Ensure all requirements are technically feasible and clearly defined. Target completion by next Friday!',
                createdAt: now.subtract(const Duration(days: 1, hours: 2)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_2_2',
            title: 'Key Discussion Points',
            createdAt: now.subtract(const Duration(days: 1, hours: 2)),
            entries: [
              TextEntry(
                id: 'sample_entry_2_2_1',
                text: 'We had an extensive discussion about the timeline for the new feature rollout. After considering various approaches, the team unanimously agreed on a phased rollout strategy. Phase 1 will target power users in October, Phase 2 will expand to all users in November, and Phase 3 introduces advanced features in December.',
                createdAt: now.subtract(const Duration(days: 1, hours: 2)),
              ),
              TextEntry(
                id: 'sample_entry_2_2_2',
                text: 'Budget concerns were initially raised by the finance team regarding the increased infrastructure costs. However, after presenting the revised proposal with optimized resource allocation and projected ROI, they approved the budget. We secured an additional 15% contingency fund for unexpected developments.',
                createdAt: now.subtract(const Duration(days: 1, hours: 3)),
              ),
              TextEntry(
                id: 'sample_entry_2_2_3',
                text: 'Marketing wants to align the product launch with the annual conference in December. This gives us a great platform for announcement but also adds pressure to the timeline. The team is confident we can meet this deadline with the current resource allocation.',
                createdAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 30)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_2_3',
            title: 'Follow-up Required',
            createdAt: now.subtract(const Duration(days: 1, hours: 4)),
            entries: [
              TextEntry(
                id: 'sample_entry_2_3_1',
                text: 'Send out a comprehensive meeting summary to all attendees by end of today. Include the key decisions made, action items with assigned owners, and the updated timeline. Make sure to CC the executive team for visibility.',
                createdAt: now.subtract(const Duration(days: 1, hours: 4)),
              ),
              TextEntry(
                id: 'sample_entry_2_3_2',
                text: 'Reach out to the legal team to ensure all compliance requirements are met for the new data handling features. Schedule a meeting with them early next week to go through the technical details.',
                createdAt: now.subtract(const Duration(days: 1, hours: 4, minutes: 30)),
              ),
            ],
          ),
        ],
      ),
      
      // Sample Note 3: Ideas & Thoughts
      Note(
        id: 'sample_${now.millisecondsSinceEpoch}_3',
        name: 'Innovation Brainstorm',
        icon: '💡',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        headlines: [
          Headline(
            id: 'sample_headline_3_1',
            title: 'App Concepts',
            createdAt: now.subtract(const Duration(days: 2)),
            entries: [
              TextEntry(
                id: 'sample_entry_3_1_1',
                text: 'Idea for a personal productivity app that uses AI to track daily habits and provides intelligent insights. The app would learn from your patterns and suggest optimal times for different activities. It could integrate with calendar, health data, and even weather to provide contextual recommendations.',
                createdAt: now.subtract(const Duration(days: 2)),
              ),
              TextEntry(
                id: 'sample_entry_3_1_2',
                text: 'Concept for a collaborative workspace tool that seamlessly integrates voice notes with traditional task management. Teams could record quick updates, brainstorm sessions, or meeting notes, and the AI would automatically extract action items, assign tasks, and update project timelines. This could revolutionize how distributed teams work together.',
                createdAt: now.subtract(const Duration(days: 2, hours: 1)),
              ),
              TextEntry(
                id: 'sample_entry_3_1_3',
                text: 'Educational platform idea that uses spaced repetition and voice interaction to help people learn languages. Instead of traditional flashcards, users would have natural conversations with an AI that adapts to their learning pace and interests. The voice aspect makes it more natural than text-based learning.',
                createdAt: now.subtract(const Duration(days: 2, hours: 1, minutes: 30)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_3_2',
            title: 'Reflections',
            createdAt: now.subtract(const Duration(days: 2, hours: 2)),
            entries: [
              TextEntry(
                id: 'sample_entry_3_2_1',
                text: 'Thinking about how voice interfaces are becoming more natural and intuitive. What if we could use voice notes not just for recording, but to create automatic daily summaries? Imagine ending each day by reviewing an AI-generated summary of everything you captured - your thoughts, tasks, and insights all organized.',
                createdAt: now.subtract(const Duration(days: 2, hours: 2)),
              ),
              TextEntry(
                id: 'sample_entry_3_2_2',
                text: 'The future of productivity tools might not be about adding more features, but about removing friction. Voice is inherently lower friction than typing. If we can make the organization and retrieval just as effortless, we might fundamentally change how people capture and use information.',
                createdAt: now.subtract(const Duration(days: 2, hours: 2, minutes: 30)),
              ),
            ],
          ),
          Headline(
            id: 'sample_headline_3_3',
            title: 'Research Topics',
            createdAt: now.subtract(const Duration(days: 2, hours: 3)),
            entries: [
              TextEntry(
                id: 'sample_entry_3_3_1',
                text: 'Need to research how AI can better understand context in voice recordings. Current systems are good at transcription, but struggle with understanding intent, emotion, and implicit context. What would it take to build a system that truly understands what someone means, not just what they say?',
                createdAt: now.subtract(const Duration(days: 2, hours: 3)),
              ),
              TextEntry(
                id: 'sample_entry_3_3_2',
                text: 'What are the best practices for organizing and retrieving large amounts of voice data? Traditional search works for text, but voice adds dimensions like tone, pace, and emotion. How can we make this searchable and useful? Are there new interaction paradigms we should explore?',
                createdAt: now.subtract(const Duration(days: 2, hours: 4)),
              ),
              TextEntry(
                id: 'sample_entry_3_3_3',
                text: 'Privacy and security considerations for voice data are crucial. Users need to trust that their personal thoughts and conversations are protected. Research end-to-end encryption options and explore local processing possibilities to minimize data sent to servers.',
                createdAt: now.subtract(const Duration(days: 2, hours: 4, minutes: 30)),
              ),
            ],
          ),
        ],
      ),
    ];
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
    
    // Add sample notes on first launch if no notes exist
    final isFirstLaunch = await _storageService.isFirstLaunch();
    if (isFirstLaunch && _notes.isEmpty) {
      _notes = _createSampleNotes();
      await _storageService.saveNotes(_notes);
      await _storageService.setFirstLaunchComplete();
      debugPrint('✨ Added sample tutorial notes for first-time user');
    }
    
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
      debugPrint('🔍 Fuzzy match found: "$targetHeadline" → "${headlines[bestIndex].title}" (${(bestSimilarity * 100).toStringAsFixed(1)}% similar)');
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

    // Set AI processing state
    _aiProcessingStates[noteId] = true;
    notifyListeners();

    try {
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
        debugPrint('⚠️ Exact match failed for "${headlineMatch.headline}", trying fuzzy match...');
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
        debugPrint('✅ Added entry to existing headline: "${headline.title}"');
      } else {
        // No match found even with fuzzy matching - create new headline
        debugPrint('⚠️ No match found, creating new headline: "${headlineMatch.headline}"');
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
      debugPrint('✅ Creating new headline: "${headlineMatch.headline}"');
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
    } finally {
      // Clear AI processing state
      _aiProcessingStates[noteId] = false;
      notifyListeners();
    }
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
        debugPrint('Tag generation failed: $e');
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

