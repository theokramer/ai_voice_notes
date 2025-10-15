import 'package:flutter/material.dart';
import '../models/settings.dart';

class ThemeConfig {
  final Color gradientStart;
  final Color gradientMiddle;
  final Color gradientEnd;
  final Color accentColor;
  final Color primaryColor;
  final Color secondaryColor;
  final Color buttonColor;
  final Color buttonSecondaryColor;
  final Color accentLight;
  final Color accentDark;

  const ThemeConfig({
    required this.gradientStart,
    required this.gradientMiddle,
    required this.gradientEnd,
    required this.accentColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.buttonColor,
    required this.buttonSecondaryColor,
    required this.accentLight,
    required this.accentDark,
  });

  Color get primary => primaryColor;
  
  LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMiddle, gradientEnd],
    stops: const [0.0, 0.5, 1.0],
  );
  
  LinearGradient get buttonGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [buttonColor, buttonColor.withOpacity(0.8)],
  );
  
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accentColor, accentDark],
    stops: const [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  // Static theme configs for each preset
  static const _themeConfigs = {
    ThemePreset.modern: ThemeConfig(
      gradientStart: Color(0xFF1f2937),
      gradientMiddle: Color(0xFF475569),
      gradientEnd: Color(0xFF64748b),
      accentColor: Color(0xFF38bdf8),
      primaryColor: Color(0xFF38bdf8), // Sky blue - vibrant but fits modern dark theme
      secondaryColor: Color(0xFF0ea5e9),
      buttonColor: Color(0xFF0ea5e9),
      buttonSecondaryColor: Color(0xFF0284c7),
      accentLight: Color(0xFF7dd3fc),
      accentDark: Color(0xFF0369a1),
    ),
    ThemePreset.oceanBlue: ThemeConfig(
      gradientStart: Color(0xFF1e3a8a),
      gradientMiddle: Color(0xFF06b6d4),
      gradientEnd: Color(0xFF14b8a6),
      accentColor: Color(0xFF06b6d4),
      primaryColor: Color(0xFF22d3ee), // Bright cyan for ocean theme
      secondaryColor: Color(0xFF14b8a6),
      buttonColor: Color(0xFF0891b2),
      buttonSecondaryColor: Color(0xFF0d9488),
      accentLight: Color(0xFF67e8f9),
      accentDark: Color(0xFF0e7490),
    ),
    ThemePreset.sunsetOrange: ThemeConfig(
      gradientStart: Color(0xFFff6b6b),
      gradientMiddle: Color(0xFFff8c42),
      gradientEnd: Color(0xFFffd93d),
      accentColor: Color(0xFFfb923c),
      primaryColor: Color(0xFFfb923c), // Bright orange for sunset theme
      secondaryColor: Color(0xFFfbbf24),
      buttonColor: Color(0xFFf97316),
      buttonSecondaryColor: Color(0xFFf59e0b),
      accentLight: Color(0xFFfdba74),
      accentDark: Color(0xFFea580c),
    ),
    ThemePreset.forestGreen: ThemeConfig(
      gradientStart: Color(0xFF065f46),
      gradientMiddle: Color(0xFF10b981),
      gradientEnd: Color(0xFF6ee7b7),
      accentColor: Color(0xFF34d399),
      primaryColor: Color(0xFF34d399), // Bright emerald green for forest theme
      secondaryColor: Color(0xFF6ee7b7),
      buttonColor: Color(0xFF10b981),
      buttonSecondaryColor: Color(0xFF059669),
      accentLight: Color(0xFF6ee7b7),
      accentDark: Color(0xFF047857),
    ),
    ThemePreset.aurora: ThemeConfig(
      gradientStart: Color(0xFF3b82f6),
      gradientMiddle: Color(0xFFec4899),
      gradientEnd: Color(0xFFfbbf24),
      accentColor: Color(0xFFf472b6),
      primaryColor: Color(0xFFf472b6), // Bright pink for aurora theme
      secondaryColor: Color(0xFF3b82f6),
      buttonColor: Color(0xFFdb2777),
      buttonSecondaryColor: Color(0xFF2563eb),
      accentLight: Color(0xFFfda4af),
      accentDark: Color(0xFF9f1239),
    ),
  };

  static ThemeConfig getThemeConfig(ThemePreset preset) {
    return _themeConfigs[preset] ?? _themeConfigs[ThemePreset.modern]!;
  }
  
  // Common colors (independent of theme)
  static const Color background = Color(0xFF1a1a1a);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE5E5E5);
  static const Color textTertiary = Color(0xFFAAAAAA);
  
  // Glassmorphism colors
  static const Color glassSurface = Color(0x30FFFFFF); // 19% white
  static const Color glassBorder = Color(0x40FFFFFF); // 25% white
  static const Color glassStrongSurface = Color(0x40FFFFFF); // 25% white (for cards)
  static const Color glassDarkSurface = Color(0x60000000); // 38% black (dark frosting for headers)
  
  // Backward compatibility - use default theme
  static final ThemeConfig _defaultConfig = getThemeConfig(ThemePreset.modern);
  static Color get gradientStart => _defaultConfig.gradientStart;
  static Color get gradientMiddle => _defaultConfig.gradientMiddle;
  static Color get gradientEnd => _defaultConfig.gradientEnd;
  static Color get primary => _defaultConfig.primary;
  static LinearGradient get backgroundGradient => _defaultConfig.backgroundGradient;

  static ThemeData buildTheme(ThemePreset preset) {
    final config = getThemeConfig(preset);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: config.primary,
        surface: glassSurface,
        onPrimary: textPrimary,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.7,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.4,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.25,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'Inter',
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          fontFamily: 'Inter',
          height: 1.65,
          letterSpacing: 0.1,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          fontFamily: 'Inter',
          height: 1.5,
          letterSpacing: 0.1,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontFamily: 'Inter',
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: glassStrongSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: glassBorder, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: glassBorder,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),
    );
  }

  // Backward compatibility - get default theme
  static ThemeData get theme => buildTheme(ThemePreset.modern);

  // Custom spacing - Generous for elegant design
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;

  // Compact mode spacing (reduced by ~40%)
  static const double spacingCompact4 = 2.4;
  static const double spacingCompact8 = 4.8;
  static const double spacingCompact12 = 7.2;
  static const double spacingCompact16 = 9.6;
  static const double spacingCompact20 = 12;
  static const double spacingCompact24 = 14.4;
  static const double spacingCompact32 = 19.2;
  static const double spacingCompact48 = 28.8;

  // Border radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 24;

  // Compact mode radius
  static const double radiusCompactSmall = 6;
  static const double radiusCompactMedium = 8;
  static const double radiusCompactLarge = 12;
  static const double radiusCompactXLarge = 16;

  // Font sizes for compact mode
  static const double fontSizeCompactBody = 12;
  static const double fontSizeCompactTitle = 14;
  static const double fontSizeCompactHeadline = 16;

  // Dimensions
  static const double cardHeightCompact = 80;
  static const double iconSizeCompact = 18;

  // Helper method to get appropriate spacing based on compact mode
  static double getSpacing(double normalSpacing, bool isCompact) {
    if (!isCompact) return normalSpacing;
    // Scale down by 60% for compact mode
    return normalSpacing * 0.6;
  }

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Shadow definitions for depth
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
  ];
  
  // Helper method to get themed shadow using theme config
  static List<BoxShadow> getThemedShadow(ThemeConfig config, {double opacity = 0.3}) {
    return [
      BoxShadow(
        color: config.primaryColor.withOpacity(opacity),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 15,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // Helper method to create glassmorphic decoration
  static BoxDecoration glassDecoration({
    double radius = radiusLarge,
    Color? color,
    Border? border,
    List<BoxShadow>? shadows,
    bool includeDefaultShadow = false,
  }) {
    return BoxDecoration(
      color: color ?? glassStrongSurface,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(
        color: glassBorder.withOpacity(0.25),  // Subtle elegant border
        width: 1,
      ),
      boxShadow: shadows ?? (includeDefaultShadow ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ] : null),
    );
  }

  // Specialized button decoration with better shadows
  static BoxDecoration buttonDecoration({
    double radius = radiusMedium,
    Color? color,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color ?? glassStrongSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glassBorder.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: isPressed ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 5,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
      ] : [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.03),
          blurRadius: 1,
          spreadRadius: 0,
          offset: const Offset(0, -1),
        ),
      ],
    );
  }
}

