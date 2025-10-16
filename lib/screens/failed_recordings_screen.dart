import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/failed_recording.dart';
import '../services/failed_recordings_service.dart';
import '../services/openai_service.dart';
import '../providers/notes_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/animated_background.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FailedRecordingsScreen extends StatefulWidget {
  const FailedRecordingsScreen({super.key});

  @override
  State<FailedRecordingsScreen> createState() => _FailedRecordingsScreenState();
}

class _FailedRecordingsScreenState extends State<FailedRecordingsScreen> {
  bool _isRetrying = false;
  String? _retryError;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final themeConfig = settingsProvider.currentThemeConfig;
        return Scaffold(
          body: AnimatedBackground(
            themeConfig: themeConfig,
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FailedRecordingsHeaderDelegate(
                      onBackPressed: () {
                        HapticService.light();
                        Navigator.pop(context);
                      },
                      expandedHeight: 120.0 + MediaQuery.of(context).padding.top,
                      collapsedHeight: 60.0 + MediaQuery.of(context).padding.top,
                      themeConfig: themeConfig,
                    ),
                  ),
                  
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTheme.spacing16),
                  ),
                  
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing24,
                    ),
                    sliver: Consumer<FailedRecordingsService>(
                      builder: (context, failedRecordingsService, child) {
                        if (failedRecordingsService.count == 0) {
                          return _buildEmptyState(themeConfig);
                        }
                        
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            // Retry All Button
                            _buildRetryAllButton(themeConfig, failedRecordingsService),
                            
                            const SizedBox(height: AppTheme.spacing24),
                            
                            // Storage Info
                            _buildStorageInfo(themeConfig, failedRecordingsService),
                            
                            const SizedBox(height: AppTheme.spacing24),
                            
                            // Failed Recordings List
                            ...failedRecordingsService.failedRecordings.map(
                              (recording) => _buildRecordingCard(
                                recording,
                                themeConfig,
                                failedRecordingsService,
                              ),
                            ),
                            
                            const SizedBox(height: AppTheme.spacing32),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeConfig themeConfig) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              decoration: BoxDecoration(
                color: themeConfig.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                border: Border.all(
                  color: themeConfig.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: themeConfig.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No Failed Recordings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'All your recordings have been successfully transcribed!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryAllButton(ThemeConfig themeConfig, FailedRecordingsService service) {
    return GestureDetector(
      onTap: _isRetrying ? null : () => _retryAllRecordings(service),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeConfig.primaryColor,
              themeConfig.primaryColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: themeConfig.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retry All Recordings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${service.count} recording${service.count == 1 ? '' : 's'} ready to retry',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isRetrying)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
              ],
            ),
            if (_retryError != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        _retryError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildStorageInfo(ThemeConfig themeConfig, FailedRecordingsService service) {
    return FutureBuilder<String>(
      future: service.getFormattedStorageSize(),
      builder: (context, snapshot) {
        final storageSize = snapshot.data ?? '0B';
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.storage,
                color: themeConfig.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  'Storage Used: $storageSize',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordingCard(
    FailedRecording recording,
    ThemeConfig themeConfig,
    FailedRecordingsService service,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.glassBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with timestamp and delete button
          Row(
            children: [
              Icon(
                Icons.mic_off,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  recording.formattedTimestamp,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(recording, service),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing8),
          
          // Duration
          if (recording.recordingDuration != null) ...[
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  recording.formattedDuration,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
          
          // Error message
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: Colors.red.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    recording.errorMessage ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0);
  }

  void _showDeleteConfirmation(FailedRecording recording, FailedRecordingsService service) {
    HapticService.light();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade400,
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      'Delete Recording?',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'This will permanently delete the failed recording and its audio file.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.light();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacing16,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.glassSurface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await HapticService.medium();
                        await service.removeRecording(recording.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          CustomSnackbar.show(
                            context,
                            message: 'Recording deleted',
                            type: SnackbarType.success,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacing16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.red.shade600,
                              Colors.red.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.buttonShadow,
                        ),
                        child: Center(
                          child: Text(
                            'Delete',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
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
      )
          .animate()
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1, 1),
            duration: AppTheme.animationFast,
            curve: Curves.easeOut,
          )
          .fadeIn(duration: AppTheme.animationFast),
    );
  }

  Future<void> _retryAllRecordings(FailedRecordingsService service) async {
    if (_isRetrying) return;
    
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });
    
    try {
      // Get required services
      final openAIService = OpenAIService(apiKey: dotenv.env['OPENAI_API_KEY'] ?? '');
      final notesProvider = context.read<NotesProvider>();
      final foldersProvider = context.read<FoldersProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      
      // Retry all recordings
      final successCount = await service.retryAllRecordings(
        openAIService: openAIService,
        notesProvider: notesProvider,
        foldersProvider: foldersProvider,
        settingsProvider: settingsProvider,
      );
      
      if (mounted) {
        HapticService.success();
        CustomSnackbar.show(
          context,
          message: '$successCount recording${successCount == 1 ? '' : 's'} queued for retry',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retryError = 'Failed to retry recordings: ${e.toString()}';
        });
        HapticService.heavy();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }
}

// Custom SliverPersistentHeaderDelegate for animated header
class _FailedRecordingsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onBackPressed;
  final double expandedHeight;
  final double collapsedHeight;
  final ThemeConfig themeConfig;

  _FailedRecordingsHeaderDelegate({
    required this.onBackPressed,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.themeConfig,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double shrinkProgress = (shrinkOffset / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
    final safePadding = MediaQuery.of(context).padding.top;
    final double fontSize = 48 - (shrinkProgress * 26);
    final double topPadding = 56 - (shrinkProgress * 40);
    final double bottomPadding = 24 - (shrinkProgress * 8);
    final double horizontalPadding = 24 - (shrinkProgress * 4);
    final double backButtonSize = 46 - (shrinkProgress * 6);
    final double backgroundOpacity = shrinkProgress * 0.4;
    final double blurAmount = shrinkProgress * 20;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            safePadding + topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          decoration: BoxDecoration(
            color: AppTheme.glassDarkSurface.withValues(alpha: backgroundOpacity),
            border: shrinkProgress > 0.5 ? const Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder,
                width: 1.5,
              ),
            ) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onBackPressed,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: backButtonSize,
                      height: backButtonSize,
                      decoration: AppTheme.glassDecoration(
                        radius: AppTheme.radiusMedium,
                        color: AppTheme.glassDarkSurface,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: shrinkProgress * 4),
                  child: Text(
                    'Failed Recordings',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      height: 1.0,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.visible,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _FailedRecordingsHeaderDelegate oldDelegate) {
    return true;
  }
}
