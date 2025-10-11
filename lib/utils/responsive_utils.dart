import 'package:flutter/material.dart';

/// Utility class for responsive layout calculations
class ResponsiveUtils {
  /// Get responsive font size based on screen height
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final height = MediaQuery.of(context).size.height;
    
    // Scale factor based on screen height
    // iPhone SE: ~667, iPhone 15 Pro: ~852, iPhone 15 Pro Max: ~932
    if (height < 700) {
      return baseSize * 0.9; // Small screens
    } else if (height > 900) {
      return baseSize * 1.1; // Large screens
    }
    return baseSize; // Normal screens
  }

  /// Get responsive spacing based on screen height
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final height = MediaQuery.of(context).size.height;
    
    if (height < 700) {
      return baseSpacing * 0.8; // Tighter spacing on small screens
    } else if (height > 900) {
      return baseSpacing * 1.2; // More breathing room on large screens
    }
    return baseSpacing;
  }

  /// Check if device has a small screen
  static bool isSmallScreen(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return height < 700;
  }

  /// Get maximum content width (centers on tablets)
  static double getMaxWidthForContent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 600 ? 600 : width; // Cap at 600px for tablets
  }

  /// Get available content height (excluding safe area and fixed elements)
  static double getAvailableContentHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    return height - padding.top - padding.bottom;
  }

  /// Calculate dynamic icon size based on screen
  static double getIconSize(BuildContext context, double baseSize) {
    final height = MediaQuery.of(context).size.height;
    
    if (height < 700) {
      return baseSize * 0.85;
    } else if (height > 900) {
      return baseSize * 1.15;
    }
    return baseSize;
  }
}

