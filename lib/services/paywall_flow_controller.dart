import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../screens/home_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../services/superwall_event_delegate.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Controller for managing the sequential paywall flow
class PaywallFlowController {
  // Singleton pattern
  static final PaywallFlowController _instance = PaywallFlowController._internal();
  static PaywallFlowController get instance => _instance;
  
  PaywallFlowController._internal();
  
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

  /// Public method for SuperwallEventDelegate to call
  /// This shows the second paywall after payment cancellation
  Future<void> showSecondPaywallPublic(BuildContext context) async {
    if (kDebugMode) {
      debugPrint('🔓 showSecondPaywallPublic() called from SuperwallEventDelegate');
    }
    await _showSecondPaywall(context);
  }

  /// Show the first paywall (dismissible)
  Future<void> _showFirstPaywall(BuildContext context) async {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('_showFirstPaywall() METHOD CALLED');
      debugPrint('═══════════════════════════════════════');
    }
    
    // Register with delegate for event tracking
    SuperwallEventDelegate.instance.setFirstPaywallActive();
    if (kDebugMode) {
      debugPrint('🎯 Registered first paywall with SuperwallEventDelegate');
      
      // PRE-LOAD second paywall in background for instant display if needed
      debugPrint('🔄 Pre-loading second paywall in background...');
    }
    _preloadSecondPaywall();
    
    if (!context.mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ Context not mounted, exiting _showFirstPaywall()');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('Showing first paywall: $_firstPaywallPlacement');
      }
      
      final handler = PaywallPresentationHandler();
      
      handler.onPresentHandler = (info) {
        if (kDebugMode) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('🎬 PRESENT HANDLER CALLED - FIRST PAYWALL');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('✅ First paywall successfully presented');
          debugPrint('Paywall info: $info');
          debugPrint('📌 Waiting for user to purchase or cancel...');
          debugPrint('   If user cancels payment → Second paywall appears');
        }
      };
      
      handler.onDismissHandler = (info, result) async {
        if (kDebugMode) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('🚪 DISMISS HANDLER CALLED - FIRST PAYWALL');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('Result: $result');
          debugPrint('Result type: ${result.runtimeType}');
          debugPrint('Paywall info: $info');
        }
        
        // Check if delegate set flag to show second paywall
        final shouldShowSecond = SuperwallEventDelegate.instance.shouldShowSecondPaywall();
        if (kDebugMode) {
          debugPrint('Should show second paywall (from delegate)? $shouldShowSecond');
        }
        
        switch (result) {
          case PurchasedPaywallResult():
            if (kDebugMode) {
              debugPrint('✅ Purchase successful!');
            }
            // Mark delegate inactive
            SuperwallEventDelegate.instance.setInactive();
            await HapticService.success();
            if (context.mounted) {
              await _onPurchaseComplete(context);
            }
            break;
            
          case RestoredPaywallResult():
            if (kDebugMode) {
              debugPrint('🔄 Restore successful!');
            }
            // Mark delegate inactive
            SuperwallEventDelegate.instance.setInactive();
            await HapticService.success();
            if (context.mounted) {
              await _onPurchaseComplete(context);
            }
            break;
            
          case DeclinedPaywallResult():
            if (kDebugMode) {
              debugPrint('🚪 Paywall declined');
            }
            // Mark delegate inactive
            SuperwallEventDelegate.instance.setInactive();
            
            // Check if we should show second paywall (payment was cancelled)
            if (shouldShowSecond) {
              if (kDebugMode) {
                debugPrint('🎬 Payment was cancelled - showing second paywall IMMEDIATELY!');
              }
              await HapticService.light();
              
              // Show second paywall immediately without delay
              if (context.mounted) {
                await _showSecondPaywall(context);
              } else {
                if (kDebugMode) {
                  debugPrint('⚠️ Context not mounted');
                }
              }
            } else {
              if (kDebugMode) {
                debugPrint('ℹ️ User just closed paywall without attempting payment');
              }
            }
            break;
            
          default:
            if (kDebugMode) {
              debugPrint('ℹ️ Other result type: $result');
            }
            SuperwallEventDelegate.instance.setInactive();
        }
      };
      
      handler.onErrorHandler = (error) async {
        if (kDebugMode) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('❌ ERROR HANDLER CALLED');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('Error showing first paywall: $error');
        }
        if (context.mounted) {
          await _showErrorDialog(context, isFirstPaywall: true);
        }
      };
      
      handler.onSkipHandler = (reason) async {
        if (kDebugMode) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('⏭️ SKIP HANDLER CALLED');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('First paywall skipped: $reason (user might be subscribed)');
        }
        await HapticService.success();
        if (context.mounted) {
          await _onPurchaseComplete(context);
        }
      };
      
      if (kDebugMode) {
        debugPrint('🔧 Setting up handler callbacks...');
        debugPrint('✓ onPresentHandler set');
        debugPrint('✓ onDismissHandler set');
        debugPrint('✓ onErrorHandler set');
        debugPrint('✓ onSkipHandler set');
        debugPrint('🚀 About to call registerPlacement...');
      }
      
      // Register the placement with handler
      await Superwall.shared.registerPlacement(
        _firstPaywallPlacement,
        handler: handler,
      );
      
      if (kDebugMode) {
        debugPrint('✅ registerPlacement call completed');
        debugPrint('⏳ Waiting for user interaction with paywall...');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception showing first paywall: $e');
      }
      if (!context.mounted) return;
      await _showErrorDialog(context, isFirstPaywall: true);
    }
  }

  /// Pre-load the second paywall in background for instant display
  void _preloadSecondPaywall() {
    // Note: Superwall automatically caches paywall assets after first load
    // This method is a placeholder - actual pre-loading happens in handleSuperwallEvent
    if (kDebugMode) {
      debugPrint('📦 Second paywall will be loaded on-demand (Superwall caching active)');
    }
  }

  /// Show the second paywall (non-dismissible hard paywall)
  Future<void> _showSecondPaywall(BuildContext context) async {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('_showSecondPaywall() METHOD CALLED');
      debugPrint('═══════════════════════════════════════');
    }
    
    if (!context.mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ Context not mounted, exiting _showSecondPaywall()');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('Showing second paywall: $_secondPaywallPlacement');
      }
      
      final handler = PaywallPresentationHandler();
      
      handler.onPresentHandler = (info) {
        if (kDebugMode) {
          debugPrint('✅ Second paywall successfully presented on screen');
          debugPrint('Paywall info: $info');
        }
      };
      
      handler.onDismissHandler = (info, result) async {
        if (kDebugMode) {
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('📱 SECOND PAYWALL DISMISSED');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('Dismiss result: $result');
          debugPrint('Result type: ${result.runtimeType}');
        }
        
        switch (result) {
          case PurchasedPaywallResult():
          case RestoredPaywallResult():
            if (kDebugMode) {
              debugPrint('✅ User purchased/restored from second paywall');
            }
            await HapticService.success();
            if (context.mounted) {
              await _onPurchaseComplete(context);
            }
            break;
          case DeclinedPaywallResult():
            // Second paywall is non-dismissible - always re-show it
            if (kDebugMode) {
              debugPrint('🚨 DeclinedPaywallResult - Second Paywall (NON-DISMISSIBLE)');
              debugPrint('♻️ Re-showing second paywall after delay...');
            }
            await HapticService.light();
            
            await Future.delayed(const Duration(milliseconds: 500));
            if (context.mounted) {
              if (kDebugMode) {
                debugPrint('🔄 Context is mounted, re-calling _showSecondPaywall()');
              }
              await _showSecondPaywall(context);
              if (kDebugMode) {
                debugPrint('✅ _showSecondPaywall() re-call completed');
              }
            } else {
              if (kDebugMode) {
                debugPrint('⚠️ WARNING: Context not mounted, cannot re-show second paywall');
              }
            }
            break;
        }
      };
      
      handler.onErrorHandler = (error) async {
        if (kDebugMode) {
          debugPrint('Error showing second paywall: $error');
        }
        if (context.mounted) {
          await _showErrorDialog(context, isFirstPaywall: false);
        }
      };
      
      handler.onSkipHandler = (reason) async {
        if (kDebugMode) {
          debugPrint('Second paywall skipped: $reason (user must be subscribed)');
        }
        await HapticService.success();
        if (context.mounted) {
          await _onPurchaseComplete(context);
        }
      };
      
      // Register the placement with handler
      await Superwall.shared.registerPlacement(
        _secondPaywallPlacement,
        handler: handler,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception showing second paywall: $e');
      }
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
