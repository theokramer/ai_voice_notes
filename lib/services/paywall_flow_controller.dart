import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../screens/home_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Controller for managing the sequential paywall flow
class PaywallFlowController {
  static const String _firstPaywallPlacement = 'onboarding_hard_paywall';
  static const String _secondPaywallPlacement = 'app_launch_paywall';

  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Show the onboarding paywall flow
  /// This will show the first paywall, and if dismissed, show the second (non-dismissible) paywall
  Future<void> showOnboardingPaywallFlow(BuildContext context) async {
    if (!context.mounted) return;

    // Show first paywall (dismissible)
    await _showFirstPaywall(context);
  }

  /// Show the first paywall (dismissible)
  Future<void> _showFirstPaywall(BuildContext context) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('_showFirstPaywall() METHOD CALLED');
    debugPrint('═══════════════════════════════════════');
    
    if (!context.mounted) {
      debugPrint('⚠️ Context not mounted, exiting _showFirstPaywall()');
      return;
    }

    try {
      debugPrint('Showing first paywall: $_firstPaywallPlacement');
      
      final handler = PaywallPresentationHandler();
      
      handler.onPresentHandler = (info) {
        debugPrint('✅ First paywall successfully presented on screen');
        debugPrint('Paywall info: $info');
      };
      
      handler.onDismissHandler = (info, result) async {
        debugPrint('First paywall dismissed with result: $result');
        debugPrint('Result type: ${result.runtimeType}');
        
        switch (result) {
          case PurchasedPaywallResult():
          case RestoredPaywallResult():
            debugPrint('User purchased/restored from first paywall');
            await HapticService.success();
            if (context.mounted) {
              await _onPurchaseComplete(context);
            }
            break;
          case DeclinedPaywallResult():
            // User cancelled payment, show second paywall
            debugPrint('🚨 PAYMENT CANCELLED DETECTED - First Paywall');
            debugPrint('DeclinedPaywallResult received - user clicked X or cancelled payment');
            debugPrint('Triggering second paywall presentation...');
            await HapticService.light();
            if (context.mounted) {
              debugPrint('Context is mounted, calling _showSecondPaywall()');
              await _showSecondPaywall(context);
              debugPrint('_showSecondPaywall() call completed');
            } else {
              debugPrint('⚠️ WARNING: Context not mounted, cannot show second paywall');
            }
            break;
        }
      };
      
      handler.onErrorHandler = (error) async {
        debugPrint('Error showing first paywall: $error');
        if (context.mounted) {
          await _showErrorDialog(context, isFirstPaywall: true);
        }
      };
      
      handler.onSkipHandler = (reason) async {
        debugPrint('First paywall skipped: $reason (user might be subscribed)');
        await HapticService.success();
        if (context.mounted) {
          await _onPurchaseComplete(context);
        }
      };
      
      await Superwall.shared.registerPlacement(
        _firstPaywallPlacement,
        handler: handler,
      );
    } catch (e) {
      debugPrint('Exception showing first paywall: $e');
      if (!context.mounted) return;
      await _showErrorDialog(context, isFirstPaywall: true);
    }
  }

  /// Show the second paywall (non-dismissible hard paywall)
  Future<void> _showSecondPaywall(BuildContext context) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('_showSecondPaywall() METHOD CALLED');
    debugPrint('═══════════════════════════════════════');
    
    if (!context.mounted) {
      debugPrint('⚠️ Context not mounted, exiting _showSecondPaywall()');
      return;
    }

    try {
      debugPrint('Showing second paywall: $_secondPaywallPlacement');
      
      final handler = PaywallPresentationHandler();
      
      handler.onPresentHandler = (info) {
        debugPrint('✅ Second paywall successfully presented on screen');
        debugPrint('Paywall info: $info');
      };
      
      handler.onDismissHandler = (info, result) async {
        debugPrint('Second paywall dismissed with result: $result');
        debugPrint('Result type: ${result.runtimeType}');
        
        switch (result) {
          case PurchasedPaywallResult():
          case RestoredPaywallResult():
            debugPrint('User purchased/restored from second paywall');
            await HapticService.success();
            if (context.mounted) {
              await _onPurchaseComplete(context);
            }
            break;
          case DeclinedPaywallResult():
            // User cancelled without purchasing, show paywall again (non-dismissible behavior)
            debugPrint('🚨 PAYMENT CANCELLED DETECTED - Second Paywall');
            debugPrint('DeclinedPaywallResult received - user clicked X or cancelled payment');
            debugPrint('Non-dismissible behavior: Re-showing second paywall after delay...');
            await HapticService.light();
            await Future.delayed(const Duration(milliseconds: 300));
            if (context.mounted) {
              debugPrint('Context is mounted, re-calling _showSecondPaywall()');
              await _showSecondPaywall(context);
              debugPrint('_showSecondPaywall() re-call completed');
            } else {
              debugPrint('⚠️ WARNING: Context not mounted, cannot re-show second paywall');
            }
            break;
        }
      };
      
      handler.onErrorHandler = (error) async {
        debugPrint('Error showing second paywall: $error');
        if (context.mounted) {
          await _showErrorDialog(context, isFirstPaywall: false);
        }
      };
      
      handler.onSkipHandler = (reason) async {
        debugPrint('Second paywall skipped: $reason (user must be subscribed)');
        await HapticService.success();
        if (context.mounted) {
          await _onPurchaseComplete(context);
        }
      };
      
      await Superwall.shared.registerPlacement(
        _secondPaywallPlacement,
        handler: handler,
      );
    } catch (e) {
      debugPrint('Exception showing second paywall: $e');
      if (!context.mounted) return;
      await _showErrorDialog(context, isFirstPaywall: false);
    }
  }

  /// Called when purchase is complete
  Future<void> _onPurchaseComplete(BuildContext context) async {
    // Mark paywall flow as complete
    await _subscriptionService.markPaywallFlowComplete();
    
    // Update subscription status
    await _subscriptionService.checkSubscriptionStatus();
    
    if (!context.mounted) return;

    // Navigate to home screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  /// Show error dialog with retry option
  Future<void> _showErrorDialog(
    BuildContext context, {
    required bool isFirstPaywall,
  }) async {
    if (!context.mounted) return;

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settingsProvider.currentThemeConfig;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.glassStrongSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.glassBorder, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.primary,
              size: 28,
            ),
            const SizedBox(width: AppTheme.spacing12),
            const Text(
              'Connection Error',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Text(
          'Unable to load subscription options. Please check your internet connection and try again.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          // Exit button
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            child: const Text(
              'Exit App',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 16,
              ),
            ),
          ),
          // Retry button
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await HapticService.medium();
              
              if (!context.mounted) return;
              
              // Retry showing the appropriate paywall
              if (isFirstPaywall) {
                await _showFirstPaywall(context);
              } else {
                await _showSecondPaywall(context);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: theme.primary.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
                vertical: AppTheme.spacing12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                color: theme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
