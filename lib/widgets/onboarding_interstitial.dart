import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'legal_footer.dart';

/// Interstitial screen for trust-building moments in onboarding
class OnboardingInterstitial extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<String>? features; // Optional feature list
  final String? subtitle;
  final Color? iconColor;
  final bool showLegalFooter; // Show Privacy Policy & Terms links

  const OnboardingInterstitial({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.features,
    this.subtitle,
    this.iconColor,
    this.showLegalFooter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final primaryColor = iconColor ?? settingsProvider.currentThemeConfig.primary;
        final availableHeight = ResponsiveUtils.getAvailableContentHeight(context);
        final isSmallScreen = availableHeight < 700;
        
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                  MediaQuery.of(context).padding.top - 
                  MediaQuery.of(context).padding.bottom - 
                  100, // Account for top bar and bottom button
              ),
              child: Column(
                children: [
                  // Top spacing - further reduced to prevent overflow
                  SizedBox(height: isSmallScreen ? availableHeight * 0.05 : availableHeight * 0.1),
                  
                  // Animated icon
                  _buildAnimatedIcon(context, primaryColor, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? AppTheme.spacing16 : ResponsiveUtils.getResponsiveSpacing(context, AppTheme.spacing32)),
                  
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: isSmallScreen ? 24 : ResponsiveUtils.getResponsiveFontSize(context, 32),
                            height: 1.2,
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
                  
                  SizedBox(height: isSmallScreen ? AppTheme.spacing12 : ResponsiveUtils.getResponsiveSpacing(context, AppTheme.spacing24)),
                  
                  // Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                            height: isSmallScreen ? 1.4 : 1.6,
                            fontSize: isSmallScreen ? 14 : ResponsiveUtils.getResponsiveFontSize(context, 17),
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 600.ms),
                  ),
                  
                  // Features (if provided)
                  if (features != null) ...[
                    SizedBox(height: isSmallScreen ? AppTheme.spacing12 : ResponsiveUtils.getResponsiveSpacing(context, AppTheme.spacing32)),
                ...features!.asMap().entries.map((entry) {
                  return _buildFeatureItem(
                    context,
                    entry.value,
                    primaryColor,
                    entry.key,
                    isSmallScreen,
                  );
                }),
                  ],
                  
                  // Subtitle (if provided)
                  if (subtitle != null) ...[
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, AppTheme.spacing32)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing32),
                      child: Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textTertiary,
                              height: 1.5,
                            ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 1200.ms, duration: 600.ms),
                    ),
                  ],
                  
                  // Legal Footer (Privacy Policy & Terms)
                  if (showLegalFooter) ...[
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, AppTheme.spacing24)),
                    LegalFooter(
                      fontSize: isSmallScreen ? 11 : 12,
                      linkColor: primaryColor,
                    )
                        .animate()
                        .fadeIn(delay: 1400.ms, duration: 600.ms),
                  ],
                  
                  SizedBox(height: availableHeight * 0.15),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(BuildContext context, Color primaryColor, bool isSmallScreen) {
    final iconSize = isSmallScreen ? 50.0 : ResponsiveUtils.getIconSize(context, 70);
    
    return Container(
      width: iconSize * 2,
      height: iconSize * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            primaryColor.withValues(alpha: 0.2),
            primaryColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.3, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          width: iconSize * 1.4,
          height: iconSize * 1.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.1),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: primaryColor,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 800.ms,
        )
        .then()
        .shimmer(
          duration: 2000.ms,
          color: primaryColor.withValues(alpha: 0.2),
        );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String feature,
    Color primaryColor,
    int index,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? AppTheme.spacing32 : AppTheme.spacing48,
        vertical: isSmallScreen ? AppTheme.spacing4 : AppTheme.spacing8,
      ),
      child: Row(
        children: [
          // Checkmark icon
          Container(
            width: isSmallScreen ? 24 : 28,
            height: isSmallScreen ? 24 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.15),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.check,
              size: isSmallScreen ? 14 : 16,
              color: primaryColor,
            ),
          ),
          
          SizedBox(width: isSmallScreen ? AppTheme.spacing12 : AppTheme.spacing16),
          
          // Feature text
          Expanded(
            child: Text(
              feature,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? 14 : ResponsiveUtils.getResponsiveFontSize(context, 16),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 800 + (index * 150)), duration: 600.ms)
        .slideX(begin: -0.2, end: 0);
  }
}
