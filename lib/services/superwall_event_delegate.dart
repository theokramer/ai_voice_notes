import 'package:flutter/material.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Superwall delegate that listens to all Superwall events
/// Detects payment cancellation and triggers second paywall
class SuperwallEventDelegate extends SuperwallDelegate {
  // Singleton pattern
  static final SuperwallEventDelegate _instance = SuperwallEventDelegate._internal();
  static SuperwallEventDelegate get instance => _instance;
  
  SuperwallEventDelegate._internal();
  
  bool _isFirstPaywallActive = false;
  bool _shouldShowSecondPaywall = false;

  /// Call this when first paywall is shown
  void setFirstPaywallActive() {
    _isFirstPaywallActive = true;
    _shouldShowSecondPaywall = false;
    debugPrint('🎯 SuperwallDelegate: First paywall marked as ACTIVE');
  }

  /// Call this when first paywall is done (purchased/restored)
  void setInactive() {
    _isFirstPaywallActive = false; 
    _shouldShowSecondPaywall = false;
    debugPrint('✓ SuperwallDelegate: First paywall marked as INACTIVE');
  }

  /// Check if we should show second paywall (called by onDismissHandler)
  bool shouldShowSecondPaywall() {
    final should = _shouldShowSecondPaywall;
    _shouldShowSecondPaywall = false; // Reset flag
    return should;
  }

  @override
  void handleSuperwallEvent(SuperwallEventInfo eventInfo) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📢 SUPERWALL EVENT RECEIVED');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Event: ${eventInfo.event}');
    debugPrint('Event type string: ${eventInfo.event.type}');
    
    // Check the event type string
    final eventTypeString = eventInfo.event.type.toString();
    debugPrint('Event type: $eventTypeString');
    
    // Check if this is a payment cancellation - EventType.transactionAbandon is the correct event name!
    if (eventTypeString == 'EventType.transactionAbandon') {
      debugPrint('🚫 TRANSACTION ABANDONED - USER CANCELLED PAYMENT!');
      debugPrint('Is first paywall active? $_isFirstPaywallActive');
      
      if (_isFirstPaywallActive) {
        debugPrint('✅ First paywall was active!');
        debugPrint('🚩 Setting flag for onDismissHandler to show second paywall');
        _shouldShowSecondPaywall = true;
        
        // STRATEGY: Dismiss immediately to trigger onDismissHandler
        // The onDismissHandler will show second paywall instantly
        debugPrint('🎬 Dismissing first paywall NOW to trigger second...');
        try {
          Superwall.shared.dismiss();
          debugPrint('✅ Dismiss called - onDismissHandler will show second paywall');
        } catch (error) {
          debugPrint('⚠️ Error dismissing paywall: $error');
        }
      } else {
        debugPrint('ℹ️ First paywall not active - ignoring old event from previous session');
      }
    } 
    
    // Also handle transaction failure
    else if (eventTypeString == 'EventType.transactionFail') {
      debugPrint('❌ TRANSACTION FAILED');
      if (_isFirstPaywallActive) {
        debugPrint('🚩 Setting flag for onDismissHandler to show second paywall');
        _shouldShowSecondPaywall = true;
        
        debugPrint('🎬 Dismissing first paywall programmatically (IMMEDIATE)...');
        try {
          Superwall.shared.dismiss();
          debugPrint('✅ Dismiss called');
        } catch (error) {
          debugPrint('⚠️ Error dismissing paywall: $error');
        }
      }
    }
    
    else {
      debugPrint('ℹ️ Other event type - will log for debugging');
    }
  }

  @override
  void didDismissPaywall(PaywallInfo paywallInfo) {
    debugPrint('📱 didDismissPaywall called: ${paywallInfo.identifier}');
  }

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) {
    debugPrint('🎬 didPresentPaywall called: ${paywallInfo.identifier}');
  }

  @override
  void handleCustomPaywallAction(String name) {
    debugPrint('🎯 handleCustomPaywallAction: $name');
  }

  @override
  void handleLog(String level, String scope, String? message, Map<dynamic, dynamic>? info, String? error) {
    // Only log errors and warnings to avoid spam
    if (level == 'error' || level == 'warn') {
      debugPrint('🔍 Superwall Log [$level][$scope]: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
    }
  }

  @override
  void handleSuperwallDeepLink(Uri url, List<String> pathComponents, Map<String, String> queryParameters) {
    debugPrint('🔗 handleSuperwallDeepLink: $url');
    debugPrint('   Path: $pathComponents');
    debugPrint('   Query: $queryParameters');
  }

  @override
  void paywallWillOpenDeepLink(Uri url) {
    debugPrint('🔗 paywallWillOpenDeepLink: $url');
  }

  @override
  void paywallWillOpenURL(Uri url) {
    debugPrint('🔗 paywallWillOpenURL: $url');
  }

  @override
  void subscriptionStatusDidChange(SubscriptionStatus newValue) {
    debugPrint('💳 subscriptionStatusDidChange: $newValue');
  }

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {
    debugPrint('📱 willDismissPaywall: ${paywallInfo.identifier}');
  }

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {
    debugPrint('🎬 willPresentPaywall: ${paywallInfo.identifier}');
  }
}
