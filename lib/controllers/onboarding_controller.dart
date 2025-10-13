import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/onboarding_data.dart';

/// Manages onboarding state and flow logic
class OnboardingController extends ChangeNotifier {
  final OnboardingData _data = OnboardingData();
  bool _hasShownRatingPrompt = false;
  
  OnboardingData get data => _data;
  bool get hasShownRatingPrompt => _hasShownRatingPrompt;
  
  void markRatingPromptShown() {
    _hasShownRatingPrompt = true;
    notifyListeners();
  }
  
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('has_used_app', false);
  }
  
  Future<PermissionStatus> requestMicrophonePermission() async {
    return await Permission.microphone.request();
  }
}

