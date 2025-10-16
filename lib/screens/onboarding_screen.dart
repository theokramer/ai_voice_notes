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
import '../widgets/onboarding_interstitial.dart';
import '../widgets/customization_loading.dart';

/// Professional onboarding flow optimized for maximum conversion
/// Flow: Video → Record+Voice Commands → Beautify → Organize → Theme Selector →
///       Question 1 (Source) → Question 2 (Use Case) → Personalized Time Savings → 
///       Privacy Interstitial → Benefits → Rating → Loading + Mic Permission → Completion → Paywall
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
  bool _isNavigating = false; // Prevents button spam
  bool _isAnimationComplete = true; // Tracks if page animations are complete

  // Page indices (only those used for logic are defined as constants)
  static const int videoPageIndex = 0;
  static const int question1Index = 4;  // Where heard (no AI response after)
  static const int question2Index = 5;  // Use case
  static const int question3Index = 7;  // Transcription quality
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
        'assets/onboarding/videos/video_onboarding.mp4',
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
      
      // When video ends, reset and restart after fly-out animation completes
      if (duration.inSeconds > 0 && 
          position.inSeconds >= duration.inSeconds &&
          _videoHasFlownOut) {
        // Wait for fly-out animation to complete (300ms), then reset - reduced from 600ms
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _videoController != null) {
            setState(() {
              _videoHasFlownOut = false;
            });
            _videoController!.seekTo(Duration.zero);
            _videoController!.play();
          }
        });
      }
    }
  }

  Future<void> _initializeLanguage() async {
    try {
      if (!mounted) return;
      
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Set English as default language if not already set
      if (settingsProvider.settings.preferredLanguage == null) {
        await settingsProvider.updatePreferredLanguage(AppLanguage.english);
        LocalizationService().setLanguage(AppLanguage.english);
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
    // Prevent spam clicking
    if (_isNavigating) return;
    
    debugPrint('🔍 ONBOARDING DEBUG: _nextPage() called');
    debugPrint('🔍 Current page: $_currentPage');
    debugPrint('🔍 Total pages: $totalPages');
    debugPrint('🔍 Can advance: ${_currentPage < totalPages - 1}');
    
    setState(() => _isNavigating = true);
    await HapticService.medium();
    
    if (_currentPage < totalPages - 1) {
      debugPrint('🔍 Advancing from page $_currentPage to ${_currentPage + 1}');
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      
      // Re-enable navigation after animation completes
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _isNavigating = false);
        }
      });
    } else {
      debugPrint('🔍 Already at last page, not advancing');
      setState(() => _isNavigating = false);
    }
  }

  /// Complete onboarding and launch paywall flow
  Future<void> _completeOnboarding() async {
    try {
      // Save onboarding data
      await _onboardingData.save();
      
      // Apply settings
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Default to medium audio quality if not set
      await settingsProvider.updateAudioQuality(
        _onboardingData.audioQuality ?? AudioQuality.medium
      );
      
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
      case 1: // Record + Voice Commands explanation page
      case 2: // Beautify explanation page
      case 3: // Organize explanation page
        return _isAnimationComplete; // Only allow proceeding after animations complete
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
            themeConfig: settingsProvider.currentThemeConfig,
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
                        debugPrint('🔍 ONBOARDING DEBUG: Page changed to $index');
                        setState(() {
                          _currentPage = index;
                          _isAnimationComplete = false; // Reset animation state
                        });
                        
                        // Set animation complete after appropriate delay for explanation pages
                        if (index >= 1 && index <= 3) {
                          Future.delayed(const Duration(milliseconds: 1800), () {
                            if (mounted) {
                              setState(() => _isAnimationComplete = true);
                            }
                          });
                        } else {
                          // For other pages, animations complete immediately
                          setState(() => _isAnimationComplete = true);
                        }
                      },
                      children: [
                        _buildVideoPage(),
                        _buildRecordVoiceExplainPage(), // MERGED: Record + Voice Commands
                        _buildBeautifyExplainPage(),
                        _buildChatExplainPage(),
                        _buildQuestion1(), // Where heard about us
                        _buildQuestion2(), // Use case
                        _buildAIHelpsPage(), // Personalized time-saving page
                        _buildQuestion3(), // Transcription quality
                        _buildInterstitial1(), // Privacy
                        _buildBenefitsScreen(), // "What You'll Get"
                        _buildRatingScreen(),
                        _buildLoadingScreen(),
                        _buildCompletionScreen(),
                      ],
                    ),
                  ),
                  
                  // Bottom button (hidden on loading and completion screens)
                  if (_currentPage != loadingIndex && 
                      _currentPage != completionIndex)
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
    // Show progress indicator from first screenshot page through loading screen
    if (_shouldShowProgress()) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          children: [
            // Back button (if not first page)
            if (_currentPage > 0)
              GestureDetector(
                onTap: _isNavigating ? null : _previousPage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 24,
                    color: settingsProvider.currentThemeConfig.primary,
                  ),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 8),
            // Progress bar (expanded)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _getProgress(),
                  backgroundColor: settingsProvider.currentThemeConfig.primary
                      .withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    settingsProvider.currentThemeConfig.primary,
                  ),
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  double _getProgress() {
    if (_currentPage == 0 || _currentPage >= loadingIndex) {
      return 0.0; // Hide progress
    }
    return _currentPage / (loadingIndex - 1);
  }

  bool _shouldShowProgress() {
    return _currentPage > 0 && _currentPage < completionIndex;
  }

  void _previousPage() async {
    if (_isNavigating || _currentPage == 0) return;
    
    setState(() => _isNavigating = true);
    await HapticService.light();
    
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  Widget _buildBottomButton(SettingsProvider settingsProvider) {
    final localization = LocalizationService();
    final availableHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = availableHeight < 700;
    String buttonText = localization.t('onboarding_continue');
    
    if (_currentPage == videoPageIndex) {
      buttonText = localization.t('onboarding_get_started');
    } else if (_currentPage == ratingIndex) {
      buttonText = localization.t('rating_skip');
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, AppTheme.spacing24, AppTheme.spacing24, 32),
      child: Column(
        children: [
          // Main hook text above button
          if (_currentPage == videoPageIndex)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: isSmallScreen ? 24 : (availableHeight < 800 ? 28 : 36),
                        height: 1.3,
                        fontWeight: FontWeight.w700,
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
          
          // Button
          GestureDetector(
            onTap: (_canProceed() && !_isNavigating) ? () {
              debugPrint('🔍 ONBOARDING DEBUG: Bottom button tapped on page $_currentPage');
              _nextPage();
            } : null,
            child: AnimatedOpacity(
              opacity: (_canProceed() && !_isNavigating) ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: double.infinity,
                height: 64,
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
                  boxShadow: (_canProceed() && !_isNavigating)
                      ? [
                          BoxShadow(
                            color: settingsProvider.currentThemeConfig.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
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
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(
                delay: 1000.ms,
                duration: 2000.ms,
                color: Colors.white.withValues(alpha: 0.3),
              ),
        ],
      ),
    );
  }

  // Video Page
  Widget _buildVideoPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final isSmallScreen = availableHeight < 700;
            final screenWidth = MediaQuery.of(context).size.width;
            
            // Calculate max video height to prevent overflow
            // Leave room for: top spacing (16) + bottom text (~120) + spacer + button (80)
            // Increased video size to ensure border radius is visible and not cropped
            final maxVideoHeight = availableHeight - 180; // Increased for bigger video with visible border radius
            final maxVideoWidth = screenWidth - (isSmallScreen ? 24 : 32); // Reduced padding for bigger video
            
            return Column(
              children: [
                SizedBox(height: isSmallScreen ? 20 : 30),
              
              // Video with original slide-up animation - CONSTRAINED
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
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
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: maxVideoHeight,
                        maxWidth: maxVideoWidth,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium : AppTheme.radiusXLarge),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: settingsProvider.currentThemeConfig.primary
                                  .withValues(alpha: _videoHasFlownOut ? 0.05 : 0.15),
                              blurRadius: isSmallScreen ? 8 : 15,
                              spreadRadius: isSmallScreen ? 1 : 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isSmallScreen ? AppTheme.radiusMedium - 2 : AppTheme.radiusXLarge - 2),
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
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 800.ms)
                    .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic)
                    .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
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

  // MERGED: Record + Voice Commands Explanation Page
  Widget _buildRecordVoiceExplainPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        final theme = settingsProvider.currentThemeConfig;
        final localization = LocalizationService();
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? availableHeight * 0.01 : availableHeight * 0.02),
              
              // Screenshot
              OnboardingScreenshot(
                screenshotPath: 'assets/onboarding/screenshots/recording_active.png',
                animationDelay: 200,
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.03),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: Text(
                  localization.t('onboarding_record_voice_title'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: isSmallScreen ? 22 : 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.03),
              
              // Main benefits (3 bullets)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? AppTheme.spacing24 : AppTheme.spacing32,
                ),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      context,
                      localization.t('onboarding_record_voice_benefit_1'),
                      theme.primary,
                      0,
                      isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 12),
                    _buildBenefitRow(
                      context,
                      localization.t('onboarding_record_voice_benefit_2'),
                      theme.primary,
                      1,
                      isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 12),
                    _buildBenefitRow(
                      context,
                      localization.t('onboarding_record_voice_benefit_3'),
                      theme.primary,
                      2,
                      isSmallScreen,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 12 : 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefitRow(
    BuildContext context,
    String benefit,
    Color primaryColor,
    int index,
    bool isSmallScreen,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            benefit,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 800 + (index * 150)),
          duration: 600.ms,
        )
        .slideX(begin: -0.2, end: 0);
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

  // Chat Explanation Page - "Chat with Your Notes"
  Widget _buildChatExplainPage() {
    return _buildExplanationPageWithScreenshot(
      screenshotPath: 'assets/onboarding/screenshots/note_selection.png',
      title: LocalizationService().t('onboarding_chat_title'),
      benefits: [
        LocalizationService().t('onboarding_chat_benefit_1'),
        LocalizationService().t('onboarding_chat_benefit_2'),
        LocalizationService().t('onboarding_chat_benefit_3'),
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
              SizedBox(height: isSmallScreen ? availableHeight * 0.01 : availableHeight * 0.02),
              
              // Screenshot
              OnboardingScreenshot(
                screenshotPath: screenshotPath,
                animationDelay: 200,
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.02 : availableHeight * 0.03),
              
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
                            width: 4,
                            height: 4,
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
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w500,
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
        (
          emoji: '✨',
          title: localization.t('onboarding_question_5_option_5'),
          subtitle: localization.t('onboarding_question_5_option_5_sub'),
          value: 'other',
        ),
      ],
      selectedValue: _onboardingData.useCase,
      onSelect: (value) {
        debugPrint('🔍 ONBOARDING DEBUG: Question 2 answered with: $value');
        setState(() => _onboardingData.useCase = value as String);
      },
    );
  }

  // Question 3: Transcription Quality
  Widget _buildQuestion3() {
    final localization = LocalizationService();
    return _buildQuestionPage(
      title: localization.t('onboarding_question_audio_quality_title'),
      options: [
        (
          emoji: '🚀',
          title: localization.t('onboarding_question_audio_quality_option_1'),
          subtitle: localization.t('onboarding_question_audio_quality_option_1_sub'),
          value: AudioQuality.high,
        ),
        (
          emoji: '⚡',
          title: localization.t('onboarding_question_audio_quality_option_2'),
          subtitle: localization.t('onboarding_question_audio_quality_option_2_sub'),
          value: AudioQuality.medium,
        ),
        (
          emoji: '💨',
          title: localization.t('onboarding_question_audio_quality_option_3'),
          subtitle: localization.t('onboarding_question_audio_quality_option_3_sub'),
          value: AudioQuality.low,
        ),
      ],
      selectedValue: _onboardingData.audioQuality,
      onSelect: (value) {
        debugPrint('🔍 ONBOARDING DEBUG: Question 3 answered with: $value');
        setState(() => _onboardingData.audioQuality = value as AudioQuality);
      },
    );
  }

  // Stunning personalized time savings page with chart
  Widget _buildAIHelpsPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
    final localization = LocalizationService();
        final screenSize = MediaQuery.of(context).size;
        final availableHeight = screenSize.height;
        final isSmallScreen = availableHeight < 700;
        final theme = settingsProvider.currentThemeConfig;
        
        // Get personalized content based on user's use case
        final useCase = _onboardingData.useCase ?? 'default';
        final title = localization.t('time_savings_${useCase}_title');
        final subtitle = localization.t('time_savings_${useCase}_subtitle');
        final statLabel = localization.t('time_savings_${useCase}_stat');
        
        return Container(
          width: screenSize.width,
          height: screenSize.height,
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: isSmallScreen ? availableHeight * 0.06 : availableHeight * 0.08,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              
              // Title - Reduced size
              Text(
                title,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: isSmallScreen ? 28 : 34,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
              
              SizedBox(height: isSmallScreen ? 8 : 12),
              
              // Subtitle - Reduced size
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),
              
              const Spacer(flex: 2),
              
              // Time comparison chart
              _buildTimeComparisonChart(
                context,
                theme,
                statLabel,
                isSmallScreen,
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildTimeComparisonChart(
    BuildContext context,
    dynamic theme,
    String statLabel,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? AppTheme.spacing16 : AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primary.withValues(alpha: 0.08),
            theme.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Chart title - Smaller
          Text(
            'Time spent on $statLabel',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Before - Tall bar (45 min)
              _buildTimeBar(
                context,
                'Without\nNotie AI',
                1.0,
                '45 min',
                const Color(0xFF4A4A4A),
                theme,
                isSmallScreen,
                600,
              ),
              
              // After - Short bar (10 min)
              _buildTimeBar(
                context,
                'With\nNotie AI',
                0.22,
                '10 min',
                const Color(0xFF00FF88),
                theme,
                isSmallScreen,
                900,
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Speed indicator and savings
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? AppTheme.spacing12 : AppTheme.spacing16,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  color: theme.primary,
                  size: isSmallScreen ? 16 : 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '4.5x faster · Save 35 min',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: theme.primary,
                      ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 1200.ms, duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }
  
  Widget _buildTimeBar(
    BuildContext context,
    String label,
    double heightFactor,
    String timeAmount,
    Color barColor,
    dynamic theme,
    bool isSmallScreen,
    int delay,
  ) {
    final maxHeight = isSmallScreen ? 100.0 : 120.0;
    final barHeight = maxHeight * heightFactor;
    
    return Column(
      children: [
        // Time amount above bar
        Text(
          timeAmount,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
        )
            .animate()
            .fadeIn(delay: (delay + 200).ms, duration: 400.ms),
        
        const SizedBox(height: 12),
        
        // Bar container
        Container(
          width: isSmallScreen ? 60 : 75,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                barColor,
                barColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24), // Very rounded corners
            boxShadow: [
              BoxShadow(
                color: barColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: delay.ms, duration: 800.ms)
            .scaleY(
              begin: 0.0,
              end: 1.0,
              alignment: Alignment.bottomCenter,
              curve: Curves.elasticOut,
            ),
        
        const SizedBox(height: 8),
        
        // Label below bar
        SizedBox(
          width: isSmallScreen ? 60 : 75,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: isSmallScreen ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  height: 1.2,
                ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(delay: (delay + 300).ms, duration: 400.ms),
      ],
    );
  }
  
  // Benefits Screen: "What You'll Get"
  Widget _buildBenefitsScreen() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
    final localization = LocalizationService();
        final availableHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = availableHeight < 700;
        final theme = settingsProvider.currentThemeConfig;
        
        final benefits = [
          (
            emoji: '⚡',
            title: localization.t('benefit_1_title'),
            subtitle: localization.t('benefit_1_subtitle'),
          ),
          (
            emoji: '🧠',
            title: localization.t('benefit_2_title'),
            subtitle: localization.t('benefit_2_subtitle'),
          ),
          (
            emoji: '🔍',
            title: localization.t('benefit_3_title'),
            subtitle: localization.t('benefit_3_subtitle'),
          ),
          (
            emoji: '✨',
            title: localization.t('benefit_4_title'),
            subtitle: localization.t('benefit_4_subtitle'),
          ),
          (
            emoji: '🔒',
            title: localization.t('benefit_5_title'),
            subtitle: localization.t('benefit_5_subtitle'),
          ),
        ];
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? availableHeight * 0.06 : availableHeight * 0.08),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: Text(
                  localization.t('benefits_screen_title'),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: isSmallScreen ? 28 : 34,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
              ),
              
              SizedBox(height: isSmallScreen ? availableHeight * 0.04 : availableHeight * 0.06),
              
              // Benefits list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                child: Column(
                  children: benefits.asMap().entries.map((entry) {
                    final index = entry.key;
                    final benefit = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                      child: _buildBenefitCard(
                        context,
                        benefit.emoji,
                        benefit.title,
                        benefit.subtitle,
                        theme.primary,
                        index,
                        isSmallScreen,
                      ),
                    );
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
  
  Widget _buildBenefitCard(
    BuildContext context,
    String emoji,
    String title,
    String subtitle,
    Color primaryColor,
    int index,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? AppTheme.spacing16 : AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.glassStrongSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji container
          Container(
            width: isSmallScreen ? 48 : 56,
            height: isSmallScreen ? 48 : 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.2),
                  primaryColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: isSmallScreen ? 24 : 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: isSmallScreen ? 13 : 14,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 400 + (index * 100)),
          duration: 600.ms,
        )
        .slideX(begin: 0.2, end: 0);
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
      showLegalFooter: true, // Show Privacy Policy & Terms links
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
                onTap: _isNavigating ? null : () async {
                  if (_isNavigating) return;
                  setState(() => _isNavigating = true);
                  await HapticService.success();
                  await _completeOnboarding();
                  // No need to reset _isNavigating as we're leaving the screen
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

