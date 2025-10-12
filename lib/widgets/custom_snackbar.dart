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

    // Use overlay instead of SnackBar to avoid layout issues
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _TopSnackbar(
        message: message,
        colors: colors,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
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

class _TopSnackbar extends StatefulWidget {
  final String message;
  final Map<String, Color> colors;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _TopSnackbar({
    required this.message,
    required this.colors,
    required this.icon,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_TopSnackbar> createState() => _TopSnackbarState();
}

class _TopSnackbarState extends State<_TopSnackbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  double _dragExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    _controller.forward();
  }
  
  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta ?? 0;
      // Limit drag to upward direction only
      if (_dragExtent > 0) {
        _dragExtent = 0;
      }
    });
  }
  
  void _handleDragEnd(DragEndDetails details) {
    // If dragged up more than 50 pixels, dismiss
    if (_dragExtent < -50) {
      _controller.reverse().then((_) => widget.onDismiss());
    } else {
      // Otherwise, animate back to original position
      setState(() {
        _dragExtent = 0;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Positioned(
      top: topPadding + 8 + _dragExtent,
      left: 16,
      right: 16,
      child: GestureDetector(
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    decoration: BoxDecoration(
                      color: const Color(0xE6000000), // 90% opacity black for better contrast
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: widget.colors['border']!, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors['shadow']!,
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
                            color: widget.colors['iconBg'],
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.colors['icon'],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null && widget.onAction != null) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          GestureDetector(
                            onTap: () {
                              widget.onAction!();
                              widget.onDismiss();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing12,
                                vertical: AppTheme.spacing8,
                              ),
                              decoration: BoxDecoration(
                                color: widget.colors['actionBg'],
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  color: widget.colors['actionText'],
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
          ),
        ),
      ),
    );
  }
}

