import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../services/haptic_service.dart';
import '../services/localization_service.dart';
import 'custom_snackbar.dart';

/// Dialog for exporting user data
class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  bool _isExporting = false;
  String? _exportFormat = 'json';

  Future<void> _exportData(BuildContext context, String format) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final notesProvider = context.read<NotesProvider>();
      final foldersProvider = context.read<FoldersProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      String content;
      String filename;
      String mimeType;

      switch (format) {
        case 'json':
          content = await ExportService.exportAsJSON(
            notes: notesProvider.allNotes,
            folders: foldersProvider.folders,
          );
          filename = 'nota_ai_export_${DateTime.now().millisecondsSinceEpoch}.json';
          mimeType = 'application/json';
          break;
        case 'markdown':
          content = await ExportService.exportAsMarkdown(
            notes: notesProvider.allNotes,
            folders: foldersProvider.folders,
          );
          filename = 'nota_ai_export_${DateTime.now().millisecondsSinceEpoch}.md';
          mimeType = 'text/markdown';
          break;
        case 'csv':
          content = await ExportService.exportAsCSV(
            notes: notesProvider.allNotes,
            folders: foldersProvider.folders,
          );
          filename = 'nota_ai_export_${DateTime.now().millisecondsSinceEpoch}.csv';
          mimeType = 'text/csv';
          break;
        default:
          throw Exception('Unsupported export format');
      }

      // Get the render box for positioning the share dialog on iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Share the export
      await ExportService.shareExport(
        content: content,
        filename: filename,
        mimeType: mimeType,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (mounted) {
        await HapticService.success();
        Navigator.pop(context);
        
        final localization = LocalizationService();
        CustomSnackbar.show(
          context,
          message: localization.t('export_success', {'count': '${notesProvider.allNotes.length}'}),
          type: SnackbarType.success,
          themeConfig: settingsProvider.currentThemeConfig,
        );
      }
    } catch (e) {
      if (mounted) {
        await HapticService.error();
        
        final localization = LocalizationService();
        CustomSnackbar.show(
          context,
          message: localization.t('export_failed', {'error': e.toString()}),
          type: SnackbarType.error,
          themeConfig: context.read<SettingsProvider>().currentThemeConfig,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();
    
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;

        return AlertDialog(
          backgroundColor: AppTheme.glassStrongSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            side: const BorderSide(color: AppTheme.glassBorder, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(
                Icons.upload_file,
                color: themeConfig.primary,
                size: 28,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                localization.t('export_title'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localization.t('export_choose_format'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _buildFormatOption(
                context,
                value: 'json',
                title: localization.t('export_json_title'),
                subtitle: localization.t('export_json_subtitle'),
                icon: Icons.code,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildFormatOption(
                context,
                value: 'markdown',
                title: localization.t('export_markdown_title'),
                subtitle: localization.t('export_markdown_subtitle'),
                icon: Icons.text_snippet,
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildFormatOption(
                context,
                value: 'csv',
                title: localization.t('export_csv_title'),
                subtitle: localization.t('export_csv_subtitle'),
                icon: Icons.table_chart,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isExporting ? null : () => Navigator.pop(context),
              child: Text(
                localization.t('export_cancel'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: _isExporting || _exportFormat == null
                  ? null
                  : () => _exportData(context, _exportFormat!),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeConfig.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(localization.t('export_button')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormatOption(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _exportFormat == value;
    
    return GestureDetector(
      onTap: _isExporting
          ? null
          : () {
              HapticService.light();
              setState(() {
                _exportFormat = value;
              });
            },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.glassSurface.withOpacity(0.5)
              : AppTheme.glassSurface.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.glassBorder : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: context.read<SettingsProvider>().currentThemeConfig.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

