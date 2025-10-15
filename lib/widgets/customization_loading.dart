import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_language.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';

/// Loading screen that simulates app customization and requests mic permission
class CustomizationLoading extends StatefulWidget {
  final VoidCallback onComplete;

  const CustomizationLoading({
    super.key,
    required this.onComplete,
  });

  @override
  State<CustomizationLoading> createState() => _CustomizationLoadingState();
}

class _CustomizationLoadingState extends State<CustomizationLoading> {
  int _currentStep = 0;
  bool _permissionRequested = false;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    final localization = LocalizationService();
    
    // Get tasks with localization
    final tasks = [
      localization.t('loading_task_1'),
      localization.t('loading_task_2', {
        'language': Provider.of<SettingsProvider>(context, listen: false)
            .preferredLanguage
            .nativeName,
      }),
      localization.t('loading_task_3'),
      localization.t('loading_task_4'),
      localization.t('loading_task_5'),
    ];

    // Progress through tasks
    for (int i = 0; i < tasks.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 800 : 1200));
      
      if (!mounted) return;
      
      setState(() {
        _currentStep = i + 1;
      });

      // Request microphone permission at step 3 (mid-load)
      if (i == 2 && !_permissionRequested && mounted) {
        _permissionRequested = true;
        _requestMicrophonePermission();
      }
    }

    // Wait a bit before completing
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      widget.onComplete();
    }
  }

  Future<void> _requestMicrophonePermission() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Request microphone permission
      final status = await Permission.microphone.request();
      
      // Mark as requested in settings
      await settingsProvider.setMicPermissionRequested();
      
      debugPrint('Microphone permission status: $status');
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        final language = settingsProvider.preferredLanguage;
        
        final tasks = [
          localization.t('loading_task_1'),
          localization.t('loading_task_2', {'language': language.nativeName}),
          localization.t('loading_task_3'),
          localization.t('loading_task_4'),
          localization.t('loading_task_5'),
        ];

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.background,
                  settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated loader icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            settingsProvider.currentThemeConfig.primary,
                            settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 50,
                        color: Colors.white,
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .rotate(duration: 3000.ms, curve: Curves.easeInOut)
                        .then()
                        .shimmer(duration: 2000.ms),
                    
                    const SizedBox(height: AppTheme.spacing48),
                    
                    // Title
                    Text(
                      localization.t('loading_title'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),
                    
                    const SizedBox(height: AppTheme.spacing48),
                    
                    // Progress indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: LinearProgressIndicator(
                        value: _currentStep / tasks.length,
                        backgroundColor: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          settingsProvider.currentThemeConfig.primary,
                        ),
                        minHeight: 8,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms),
                    
                    const SizedBox(height: AppTheme.spacing32),
                    
                    // Task list
                    ...List.generate(tasks.length, (index) {
                      final isCompleted = index < _currentStep;
                      final isCurrent = index == _currentStep - 1;
                      
                      return _TaskItem(
                        task: tasks[index],
                        isCompleted: isCompleted,
                        isCurrent: isCurrent,
                        primaryColor: settingsProvider.currentThemeConfig.primary,
                        delay: index * 100,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String task;
  final bool isCompleted;
  final bool isCurrent;
  final Color primaryColor;
  final int delay;

  const _TaskItem({
    required this.task,
    required this.isCompleted,
    required this.isCurrent,
    required this.primaryColor,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        // Use theme color background for better visibility on light backgrounds
        color: isCompleted || isCurrent
            ? primaryColor.withValues(alpha: 0.15)
            : primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          // Stronger border with theme color for better visibility
          color: isCompleted || isCurrent
              ? primaryColor.withValues(alpha: 0.6)
              : primaryColor.withValues(alpha: 0.3),
          width: isCompleted || isCurrent ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? primaryColor
                  : isCurrent
                      ? primaryColor.withValues(alpha: 0.3)
                      : AppTheme.textTertiary.withValues(alpha: 0.2),
            ),
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : isCurrent
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : null,
          ),
          
          const SizedBox(width: AppTheme.spacing16),
          
          // Task text
          Expanded(
            child: Text(
              task,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isCompleted || isCurrent
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideX(begin: -0.2, end: 0);
  }
}

