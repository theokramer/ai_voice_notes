import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/note.dart';
import '../services/openai_service.dart';
import '../widgets/ai_chat_overlay.dart';

/// Controller for AI chat functionality
/// Manages chat state, messages, and communication with OpenAI
class AIChatController extends ChangeNotifier {
  bool _isInChatMode = false;
  final List<ChatMessage> _chatMessages = [];
  String? _chatContext;
  bool _isAIProcessing = false;

  bool get isInChatMode => _isInChatMode;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  String? get chatContext => _chatContext;
  bool get isAIProcessing => _isAIProcessing;

  /// Enter chat mode with optional initial query
  void enterChatMode({String? initialQuery}) {
    _isInChatMode = true;
    _chatContext = initialQuery?.isNotEmpty == true ? initialQuery : null;
    notifyListeners();
  }

  /// Exit chat mode and clear state
  void exitChatMode() {
    _isInChatMode = false;
    _chatMessages.clear();
    _chatContext = null;
    _isAIProcessing = false;
    notifyListeners();
  }

  /// Send a message to the AI and get response
  Future<void> sendMessage({
    required String message,
    required List<Note> notes,
  }) async {
    if (message.trim().isEmpty) return;

    // Add user message
    _chatMessages.add(ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _isAIProcessing = true;
    notifyListeners();

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('OpenAI API key not found');
      }

      final openAIService = OpenAIService(apiKey: apiKey);

      // Build conversation history
      final history = _chatMessages
          .where((m) => m.isUser)
          .map((m) => {'role': 'user', 'content': m.text})
          .toList();

      final response = await openAIService.chatCompletion(
        message: message,
        history: history,
        notes: notes,
      );

      // Add AI response
      final aiMessage = ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        noteCitations: response.noteCitations,
      );

      _chatMessages.add(aiMessage);
      _isAIProcessing = false;
      notifyListeners();
    } catch (e) {
      _chatMessages.add(ChatMessage(
        text: 'Sorry, I encountered an error: ${e.toString()}',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isAIProcessing = false;
      notifyListeners();
    }
  }

  /// Add a system message to the chat (e.g., confirmation messages)
  void addSystemMessage(String message) {
    _chatMessages.add(ChatMessage(
      text: message,
      isUser: false,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _chatMessages.clear();
    super.dispose();
  }
}

