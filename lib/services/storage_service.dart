import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class StorageService {
  static const String _notesKey = 'notes';
  static const String _apiKeyKey = 'openai_api_key';
  static const String _viewTypeKey = 'note_view_type';

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
}

