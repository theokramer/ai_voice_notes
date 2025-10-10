import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'dart:async';

/// Service to track and manage subscription status
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static const String _hasCompletedPaywallFlowKey = 'has_completed_paywall_flow';
  static const String _isSubscribedKey = 'is_subscribed';

  bool _isSubscribed = false;
  bool _hasCompletedPaywallFlow = false;
  StreamSubscription<SubscriptionStatus>? _subscription;

  /// Get current subscription status
  bool get isSubscribed => _isSubscribed;

  /// Get whether user has completed the paywall flow
  bool get hasCompletedPaywallFlow => _hasCompletedPaywallFlow;

  /// Initialize the subscription service and load cached status
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedPaywallFlow = prefs.getBool(_hasCompletedPaywallFlowKey) ?? false;
      _isSubscribed = prefs.getBool(_isSubscribedKey) ?? false;

      debugPrint('SubscriptionService initialized: subscribed=$_isSubscribed, completed flow=$_hasCompletedPaywallFlow');

      // Listen to subscription status changes from Superwall
      _startListeningToSubscriptionStatus();
    } catch (e) {
      debugPrint('Error initializing SubscriptionService: $e');
    }
  }

  /// Start listening to Superwall subscription status changes
  void _startListeningToSubscriptionStatus() {
    try {
      _subscription = Superwall.shared.subscriptionStatus.listen((status) {
        debugPrint('Subscription status changed: $status');
        // Update our local state based on the subscription status
        final isActive = status is SubscriptionStatusActive;
        _updateSubscriptionStatus(isActive);
      });
    } catch (e) {
      debugPrint('Error listening to subscription status: $e');
    }
  }

  /// Check current subscription status
  Future<void> checkSubscriptionStatus() async {
    try {
      // When a purchase is made, Superwall will handle it automatically via the stream
      // We'll rely on marking the paywall flow as complete
      // If the user completed the paywall flow successfully, we assume they're subscribed
      if (_hasCompletedPaywallFlow) {
        await _updateSubscriptionStatus(true);
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
    }
  }

  /// Update subscription status and persist to storage
  Future<void> _updateSubscriptionStatus(bool isSubscribed) async {
    _isSubscribed = isSubscribed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isSubscribedKey, isSubscribed);
      debugPrint('Subscription status updated: $isSubscribed');
    } catch (e) {
      debugPrint('Error saving subscription status: $e');
    }
  }

  /// Mark that the user has completed the paywall flow
  Future<void> markPaywallFlowComplete() async {
    _hasCompletedPaywallFlow = true;
    _isSubscribed = true; // If they completed the paywall flow, they must have purchased
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompletedPaywallFlowKey, true);
      await prefs.setBool(_isSubscribedKey, true);
      debugPrint('Paywall flow marked as complete');
    } catch (e) {
      debugPrint('Error marking paywall flow complete: $e');
    }
  }

  /// Reset paywall flow completion status (for testing)
  Future<void> resetPaywallFlowStatus() async {
    _hasCompletedPaywallFlow = false;
    _isSubscribed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompletedPaywallFlowKey, false);
      await prefs.setBool(_isSubscribedKey, false);
      debugPrint('Paywall flow status reset');
    } catch (e) {
      debugPrint('Error resetting paywall flow status: $e');
    }
  }

  /// Clear all subscription data (for testing/logout)
  Future<void> clearData() async {
    _isSubscribed = false;
    _hasCompletedPaywallFlow = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasCompletedPaywallFlowKey);
      await prefs.remove(_isSubscribedKey);
      debugPrint('Subscription data cleared');
    } catch (e) {
      debugPrint('Error clearing subscription data: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
  }
}
