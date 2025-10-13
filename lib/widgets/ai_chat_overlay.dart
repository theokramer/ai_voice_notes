import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import '../services/openai_service.dart';
import 'chat/chat_message_bubble.dart';
import 'chat/chat_input_field.dart';

class AIChatOverlay extends StatefulWidget {
  final List<ChatMessage> messages;
  final String? context;
  final VoidCallback onClose;
  final Function(ChatAction action) onAction;
  final Function(String message) onSendMessage;
  final Function(String noteId)? onNoteTap;
  final bool isProcessing;
  final ThemeConfig themeConfig;

  const AIChatOverlay({
    super.key,
    required this.messages,
    this.context,
    required this.onClose,
    required this.onAction,
    required this.onSendMessage,
    this.onNoteTap,
    this.isProcessing = false,
    required this.themeConfig,
  });

  @override
  State<AIChatOverlay> createState() => _AIChatOverlayState();
}

class _AIChatOverlayState extends State<AIChatOverlay> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {}); // Rebuild for send button state
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(AIChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppTheme.animationNormal,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        widget.onClose();
      },
      child: Container(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent taps inside from closing
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    constraints: const BoxConstraints(maxWidth: 400),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing20,
                      vertical: AppTheme.spacing48,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.glassStrongSurface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                            border: Border.all(
                              color: AppTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildHeader(),
                              Expanded(
                                child: _buildMessagesList(),
                              ),
                              _buildInputArea(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: widget.themeConfig.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.psychology,
                  size: 20,
                  color: widget.themeConfig.primaryColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  'Chat with AI',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  widget.onClose();
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: AppTheme.glassSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (widget.context != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing8,
              ),
              decoration: BoxDecoration(
                color: widget.themeConfig.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: widget.themeConfig.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'About: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
                  Flexible(
                    child: Text(
                      '"${widget.context}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: widget.themeConfig.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (widget.messages.isEmpty && !widget.isProcessing) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: widget.messages.length + (widget.isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(widget.messages[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Start chatting with AI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              LocalizationService().t('type_message_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              margin: const EdgeInsets.only(right: AppTheme.spacing8),
              decoration: BoxDecoration(
                color: widget.themeConfig.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.psychology,
                size: 16,
                color: widget.themeConfig.primaryColor,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        gradient: message.isUser
                            ? LinearGradient(
                                colors: [
                                  widget.themeConfig.primaryColor,
                                  widget.themeConfig.primaryColor.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: message.isUser ? null : AppTheme.glassSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: message.isUser
                              ? widget.themeConfig.primaryColor.withValues(alpha: 0.5)
                              : AppTheme.glassBorder,
                        ),
                      ),
                      child: Text(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                if (message.action != null) ...[
                  const SizedBox(height: AppTheme.spacing12),
                  _buildActionCard(message.action!),
                ],
                if (message.noteCitations.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  ...message.noteCitations.map((citation) => Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacing4),
                    child: _buildNoteCitation(citation),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.2, end: 0, duration: 300.ms);
  }

  Widget _buildActionCard(ChatAction action) {
    // Get icon and emoji based on action type
    IconData actionIcon;
    String actionEmoji;
    Color accentColor = widget.themeConfig.primaryColor;
    
    switch (action.type) {
      case 'create_note':
        actionIcon = Icons.note_add;
        actionEmoji = '📝';
        break;
      case 'add_entry':
        actionIcon = Icons.add_circle_outline;
        actionEmoji = '➕';
        accentColor = widget.themeConfig.accentColor;
        break;
      case 'move_entry':
        actionIcon = Icons.drive_file_move_outline;
        actionEmoji = '📦';
        accentColor = widget.themeConfig.secondaryColor;
        break;
      default:
        actionIcon = Icons.psychology;
        actionEmoji = '💡';
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () {
            HapticService.medium();
            widget.onAction(action);
          },
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Icon(
                        actionIcon,
                        size: 18,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suggested Action',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            action.buttonLabel,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.glassSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: AppTheme.glassBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        actionEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          action.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacing12,
                          horizontal: AppTheme.spacing16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              actionIcon,
                              size: 18,
                              color: AppTheme.textPrimary,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              action.buttonLabel,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildNoteCitation(NoteCitation citation) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        widget.onNoteTap?.call(citation.noteId);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: AppTheme.glassSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.note,
              size: 16,
              color: widget.themeConfig.primaryColor,
            ),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                citation.noteName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            margin: const EdgeInsets.only(right: AppTheme.spacing8),
            decoration: BoxDecoration(
              color: widget.themeConfig.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(
              Icons.psychology,
              size: 16,
              color: widget.themeConfig.primaryColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.glassSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.textSecondary,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .fadeIn(
          duration: 600.ms,
          delay: (index * 200).ms,
        )
        .fadeOut(
          duration: 600.ms,
          delay: (index * 200 + 600).ms,
        );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.glassBorder, width: 1),
        ),
      ),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          decoration: AppTheme.glassDecoration(
                            radius: AppTheme.radiusMedium,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _focusNode,
                                  enabled: !widget.isProcessing,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  maxLines: null,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: LocalizationService().t('type_message_placeholder'),
                                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.textTertiary,
                                        ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacing16,
                                      vertical: AppTheme.spacing12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _handleSendMessage(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
          GestureDetector(
            onTap: widget.isProcessing || _messageController.text.trim().isEmpty
                ? null
                : _handleSendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: _messageController.text.trim().isNotEmpty && !widget.isProcessing
                    ? LinearGradient(
                        colors: [
                          widget.themeConfig.primaryColor,
                          widget.themeConfig.primaryColor.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                color: _messageController.text.trim().isEmpty || widget.isProcessing
                    ? AppTheme.glassSurface
                    : null,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _messageController.text.trim().isNotEmpty && !widget.isProcessing
                      ? widget.themeConfig.primaryColor
                      : AppTheme.glassBorder,
                ),
              ),
              child: widget.isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textSecondary,
                      ),
                    )
                  : Icon(
                      Icons.send,
                      size: 20,
                      color: _messageController.text.trim().isNotEmpty
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty || widget.isProcessing) return;
    
    HapticService.medium();
    widget.onSendMessage(message);
    _messageController.clear();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final ChatAction? action;
  final List<NoteCitation> noteCitations;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.noteCitations = const [],
  });
}

class ChatAction {
  final String type; // 'create_note', 'add_entry', etc.
  final String description;
  final String buttonLabel;
  final Map<String, dynamic> data;

  ChatAction({
    required this.type,
    required this.description,
    required this.buttonLabel,
    required this.data,
  });
}

