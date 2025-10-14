import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/paywall_flow_controller.dart';
import '../services/localization_service.dart';
import '../providers/settings_provider.dart';
import '../models/onboarding_data.dart';
import '../models/settings.dart';
import '../models/app_language.dart';
import '../widgets/onboarding_question_card.dart';
import '../widgets/onboarding_screenshot.dart';
import '../widgets/animated_background.dart';
import '../widgets/language_selector.dart';
import '../widgets/onboarding_interstitial.dart';
import '../widgets/customization_loading.dart';

/// Professional onboarding flow optimized for maximum conversion
/// Flow: Video + Language → 3 Explanation Pages with Screenshots → Theme Selector →
///       4 Questions (Source, Use Case, Audio Quality, AI Autonomy) → Privacy Interstitial →
///       Rating → Loading + Mic Permission → Completion → Paywall
/// 
/// Philosophy: "Tap. Speak. Done. AI handles the rest."
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> 
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final OnboardingData _onboardingData = OnboardingData();
  
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _videoHasFlownOut = false;

  // Page indices (only those used for logic are defined as constants)
  static const int videoPageIndex = 0;
  static const int question1Index = 5;  // Where did you hear about us
  static const int question2Index = 6;  // Use case
  static const int question3Index = 7;  // Audio quality
  static const int question4Index = 8;  // AI Autonomy Level
  static const int ratingIndex = 10;  // Rating prompt
  static const int loadingIndex = 11;  // Loading + mic permission
  static const int completionIndex = 12;  // Completion screen
  static const int totalPages = 13;
  
  // State for preventing double rating prompt
  bool _hasShownRatingPrompt = false;

  @override
  void initState() {
    super.initState();
    // Initialize async operations without blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
      _initializeLanguage();
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/onboarding/videos/recording_to_note.mp4',
      );
      
      await _videoController!.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Video initialization timed out');
          throw Exception('Video timeout');
        },
      );
      
      await _videoController!.setLooping(false);
      
      // Listen for video position to trigger fly-out animation
      _videoController!.addListener(_videoListener);
      
      await _videoController!.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // Continue without video - don't block the flow
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && _isVideoInitialized) {
      final position = _videoController!.value.position;
      final duration = _videoController!.value.duration;
      
      // Trigger fly-out 3 seconds before end
      if (duration.inSeconds > 0 && 
          position.inSeconds >= duration.inSeconds - 3 &&
          !_videoHasFlownOut) {
        setState(() {
          _videoHasFlownOut = true;
        });
      }
    }
  }

  Future<void> _initializeLanguage() async {
    try {
      if (!mounted) return;
      
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final detectedLanguage = LanguageHelper.detectDeviceLanguage();
      
      // Set language if not already set
      if (settingsProvider.settings.preferredLanguage == null) {
        await settingsProvider.updatePreferredLanguage(detectedLanguage);
        LocalizationService().setLanguage(detectedLanguage);
      } else {
        // Sync with existing language preference
        LocalizationService().setLanguage(settingsProvider.settings.preferredLanguage!);
      }
      
      if (mounted) {
        _onboardingData.selectedLanguage = settingsProvider.preferredLanguage;
      }
    } catch (e) {
      debugPrint('Error initializing language: $e');
      // Continue with default language
      LocalizationService().setLanguage(AppLanguage.english);
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() async {
    await HapticService.medium();
    
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Complete onboarding and launch paywall flow
  Future<void> _completeOnboarding() async {
    try {
      // Save onboarding data
      await _onboardingData.save();
      
      // Apply settings
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      if (_onboardingData.audioQuality != null) {
        await settingsProvider.updateAudioQuality(_onboardingData.audioQuality!);
      }
      
      // Apply AI Autonomy setting
      if (_onboardingData.aiAutopilot != null) {
        final mode = _onboardingData.aiAutopilot! 
            ? OrganizationMode.autoOrganize 
            : OrganizationMode.manualOrganize;
        await settingsProvider.updateOrganizationMode(mode);
      }
      
      // Note: Language is already saved when changed via LanguageSelector
      // No need to save again here as it's already persisted to SharedPreferences
      
      if (!mounted) return;

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      
      await HapticService.success();
      
      if (!mounted) return;

      // Launch paywall flow
      await PaywallFlowController.instance.showOnboardingPaywallFlow(context);
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      
      // Try to launch paywall flow anyway
      if (mounted) {
        await PaywallFlowController.instance.showOnboardingPaywallFlow(context);
      }
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case question1Index:
        return _onboardingData.hearAboutUs != null;
      case question2Index:
        return _onboardingData.useCase != null;
      case question3Index:
        return _onboardingData.audioQuality != null;
      case question4Index:
        return _onboardingData.aiAutopilot != null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          body: AnimatedBackground(
            style: settingsProvider.settings.backgroundStyle,
            themeConfig: settingsProvider.currentThemeConfig,
            isSimpleMode: false, // Always show fancy onboarding
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar with progress
                  _buildTopBar(settingsProvider),

                  // PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: [
                        _buildVideoPage(),
                        _buildRecordExplainPage(),
                        _buildBeautifyExplainPage(),
                        _buildOrganizeExplainPage(),
                        _buildThemeSelectorPage(),
                        _buildQuestion1(), // Where heard about us
                        _buildQuestion2(), // Use case
                        _buildQuestion3(), // Audio quality
                        _buildQuestion4(), // AI Autonomy
                        _buildInterstitial1(), // Privacy
                        _buildRatingScreen(),
                        _buildLoadingScreen(),
                        _buildCompletionScreen(),
                      ],
                    ),
                  ),
                  
                  // Bottom button (hidden on loading and completion screens)
                  if (_currentPage != loadingIndex && _currentPage != completionIndex)
                    _buildBottomButton(settingsProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(SettingsProvider settingsProvider) {
    // Only show language selector on video page
    if (_currentPage == videoPageIndex) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48), // Balance for language selector
            const Spacer(),
            const LanguageSelector(showPulseAnimation: true),
          ],
        ),
      );
    }
    
    // Show progress indicator for question pages
    if (_currentPage >= question1Index && _currentPage <= question4Index) {
      final questionNumber = _getQuestionNumber(_currentPage);
      final totalQuestions = 4;
      
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            Text(
              'Question $questionNumber of $totalQuestions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: LinearProgressIndicator(
                value: questionNumber / totalQuestions,
                backgroundColor: settingsProvider.currentThemeConfig.primary
                    .withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  settingsProvider.currentThemeConfig.primary,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  int _getQuestionNumber(int pageIndex) {
    if (pageIndex == question1Index) return 1;
    if (pageIndex == question2Index) return 2;
    if (pageIndex == question3Index) return 3;
    if (pageIndex == question4Index) return 4;
    return 0;
  }

  Widget _buildBottomButton(SettingsProvider settingsProvider) {
    final localization = LocalizationService();
    String buttonText = localization.t('onboarding_continue');
    
    if (_currentPage == videoPageIndex) {
      buttonText = localization.t('onboarding_get_started');
    } else if (_currentPage == ratingIndex) {
      buttonText = localization.t('rating_skip');
    }
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: GestureDetector(
        onTap: _canProceed() ? _nextPage : null,
        child: AnimatedOpacity(
          opacity: _canProceed() ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  settingsProvider.currentThemeConfig.primary,
                  settingsProvider.currentThemeConfig.primary
                      .withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: _canProceed()
                  ? [
                      BoxShadow(
                        color: settingsProvider.currentThemeConfig.primary
                            .withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                buttonText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(
                delay: 1000.ms,
                duration: 2000.ms,
                color: Colors.white.withValues(alpha: 0.3),
              ),
        ),
      ),
    );
  }

  // Video Page
  Widget _buildVideoPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isSmallScreen = availableHeight < 700;
            final screenWidth = MediaQuery.of(context).size.width;
            
            // Calculate max video height to prevent overflow
            // Leave room for: top spacing (16) + bottom text (~220) + spacer + button (80)
            final maxVideoHeight = availableHeight - 340;
            final maxVideoWidth = screenWidth - (isSmallScreen ? 40 : 48); // Account for padding
            
            return Column(
              children: [
                SizedBox(height: isSmallScreen ? 8 : 12),
              
              // Video with fly-in/fly-out animation - CONSTRAINED
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 24),
                child: AnimatedSlide(
                  offset: _videoHasFlownOut 
                      ? const Offset(0, -2) 
                      : const Offset(0, 0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInCubic,
                  child: AnimatedScale(
                    scale: _videoHasFlownOut ? 0.85 : 1.0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInCubic,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: maxVideoHeight,
                        maxWidth: maxVideoWidth,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium : AppTheme.radiusXLarge),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium : AppTheme.radiusXLarge),
                            border: Border.all(
                              color: settingsProvider.currentThemeConfig.primary
                                  .withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: settingsProvider.currentThemeConfig.primary
                                    .withValues(alpha: _videoHasFlownOut ? 0.1 : 0.3),
                                blurRadius: isSmallScreen ? 15 : 30,
                                spreadRadius: isSmallScreen ? 2 : 5,
                              ),
                            ],
                          ),
                          child: _isVideoInitialized && _videoController != null
                              ? AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!),
                                )
                              : AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.2),
                                          settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.05),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.mic_rounded,
                                        size: isSmallScreen ? 50 : 80,
                                        color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 800.ms)
                          .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic)
                          .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
                
              // Main hook text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: isSmallScreen ? 24 : (availableHeight < 800 ? 28 : 36),
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ) ?? const TextStyle(),
                    children: _buildAnimatedTextSpans(
                      localization.t('onboarding_subtitle'),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1200.ms, duration: 800.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
              
              SizedBox(height: isSmallScreen ? 8 : 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
                child: Text(
                  localization.t('onboarding_sub_subtitle'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
                    .animate()
                    .fadeIn(delay: 1800.ms, duration: 600.ms),
              ),
              
              const Spacer(),
              ],
            );
          },
        );
      },
    );
  }

  List<TextSpan> _buildAnimatedTextSpans(String text) {
    // Replace \n with actual newlines and split into words while preserving line breaks
    final lines = text.split('\n');
    final List<TextSpan> spans = [];
    
    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final words = lines[lineIndex].split(' ');
      for (final word in words) {
        if (word.isNotEmpty) {
          spans.add(TextSpan(text: '$word '));
        }
      }
      // Add line break if not the last line
      if (lineIndex < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return spans;
  }

  // Record Explanation Page - "Just Tap & Speak"
  Widget _buildRecordExplainPage() {
    return _buildExplanationPageWithScreenshot(
      screenshotPath: 'assets/onboarding/screenshots/recording_active.png',
      title: LocalizationService().t('onboarding_record_title'),
      benefits: [
        LocalizationService().t('onboarding_record_benefit_1'),
        LocalizationService().t('onboarding_record_benefit_2'),
        LocalizationService().t('onboarding_record_benefit_3'),
      ],
    );
  }

  // Beautify Explanation Page - "AI Beautifies Your Words"
  Widget _buildBeautifyExplainPage() {
    return _buildExplanationPageWithScreenshot(
      screenshotPath: 'assets/onboarding/screenshots/note_detail_organized.png',
      title: LocalizationService().t('onboarding_beautify_title'),
      benefits: [
        LocalizationService().t('onboarding_beautify_benefit_1'),
        LocalizationService().t('onboarding_beautify_benefit_2'),
        LocalizationService().t('onboarding_beautify_benefit_3'),
      ],
    );
  }

  // Organize Explanation Page - "AI Organizes Everything"
  Widget _buildOrganizeExplainPage() {
    return _buildExplanationPageWithScreenshot(
      screenshotPath: 'assets/onboarding/screenshots/home_with_notes.png',
      title: LocalizationService().t('onboarding_organize_title'),
      benefits: [
        LocalizationService().t('onboarding_organize_benefit_1'),
        LocalizationService().t('onboarding_organize_benefit_2'),
        LocalizationService().t('onboarding_organize_benefit_3'),
      ],
    );
  }

  // Explanation page with screenshot
  Widget _buildExplanationPageWithScreenshot({
    required String screenshotPath,
    required String title,
    required List<String> benefits,
  }) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        final theme = settingsProvider.currentThemeConfig;
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? availableHeight * 0.04 : availableHeight * 0.08),
              
              // Screenshot
              OnboardingScreenshot(
                screenshotPath: screenshotPath,
                animationDelay: 200,
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.04 : availableHeight * 0.06),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: isSmallScreen ? 22 : 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.04),
              
              // Benefits
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? AppTheme.spacing24 : AppTheme.spacing32,
                ),
                child: Column(
                  children: benefits.asMap().entries.map((entry) {
                    final index = entry.key;
                    final benefit = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              benefit,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.5,
                                    fontSize: isSmallScreen ? 15 : 17,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 800 + (index * 150)),
                          duration: 600.ms,
                        )
                        .slideX(begin: -0.2, end: 0);
                  }).toList(),
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 12 : 24),
            ],
          ),
        );
      },
    );
  }

  // Theme Selector Page
  Widget _buildThemeSelectorPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        final localization = LocalizationService();
        
        return Column(
          children: [
            SizedBox(height: isSmallScreen ? availableHeight * 0.06 : availableHeight * 0.1),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Text(
                localization.t('onboarding_theme_title'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: isSmallScreen ? 24 : 32,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
              child: Text(
                localization.t('onboarding_theme_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: isSmallScreen ? 13 : 15,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),
            ),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.03 : availableHeight * 0.05),
            
            // Live preview area - animates when theme changes
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              height: isSmallScreen ? availableHeight * 0.2 : availableHeight * 0.25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                gradient: settingsProvider.currentThemeConfig.backgroundGradient,
                border: Border.all(
                  color: AppTheme.glassBorder.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.palette_rounded,
                  size: isSmallScreen ? 45 : 60,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 600.ms, duration: 800.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.03 : availableHeight * 0.04),
            
            // Theme selector (horizontally scrollable)
            SizedBox(
              height: isSmallScreen ? 80 : 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                itemCount: ThemePreset.values.length,
                itemBuilder: (context, index) {
                  final theme = ThemePreset.values[index];
                  final themeConfig = AppTheme.getThemeConfig(theme);
                  final isSelected = settingsProvider.settings.themePreset == theme;
                  
                  return GestureDetector(
                    onTap: () async {
                      await HapticService.light();
                      await settingsProvider.updateThemePreset(theme);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: isSmallScreen ? 70 : 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        gradient: themeConfig.backgroundGradient,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: themeConfig.primary.withValues(alpha: 0.5),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: isSmallScreen ? 28 : 32,
                            )
                          : null,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 800 + (index * 100)),
                        duration: 400.ms,
                      )
                      .slideX(begin: 0.3, end: 0);
                },
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 24),
          ],
        );
      },
    );
  }

  // Question 1: Where did you hear about us?
  Widget _buildQuestion1() {
    final localization = LocalizationService();
    return _buildQuestionPage(
      title: localization.t('onboarding_question_1_title'),
      options: [
        (
          emoji: '📱',
          title: localization.t('onboarding_question_1_option_1'),
          subtitle: localization.t('onboarding_question_1_option_1_sub'),
          value: 'social_media',
        ),
        (
          emoji: '👥',
          title: localization.t('onboarding_question_1_option_2'),
          subtitle: localization.t('onboarding_question_1_option_2_sub'),
          value: 'friend',
        ),
        (
          emoji: '🏪',
          title: localization.t('onboarding_question_1_option_3'),
          subtitle: localization.t('onboarding_question_1_option_3_sub'),
          value: 'app_store',
        ),
        (
          emoji: '🎥',
          title: localization.t('onboarding_question_1_option_4'),
          subtitle: localization.t('onboarding_question_1_option_4_sub'),
          value: 'youtube',
        ),
        (
          emoji: '💬',
          title: localization.t('onboarding_question_1_option_5'),
          subtitle: localization.t('onboarding_question_1_option_5_sub'),
          value: 'reddit',
        ),
        (
          emoji: '🔍',
          title: localization.t('onboarding_question_1_option_6'),
          subtitle: localization.t('onboarding_question_1_option_6_sub'),
          value: 'google',
        ),
        (
          emoji: '✨',
          title: localization.t('onboarding_question_1_option_7'),
          subtitle: localization.t('onboarding_question_1_option_7_sub'),
          value: 'other',
        ),
      ],
      selectedValue: _onboardingData.hearAboutUs,
      onSelect: (value) => setState(() => _onboardingData.hearAboutUs = value as String),
    );
  }

  // Question 2: Use case
  Widget _buildQuestion2() {
    final localization = LocalizationService();
    return _buildQuestionPage(
      title: localization.t('onboarding_question_5_title'),
      options: [
        (
          emoji: '💼',
          title: localization.t('onboarding_question_5_option_1'),
          subtitle: localization.t('onboarding_question_5_option_1_sub'),
          value: 'work',
        ),
        (
          emoji: '📚',
          title: localization.t('onboarding_question_5_option_2'),
          subtitle: localization.t('onboarding_question_5_option_2_sub'),
          value: 'learning',
        ),
        (
          emoji: '💭',
          title: localization.t('onboarding_question_5_option_3'),
          subtitle: localization.t('onboarding_question_5_option_3_sub'),
          value: 'journal',
        ),
        (
          emoji: '🎨',
          title: localization.t('onboarding_question_5_option_4'),
          subtitle: localization.t('onboarding_question_5_option_4_sub'),
          value: 'creative',
        ),
      ],
      selectedValue: _onboardingData.useCase,
      onSelect: (value) => setState(() => _onboardingData.useCase = value as String),
    );
  }

  // Question 3: Audio quality
  Widget _buildQuestion3() {
    final localization = LocalizationService();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    return _buildQuestionPage(
      title: localization.t('onboarding_question_6_title'),
      subtitle: localization.t('onboarding_question_6_subtitle', {
        'language': settingsProvider.preferredLanguage.name,
      }),
      options: [
        (
          emoji: '⚡',
          title: localization.t('onboarding_question_6_option_1'),
          subtitle: localization.t('onboarding_question_6_option_1_sub'),
          value: AudioQuality.low,
        ),
        (
          emoji: '🎯',
          title: localization.t('onboarding_question_6_option_2'),
          subtitle: localization.t('onboarding_question_6_option_2_sub'),
          value: AudioQuality.medium,
        ),
        (
          emoji: '💎',
          title: localization.t('onboarding_question_6_option_3'),
          subtitle: localization.t('onboarding_question_6_option_3_sub'),
          value: AudioQuality.high,
        ),
      ],
      selectedValue: _onboardingData.audioQuality,
      onSelect: (value) => setState(() => _onboardingData.audioQuality = value as AudioQuality),
    );
  }

  // Question 4: AI Autonomy Level
  Widget _buildQuestion4() {
    final localization = LocalizationService();
    return _buildQuestionPage(
      title: localization.t('onboarding_question_7_title'),
      subtitle: localization.t('onboarding_question_7_subtitle'),
      options: [
        (
          emoji: '🚀',
          title: localization.t('onboarding_question_7_option_1'),
          subtitle: localization.t('onboarding_question_7_option_1_sub'),
          value: true, // true = autopilot
        ),
        (
          emoji: '🎯',
          title: localization.t('onboarding_question_7_option_2'),
          subtitle: localization.t('onboarding_question_7_option_2_sub'),
          value: false, // false = hybrid/assisted
        ),
      ],
      selectedValue: _onboardingData.aiAutopilot,
      onSelect: (value) => setState(() => _onboardingData.aiAutopilot = value as bool),
    );
  }

  // Interstitial 1: Privacy & Security
  Widget _buildInterstitial1() {
    final localization = LocalizationService();
    return OnboardingInterstitial(
      icon: Icons.shield_rounded,
      title: localization.t('interstitial_privacy_title'),
      message: localization.t('interstitial_privacy_message'),
      features: [
        localization.t('interstitial_privacy_feature_1'),
        localization.t('interstitial_privacy_feature_2'),
        localization.t('interstitial_privacy_feature_3'),
      ],
    );
  }

  // Rating screen
  Widget _buildRatingScreen() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        
        // Trigger native rating prompt on appearance (only once)
        if (!_hasShownRatingPrompt) {
          _hasShownRatingPrompt = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNativeRatingPrompt();
          });
        }
        
        return Column(
          children: [
            SizedBox(height: isSmallScreen ? availableHeight * 0.15 : availableHeight * 0.2),
              
              // Star icon
              Container(
                width: isSmallScreen ? 100 : 120,
                height: isSmallScreen ? 100 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      settingsProvider.currentThemeConfig.accentColor,
                      settingsProvider.currentThemeConfig.accentColor.withValues(alpha: 0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: settingsProvider.currentThemeConfig.accentColor.withValues(alpha: 0.4),
                      blurRadius: isSmallScreen ? 25 : 40,
                      spreadRadius: isSmallScreen ? 5 : 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.star,
                  size: isSmallScreen ? 50 : 60,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.04 : availableHeight * 0.06),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Text(
                localization.t('rating_title'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
            ),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.03),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
              child: Text(
                localization.t('rating_message'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms),
            ),
            
            const Spacer(),
          ],
        );
      },
    );
  }

  Future<void> _showNativeRatingPrompt() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      
      if (await inAppReview.isAvailable()) {
        await Future.delayed(const Duration(milliseconds: 500));
        await inAppReview.requestReview();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error showing native rating prompt: $e');
      }
    }
  }

  // Loading screen
  Widget _buildLoadingScreen() {
    return CustomizationLoading(
      onComplete: () {
        if (mounted) {
          _nextPage();
        }
      },
    );
  }

  // Completion screen - Redesigned
  Widget _buildCompletionScreen() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final localization = LocalizationService();
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        final theme = settingsProvider.currentThemeConfig;
        
        return Column(
          children: [
            SizedBox(height: isSmallScreen ? availableHeight * 0.1 : availableHeight * 0.15),
            
            // Animated sequence: Microphone → Waveform → Organized Note
            SizedBox(
              height: isSmallScreen ? availableHeight * 0.25 : availableHeight * 0.3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background glow
                  Container(
                    width: isSmallScreen ? 150 : 200,
                    height: isSmallScreen ? 150 : 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          theme.primary.withValues(alpha: 0.3),
                          theme.primary.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: 2000.ms,
                      ),
                  
                  // Microphone icon
                  Icon(
                    Icons.mic_rounded,
                    size: isSmallScreen ? 60 : 80,
                    color: theme.primary,
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                      )
                      .then(delay: 500.ms)
                      .fadeOut(duration: 600.ms)
                      .scale(end: const Offset(0.5, 0.5)),
                  
                  // Waveform icon (appears after mic)
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: isSmallScreen ? 60 : 80,
                    color: theme.primary,
                  )
                      .animate()
                      .fadeIn(delay: 1900.ms, duration: 600.ms)
                      .scale(
                        delay: 1900.ms,
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                      )
                      .then(delay: 500.ms)
                      .fadeOut(duration: 600.ms)
                      .scale(end: const Offset(0.5, 0.5)),
                  
                  // Check mark (organized note - appears last)
                  Icon(
                    Icons.check_circle_rounded,
                    size: isSmallScreen ? 60 : 80,
                    color: theme.primary,
                  )
                      .animate()
                      .fadeIn(delay: 3000.ms, duration: 800.ms)
                      .scale(
                        delay: 3000.ms,
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        curve: Curves.elasticOut,
                      ),
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.04 : availableHeight * 0.06),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Text(
                localization.t('completion_title'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: isSmallScreen ? 24 : 28,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
                  .animate()
                  .fadeIn(delay: 3800.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
            ),
            
            SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.03),
            
            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
              child: Text(
                localization.t('completion_subtitle'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: isSmallScreen ? 15 : 17,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
                  .animate()
                  .fadeIn(delay: 4000.ms, duration: 600.ms),
            ),
            
            const Spacer(),
            
            // CTA Button
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? AppTheme.spacing16 : AppTheme.spacing24),
              child: GestureDetector(
                onTap: () async {
                  await HapticService.success();
                  await _completeOnboarding();
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primary,
                        theme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      localization.t('completion_cta'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .shimmer(
                      delay: 4200.ms,
                      duration: 2000.ms,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
              )
                  .animate()
                  .fadeIn(delay: 4200.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
            ),
          ],
        );
      },
    );
  }

  // Generic question page builder - Non-scrollable with scrollable options list
  Widget _buildQuestionPage({
    required String title,
    String? subtitle,
    required List<({String emoji, String title, String subtitle, Object value})> options,
    required Object? selectedValue,
    required Function(Object) onSelect,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isSmallScreen = availableHeight < 700;
        final headerHeight = isSmallScreen ? availableHeight * 0.2 : availableHeight * 0.25;
        final optionsHeight = isSmallScreen ? availableHeight * 0.8 : availableHeight * 0.75;
        
        return Column(
          children: [
            // Fixed header section
            SizedBox(
              height: headerHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: isSmallScreen ? 22 : 26,
                            height: 1.15,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),
                  ),
                  
                  if (subtitle != null) ...[
                    SizedBox(height: isSmallScreen ? 6 : 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textTertiary,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 600.ms),
                    ),
                  ],
                ],
              ),
            ),
            
            // Scrollable options section
            SizedBox(
              height: optionsHeight,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return OnboardingQuestionCard(
                    emoji: option.emoji,
                    title: option.title,
                    subtitle: option.subtitle,
                    isSelected: selectedValue == option.value,
                    onTap: () => onSelect(option.value),
                    animationDelay: index * 100,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

