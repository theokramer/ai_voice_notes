import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SnackbarType {
  success,
  error,
  info,
  warning,
}

class CustomSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    ThemeConfig? themeConfig,
  }) {
    final colors = _getColors(type, themeConfig);
    final icon = _getIcon(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: const Color(0xE6000000), // 90% opacity black for better contrast
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: colors['border']!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors['shadow']!,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: colors['iconBg'],
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(
                      icon,
                      color: colors['icon'],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    GestureDetector(
                      onTap: onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing12,
                          vertical: AppTheme.spacing8,
                        ),
                        decoration: BoxDecoration(
                          color: colors['actionBg'],
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            color: colors['actionText'],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Map<String, Color> _getColors(SnackbarType type, ThemeConfig? themeConfig) {
    switch (type) {
      case SnackbarType.success:
        return {
          'border': const Color(0xFF10b981),
          'shadow': const Color(0xFF10b981).withValues(alpha: 0.3),
          'iconBg': const Color(0xFF10b981).withValues(alpha: 0.2),
          'icon': const Color(0xFF10b981),
          'actionBg': const Color(0xFF10b981).withValues(alpha: 0.2),
          'actionText': const Color(0xFF10b981),
        };
      case SnackbarType.error:
        return {
          'border': const Color(0xFFef4444),
          'shadow': const Color(0xFFef4444).withValues(alpha: 0.3),
          'iconBg': const Color(0xFFef4444).withValues(alpha: 0.2),
          'icon': const Color(0xFFef4444),
          'actionBg': const Color(0xFFef4444).withValues(alpha: 0.2),
          'actionText': const Color(0xFFef4444),
        };
      case SnackbarType.warning:
        return {
          'border': const Color(0xFFf59e0b),
          'shadow': const Color(0xFFf59e0b).withValues(alpha: 0.3),
          'iconBg': const Color(0xFFf59e0b).withValues(alpha: 0.2),
          'icon': const Color(0xFFf59e0b),
          'actionBg': const Color(0xFFf59e0b).withValues(alpha: 0.2),
          'actionText': const Color(0xFFf59e0b),
        };
      case SnackbarType.info:
        final primaryColor = themeConfig?.primaryColor ?? AppTheme.primary;
        return {
          'border': primaryColor,
          'shadow': primaryColor.withValues(alpha: 0.3),
          'iconBg': primaryColor.withValues(alpha: 0.2),
          'icon': primaryColor,
          'actionBg': primaryColor.withValues(alpha: 0.2),
          'actionText': primaryColor,
        };
    }
  }

  static IconData _getIcon(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle;
      case SnackbarType.error:
        return Icons.error;
      case SnackbarType.warning:
        return Icons.warning;
      case SnackbarType.info:
        return Icons.info;
    }
  }
}

