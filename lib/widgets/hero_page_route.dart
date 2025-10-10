import 'package:flutter/material.dart';

class HeroPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration _duration;
  final Curve curve;

  HeroPageRoute({
    required this.builder,
    Duration transitionDuration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOutCubic,
    super.settings,
  }) : _duration = transitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Create fade + scale animation
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 0.6, curve: curve),
      ),
    );

    final scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 1.0, curve: curve),
      ),
    );

    // Fade out previous page slightly
    final secondaryFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: curve,
      ),
    );

    // If this is the page being pushed, animate in
    return Stack(
      children: [
        // Previous page fading out
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          FadeTransition(
            opacity: secondaryFadeAnimation,
            child: Container(),
          ),
        // New page animating in
        FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Duration get transitionDuration => _duration;

  @override
  bool get maintainState => true;
}

// Slide up page route (for bottom sheets style)
class SlideUpPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration _duration;

  SlideUpPageRoute({
    required this.builder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    super.settings,
  }) : _duration = transitionDuration;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
    );

    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  @override
  Duration get transitionDuration => _duration;

  @override
  bool get maintainState => true;
}

// Shared axis transition (Material Design 3 style)
class SharedAxisPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration _duration;
  final SharedAxisTransitionType transitionType;

  SharedAxisPageRoute({
    required this.builder,
    Duration transitionDuration = const Duration(milliseconds: 350),
    this.transitionType = SharedAxisTransitionType.scaled,
    super.settings,
  }) : _duration = transitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (transitionType) {
      case SharedAxisTransitionType.horizontal:
        return _buildHorizontalTransition(
          animation,
          secondaryAnimation,
          child,
        );
      case SharedAxisTransitionType.vertical:
        return _buildVerticalTransition(
          animation,
          secondaryAnimation,
          child,
        );
      case SharedAxisTransitionType.scaled:
        return _buildScaledTransition(
          animation,
          secondaryAnimation,
          child,
        );
    }
  }

  Widget _buildHorizontalTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incomingOffset = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    final outgoingOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );

    final incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    final outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    return Stack(
      children: [
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          SlideTransition(
            position: outgoingOffset,
            child: FadeTransition(
              opacity: outgoingFade,
              child: Container(),
            ),
          ),
        SlideTransition(
          position: incomingOffset,
          child: FadeTransition(
            opacity: incomingFade,
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incomingOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    final incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    return SlideTransition(
      position: incomingOffset,
      child: FadeTransition(
        opacity: incomingFade,
        child: child,
      ),
    );
  }

  Widget _buildScaledTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incomingScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    final outgoingScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInCubic),
      ),
    );

    final incomingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    final outgoingFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    return Stack(
      children: [
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          ScaleTransition(
            scale: outgoingScale,
            child: FadeTransition(
              opacity: outgoingFade,
              child: Container(),
            ),
          ),
        ScaleTransition(
          scale: incomingScale,
          child: FadeTransition(
            opacity: incomingFade,
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Duration get transitionDuration => _duration;

  @override
  bool get maintainState => true;
}

enum SharedAxisTransitionType {
  horizontal,
  vertical,
  scaled,
}

// Helper function for easy navigation
extension NavigationExtensions on BuildContext {
  Future<T?> pushHero<T>(Widget page) {
    return Navigator.of(this).push<T>(
      HeroPageRoute(builder: (_) => page),
    );
  }

  Future<T?> pushSlideUp<T>(Widget page) {
    return Navigator.of(this).push<T>(
      SlideUpPageRoute(builder: (_) => page),
    );
  }

  Future<T?> pushSharedAxis<T>(
    Widget page, {
    SharedAxisTransitionType type = SharedAxisTransitionType.scaled,
  }) {
    return Navigator.of(this).push<T>(
      SharedAxisPageRoute(
        builder: (_) => page,
        transitionType: type,
      ),
    );
  }
}

