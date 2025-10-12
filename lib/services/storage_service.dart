import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/folder.dart';

class StorageService {
  static const String _notesKey = 'notes';
  static const String _apiKeyKey = 'openai_api_key';
  static const String _viewTypeKey = 'note_view_type';
  static const String _sortOptionKey = 'sort_option';
  static const String _sortDirectionKey = 'sort_direction';
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _foldersKey = 'folders';
  static const String _unorganizedFolderIdKey = 'unorganized_folder_id';

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList(_notesKey) ?? [];
    return notesJson.map((json) => Note.fromJsonString(json)).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((note) => note.toJsonString()).toList();
    await prefs.setStringList(_notesKey, notesJson);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  Future<String?> loadViewType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewTypeKey);
  }

  Future<void> saveViewType(String viewType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewTypeKey, viewType);
  }

  Future<String?> loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortOptionKey);
  }

  Future<void> saveSortOption(String sortOption) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOptionKey, sortOption);
  }

  Future<String?> loadSortDirection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortDirectionKey);
  }

  Future<void> saveSortDirection(String sortDirection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortDirectionKey, sortDirection);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  // Folder persistence
  Future<List<Folder>> loadFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getStringList(_foldersKey) ?? [];
    return foldersJson.map((json) => Folder.fromJsonString(json)).toList();
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = folders.map((folder) => folder.toJsonString()).toList();
    await prefs.setStringList(_foldersKey, foldersJson);
  }

  Future<String?> getUnorganizedFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_unorganizedFolderIdKey);
  }

  Future<void> saveUnorganizedFolderId(String folderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unorganizedFolderIdKey, folderId);
  }
}

