import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';
import '../../services/localization_service.dart';

/// Chat input field with send button
class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSend;
  final bool isProcessing;
  final Color primaryColor;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isProcessing,
    required this.primaryColor,
  });

  void _handleSend() {
    final text = controller.text.trim();
    if (text.isNotEmpty && !isProcessing) {
      HapticService.light();
      onSend(text);
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !isProcessing;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.glassStrongSurface,
        border: Border(
          top: BorderSide(
            color: AppTheme.glassBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
              decoration: InputDecoration(
                hintText: LocalizationService().t('type_message'),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: AppTheme.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          AnimatedContainer(
            duration: AppTheme.animationNormal,
            curve: Curves.easeOutCubic,
            child: IconButton(
              onPressed: canSend ? _handleSend : null,
              icon: Icon(
                Icons.send,
                color: canSend ? primaryColor : AppTheme.textTertiary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: canSend
                    ? primaryColor.withValues(alpha: 0.2)
                    : AppTheme.glassSurface,
                padding: const EdgeInsets.all(AppTheme.spacing12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

