import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../services/paywall_flow_controller.dart';
import '../providers/settings_provider.dart';
import '../models/onboarding_data.dart';
import '../models/settings.dart';
import '../widgets/onboarding_question_card.dart';
import '../widgets/animated_background.dart';

/// Professional onboarding flow with video, features, questions, and paywall
/// Flow: Video → Features with Screenshots → Questions with Progress → Value Prop → Paywall
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final OnboardingData _onboardingData = OnboardingData();
  
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Total pages: 1 video + 4 features + 4 questions + 1 value prop = 10 pages
  static const int totalPages = 10;
  static const int firstFeatureIndex = 1;
  static const int lastFeatureIndex = 4;
  static const int firstQuestionIndex = 5;
  static const int lastQuestionIndex = 8;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/onboarding/videos/recording_to_note.mp4',
      );
      
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _nextPage() async {
    await HapticService.medium();
    
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Last page - save data and navigate to home
      await _completeOnboarding();
    }
  }

  /// Complete onboarding and launch paywall flow
  Future<void> _completeOnboarding() async {
    try {
      // Save onboarding data
      await _onboardingData.save();
      
      // Apply audio quality setting
      if (_onboardingData.audioQuality != null && mounted) {
        await Provider.of<SettingsProvider>(context, listen: false)
            .updateAudioQuality(_onboardingData.audioQuality!);
      }
      
      // Apply auto-close after entry setting
      if (_onboardingData.autoCloseAfterEntry != null && mounted) {
        await Provider.of<SettingsProvider>(context, listen: false)
            .updateAutoCloseAfterEntry(_onboardingData.autoCloseAfterEntry!);
      }
      
      if (!mounted) return;

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      
      await HapticService.success();
      
      if (!mounted) return;

      // Launch paywall flow
      await PaywallFlowController().showOnboardingPaywallFlow(context);
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      
      // Try to launch paywall flow anyway
      if (mounted) {
        await PaywallFlowController().showOnboardingPaywallFlow(context);
      }
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 5: return _onboardingData.noteFrequency != null;
      case 6: return _onboardingData.useCase != null;
      case 7: return _onboardingData.audioQuality != null;
      case 8: return _onboardingData.autoCloseAfterEntry != null;
      default: return true;
    }
  }

  bool get _isInFeaturePages => _currentPage >= firstFeatureIndex && _currentPage <= lastFeatureIndex;
  bool get _isInQuestionPages => _currentPage >= firstQuestionIndex && _currentPage <= lastQuestionIndex;
  
  int get _questionProgress {
    if (!_isInQuestionPages) return 0;
    return _currentPage - firstQuestionIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          body: AnimatedBackground(
            style: settingsProvider.settings.backgroundStyle,
            themeConfig: settingsProvider.currentThemeConfig,
            child: SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: _buildProgressIndicator(),
                  ),

                  // PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: [
                        // Page 0: Video
                        _buildVideoPage(),
                        
                        // Pages 1-4: Features with Screenshots
                        _buildFeatureWithScreenshot(
                          title: 'Speak Your Thoughts',
                          subtitle: 'Your voice becomes perfectly organized notes',
                          imagePath: 'assets/onboarding/screenshots/recording_active.png',
                          delay: 0,
                        ),
                        _buildFeatureWithScreenshot(
                          title: 'Choose Your Categories',
                          subtitle: 'Organize notes into custom categories',
                          imagePath: 'assets/onboarding/screenshots/note_selection.png',
                          delay: 0,
                        ),
                        _buildFeatureWithScreenshot(
                          title: 'AI-Powered Organization',
                          subtitle: 'Automatic headlines and smart categorization',
                          imagePath: 'assets/onboarding/screenshots/note_detail_organized.png',
                          delay: 0,
                        ),
                        _buildFeatureWithScreenshot(
                          title: 'All Your Notes, Organized',
                          subtitle: 'Access everything instantly with smart search',
                          imagePath: 'assets/onboarding/screenshots/home_with_notes.png',
                          delay: 0,
                        ),
                        
                        // Pages 5-8: Questions
                        _buildQuestionFrequency(),
                        _buildQuestionUseCase(),
                        _buildQuestionAudioQuality(),
                        _buildQuestionAutoClose(),
                        
                        // Page 9: Value Proposition
                        _buildValuePropositionPage(),
                      ],
                    ),
                  ),
                  
                  // Next button
                  Padding(
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
                                settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            boxShadow: _canProceed() 
                              ? [
                                  BoxShadow(
                                    color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                          ),
                          child: Center(
                            child: Text(
                              _currentPage == totalPages - 1 ? 'Get Started' : 'Continue',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  // Progress Indicator
  Widget _buildProgressIndicator() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        if (_isInFeaturePages) {
          // Dots for feature pages
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final pageIndex = firstFeatureIndex + index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: _currentPage == pageIndex ? 24.0 : 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: _currentPage == pageIndex
                      ? settingsProvider.currentThemeConfig.primary
                      : settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              );
            }),
          );
        } else if (_isInQuestionPages) {
          // Progress bar for questions
          return Column(
            children: [
              Text(
                'Question $_questionProgress of 3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: _questionProgress / 3,
                  backgroundColor: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    settingsProvider.currentThemeConfig.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Video Page
  Widget _buildVideoPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppTheme.spacing24),
              
              Text(
                'Welcome to\nAI Voice Notes',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 36,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: AppTheme.spacing16),
              
              Text(
                'Transform your voice into\nperfectly organized notes',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),
              
              const SizedBox(height: AppTheme.spacing48),
              
              // Video player
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    border: Border.all(
                      color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
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
                            color: AppTheme.glassStrongSurface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 800.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              
              const SizedBox(height: AppTheme.spacing32),
              
              // AI wave animations
              _buildAudioWaveAnimation(settingsProvider.currentThemeConfig.primary)
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 600.ms),
            ],
          ),
        );
      },
    );
  }

  // Audio Wave Animation
  Widget _buildAudioWaveAnimation(Color primaryColor) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(20, (index) {
          final delay = index * 50;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleY(
                  begin: 0.3,
                  end: 1.0,
                  duration: Duration(milliseconds: 600 + (index % 5) * 100),
                  delay: Duration(milliseconds: delay),
                  curve: Curves.easeInOut,
                ),
          );
        }),
      ),
    );
  }

  // Feature Pages with Screenshots
  Widget _buildFeatureWithScreenshot({
    required String title,
    required String subtitle,
    required String imagePath,
    required int delay,
  }) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppTheme.spacing24),
              
              // Title
              Text(
                title,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 32,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: AppTheme.spacing16),
              
              // Subtitle
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms),
              
              const SizedBox(height: AppTheme.spacing48),
              
              // Screenshot
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    border: Border.all(
                      color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge - 2),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 400,
                          color: AppTheme.glassStrongSurface,
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 80,
                              color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 800.ms)
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              
              const SizedBox(height: AppTheme.spacing32),
              
              // AI indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: settingsProvider.currentThemeConfig.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      'Powered by AI',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: settingsProvider.currentThemeConfig.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),
            ],
          ),
        );
      },
    );
  }

  // Value Proposition Page (Before Paywall)
  Widget _buildValuePropositionPage() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppTheme.spacing24),
              
              // Icon with glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      settingsProvider.currentThemeConfig.primary,
                      settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: settingsProvider.currentThemeConfig.primary.withValues(alpha: 0.5),
                      blurRadius: 50,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stars,
                  size: 60,
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
              
              const SizedBox(height: AppTheme.spacing48),
              
              // Main headline
              Text(
                'Your Thoughts\nDeserve Better',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 40,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: AppTheme.spacing24),
              
              // Subheadline
              Text(
                'Stop losing brilliant ideas to forgotten voice memos. '
                'Start capturing, organizing, and acting on every thought instantly.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.7,
                  fontSize: 17,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 600.ms),
              
              const SizedBox(height: AppTheme.spacing48),
              
              // Value props
              _buildValueProp(
                icon: Icons.flash_on,
                title: '10x Faster',
                description: 'Speak naturally, get organized notes',
                delay: 800,
                primaryColor: settingsProvider.currentThemeConfig.primary,
              ),
              
              _buildValueProp(
                icon: Icons.psychology,
                title: 'AI-Powered',
                description: 'Smart categorization & summaries',
                delay: 950,
                primaryColor: settingsProvider.currentThemeConfig.primary,
              ),
              
              _buildValueProp(
                icon: Icons.workspace_premium,
                title: 'Always Available',
                description: 'Capture ideas anytime, anywhere',
                delay: 1100,
                primaryColor: settingsProvider.currentThemeConfig.primary,
              ),
              
              const SizedBox(height: AppTheme.spacing48),
              
              // Social proof / trust indicator
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                decoration: BoxDecoration(
                  color: AppTheme.glassStrongSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.glassBorder, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => 
                        Icon(
                          Icons.star,
                          color: const Color(0xFFfbbf24),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    Text(
                      'Join thousands of users capturing\ntheir best ideas effortlessly',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 1300.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildValueProp({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.glassStrongSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.glassBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.3),
                  primaryColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, color: primaryColor, size: 28),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
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
        .fadeIn(delay: Duration(milliseconds: delay), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  // Question Pages

  Widget _buildQuestionFrequency() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacing24),
          
          Text(
            'How often do you\ntake notes?',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 28,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: AppTheme.spacing48),
          
          OnboardingQuestionCard(
            emoji: '📝',
            title: 'Daily',
            subtitle: 'I\'m committed',
            isSelected: _onboardingData.noteFrequency == 'daily',
            onTap: () => setState(() => _onboardingData.noteFrequency = 'daily'),
            animationDelay: 0,
          ),
          OnboardingQuestionCard(
            emoji: '🗓️',
            title: 'Few times a week',
            subtitle: 'Regular user',
            isSelected: _onboardingData.noteFrequency == 'weekly',
            onTap: () => setState(() => _onboardingData.noteFrequency = 'weekly'),
            animationDelay: 100,
          ),
          OnboardingQuestionCard(
            emoji: '✨',
            title: 'Whenever inspiration strikes',
            subtitle: 'As needed',
            isSelected: _onboardingData.noteFrequency == 'occasional',
            onTap: () => setState(() => _onboardingData.noteFrequency = 'occasional'),
            animationDelay: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionUseCase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacing24),
          
          Text(
            'What will you use\nAI Voice Notes for?',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 28,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: AppTheme.spacing48),
          
          OnboardingQuestionCard(
            emoji: '💼',
            title: 'Work & Productivity',
            subtitle: 'Meetings, tasks, ideas',
            isSelected: _onboardingData.useCase == 'work',
            onTap: () => setState(() => _onboardingData.useCase = 'work'),
            animationDelay: 0,
          ),
          OnboardingQuestionCard(
            emoji: '📚',
            title: 'Learning & Study',
            subtitle: 'Lectures, research, notes',
            isSelected: _onboardingData.useCase == 'learning',
            onTap: () => setState(() => _onboardingData.useCase = 'learning'),
            animationDelay: 100,
          ),
          OnboardingQuestionCard(
            emoji: '💭',
            title: 'Personal Journaling',
            subtitle: 'Thoughts, feelings, daily life',
            isSelected: _onboardingData.useCase == 'journal',
            onTap: () => setState(() => _onboardingData.useCase = 'journal'),
            animationDelay: 200,
          ),
          OnboardingQuestionCard(
            emoji: '🎨',
            title: 'Creative Ideas',
            subtitle: 'Inspiration, projects',
            isSelected: _onboardingData.useCase == 'creative',
            onTap: () => setState(() => _onboardingData.useCase = 'creative'),
            animationDelay: 300,
              ),
        ],
      ),
    );
  }

  Widget _buildQuestionAudioQuality() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacing24),
          
          Text(
            'Choose your\ntranscription quality',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 28,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: AppTheme.spacing16),
          
          Text(
            'You can change this later in settings',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 600.ms),
          
          const SizedBox(height: AppTheme.spacing48),
          
          OnboardingQuestionCard(
            emoji: '⚡',
            title: 'Fast & Efficient',
            subtitle: 'Good quality, quick processing',
            isSelected: _onboardingData.audioQuality == AudioQuality.low,
            onTap: () => setState(() => _onboardingData.audioQuality = AudioQuality.low),
            animationDelay: 0,
          ),
          OnboardingQuestionCard(
            emoji: '🎯',
            title: 'Balanced',
            subtitle: 'Recommended for most users',
            isSelected: _onboardingData.audioQuality == AudioQuality.medium,
            onTap: () => setState(() => _onboardingData.audioQuality = AudioQuality.medium),
            animationDelay: 100,
          ),
          OnboardingQuestionCard(
            emoji: '💎',
            title: 'Maximum Accuracy',
            subtitle: 'Best quality, slower',
            isSelected: _onboardingData.audioQuality == AudioQuality.high,
            onTap: () => setState(() => _onboardingData.audioQuality = AudioQuality.high),
            animationDelay: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionAutoClose() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing32),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacing24),
          
          Text(
            'Quick recording\nworkflow?',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 28,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: AppTheme.spacing16),
          
          Text(
            'Auto-close notes to record multiple entries faster',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 600.ms),
          
          const SizedBox(height: AppTheme.spacing48),
          
          OnboardingQuestionCard(
            emoji: '🏃',
            title: 'Yes, Auto-Close',
            subtitle: 'Close note after 2 seconds (faster workflow)',
            isSelected: _onboardingData.autoCloseAfterEntry == true,
            onTap: () => setState(() => _onboardingData.autoCloseAfterEntry = true),
            animationDelay: 0,
          ),
          OnboardingQuestionCard(
            emoji: '✋',
            title: 'No, Keep Open',
            subtitle: 'I\'ll close notes manually (more control)',
            isSelected: _onboardingData.autoCloseAfterEntry == false,
            onTap: () => setState(() => _onboardingData.autoCloseAfterEntry = false),
            animationDelay: 100,
          ),
        ],
      ),
    );
  }
}
