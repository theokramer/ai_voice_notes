import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/subscription_service.dart';
import '../services/paywall_flow_controller.dart';
import '../widgets/animated_background.dart';
import '../widgets/loading_indicator.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

/// Splash screen shown during app initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer initialization until after the first frame to avoid calling
    // notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  /// Initialize app and navigate to appropriate screen
  Future<void> _initialize() async {
    try {
      // Load notes provider
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      await notesProvider.initialize();

      // Load settings provider
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.initialize();

      // Initialize subscription service
      final subscriptionService = SubscriptionService();
      await subscriptionService.initialize();

      // Wait minimum time for splash screen (better UX)
      await Future.delayed(const Duration(milliseconds: 1500));

      // Check if user has completed onboarding
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

      if (!mounted) return;

      // Determine navigation based on onboarding and subscription status
      if (!hasCompletedOnboarding) {
        // User hasn't completed onboarding → go to onboarding
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
        );
      } else if (!subscriptionService.isSubscribed) {
        // User completed onboarding and is subscribed → go to home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        // User completed onboarding but not subscribed → show paywall flow
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => _PaywallFlowScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
      
      // Even if there's an error, navigate to onboarding after delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
        ),
      );
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon/logo with glow effect
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          settingsProvider.currentThemeConfig.accentColor,
                          settingsProvider.currentThemeConfig.accentColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: settingsProvider.currentThemeConfig.accentColor.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: settingsProvider.currentThemeConfig.accentColor.withOpacity(0.3),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      size: 70,
                      color: Colors.white,
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(reverse: true),
                      )
                      .scale(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: const Duration(milliseconds: 400))
                      .shimmer(
                        duration: const Duration(milliseconds: 2000),
                        delay: const Duration(milliseconds: 800),
                        color: Colors.white.withOpacity(0.3),
                      ),
                  
                  const SizedBox(height: 40),
                  
                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        settingsProvider.currentThemeConfig.accentColor.withOpacity(0.8),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'AI Voice Notes',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(milliseconds: 600),
                      )
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                      ),
                  
                  const SizedBox(height: 16),
                  
                  // Tagline
                  const Text(
                    'Your thoughts, perfectly captured',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 600),
                      ),
                  
                  const SizedBox(height: 80),
                  
                  // Custom loading indicator
                  LoadingIndicator(
                    size: 50,
                    color: settingsProvider.currentThemeConfig.accentColor,
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 800),
                        duration: const Duration(milliseconds: 600),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Screen that immediately launches the paywall flow
class _PaywallFlowScreen extends StatefulWidget {
  @override
  State<_PaywallFlowScreen> createState() => _PaywallFlowScreenState();
}

class _PaywallFlowScreenState extends State<_PaywallFlowScreen> {
  @override
  void initState() {
    super.initState();
    // Launch paywall flow immediately after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchPaywallFlow();
    });
  }

  Future<void> _launchPaywallFlow() async {
    if (!mounted) return;
    await PaywallFlowController().showOnboardingPaywallFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon/logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_open,
                size: 60,
                color: Colors.white,
              ),
            )
                .animate()
                .scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: const Duration(milliseconds: 400)),
            
            const SizedBox(height: 32),
            
            // Loading text
            const Text(
              'Loading subscription options...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 600),
                ),
            
            const SizedBox(height: 60),
            
            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primary.withValues(alpha: 0.5),
                ),
              ),
            )
                .animate()
                .fadeIn(
                  delay: const Duration(milliseconds: 500),
                  duration: const Duration(milliseconds: 600),
                ),
          ],
        ),
      ),
    );
  }
}
