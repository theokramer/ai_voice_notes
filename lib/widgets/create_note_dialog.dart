import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';

class CreateNoteDialog extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  
  const CreateNoteDialog({
    super.key,
    this.initialName,
    this.initialIcon,
  });

  @override
  State<CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<CreateNoteDialog> {
  late final TextEditingController _nameController;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'icon': '📝', // Default icon
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                decoration: BoxDecoration(
                  color: AppTheme.glassStrongSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initialName != null ? LocalizationService().t('edit_note') : LocalizationService().t('create_note'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppTheme.spacing24),
                // Name input
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: LocalizationService().t('note_name_hint'),
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppTheme.glassSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: const BorderSide(color: AppTheme.glassBorder, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(color: themeConfig.primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                  ),
                  onSubmitted: (_) => _handleCreate(),
                ),
                const SizedBox(height: AppTheme.spacing24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing16,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.glassSurface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              LocalizationService().t('cancel'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleCreate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacing16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                themeConfig.primaryColor,
                                themeConfig.primaryColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                            boxShadow: AppTheme.getThemedShadow(themeConfig),
                          ),
                          child: Center(
                            child: Text(
                              widget.initialName != null ? LocalizationService().t('save') : LocalizationService().t('create'),
                              style:
                                  Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ),
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
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: AppTheme.animationNormal,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: AppTheme.animationNormal);
      },
    );
  }
}

