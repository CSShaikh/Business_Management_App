import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/business_repository.dart';
import '../auth/login_screen.dart';
import '../business_setup/business_setup_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final BusinessRepository _businessRepository =
      BusinessRepository();

  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _floatingController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _progressWidth;

  String _statusText =
      'Preparing your workspace...';

  double _progress = 0.0;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1500,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1800,
      ),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 12,
      ),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2200,
      ),
    );

    _logoScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.0,
        0.55,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.0,
        0.40,
        curve: Curves.easeIn,
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.25,
        0.85,
        curve: Curves.easeOut,
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(
        0,
        0.18,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.20,
          0.85,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _progressWidth = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.35,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    _mainController.forward();
    _pulseController.repeat(
      reverse: true,
    );
    _rotationController.repeat();
    _floatingController.repeat(
      reverse: true,
    );

    _startApp();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _floatingController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // APPLICATION STARTUP
  // ===========================================================================

  Future<void> _startApp() async {
    await _setStartupProgress(
      0.15,
      'Starting your workspace...',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 450,
      ),
    );

    if (!mounted) {
      return;
    }

    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        await _setStartupProgress(
          0.75,
          'Opening secure login...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 450,
          ),
        );

        if (!mounted) {
          return;
        }

        _openLogin();
        return;
      }

      await _setStartupProgress(
        0.30,
        'Checking your account...',
      );

      await user.reload();

      if (!mounted) {
        return;
      }

      final User? refreshedUser =
          _auth.currentUser;

      if (refreshedUser == null) {
        await _setStartupProgress(
          0.75,
          'Opening secure login...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 400,
          ),
        );

        if (!mounted) {
          return;
        }

        _openLogin();
        return;
      }

      await _setStartupProgress(
        0.50,
        'Checking your business profile...',
      );

      final business =
          await _businessRepository
              .getBusinessForOwner(
        refreshedUser.uid,
      );

      if (!mounted) {
        return;
      }

      if (business == null) {
        await _setStartupProgress(
          0.82,
          'Business setup required...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 500,
          ),
        );

        if (!mounted) {
          return;
        }

        _openBusinessSetup();
        return;
      }

      await _setStartupProgress(
        0.88,
        'Loading your dashboard...',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) {
        return;
      }

      await _setStartupProgress(
        1.0,
        'Welcome back!',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 250,
        ),
      );

      if (!mounted) {
        return;
      }

      _openDashboard();
    } on FirebaseAuthException catch (e) {
      await _handleAuthError(e);
    } on FirebaseException catch (e) {
      await _handleFirebaseError(e);
    } catch (e) {
      await _handleUnexpectedError(e);
    }
  }

  Future<void> _setStartupProgress(
    double progress,
    String status,
  ) async {
    if (!mounted) {
      return;
    }

    final double safeProgress =
        progress.clamp(
      0.0,
      1.0,
    );

    setState(() {
      _progress = safeProgress;
      _statusText = status;
    });
  }

  // ===========================================================================
  // ERROR HANDLING
  // ===========================================================================

  Future<void> _handleAuthError(
    FirebaseAuthException error,
  ) async {
    if (!mounted) {
      return;
    }

    final bool shouldSignOut =
        error.code == 'user-disabled' ||
        error.code == 'user-not-found' ||
        error.code == 'invalid-user-token' ||
        error.code == 'user-token-expired';

    if (shouldSignOut) {
      try {
        await _auth.signOut();
      } catch (_) {
        // Ignore sign-out failure and continue to login.
      }
    }

    await _setStartupProgress(
      0.78,
      'Opening secure login...',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 500,
      ),
    );

    if (!mounted) {
      return;
    }

    _openLogin();
  }

  Future<void> _handleFirebaseError(
    FirebaseException error,
  ) async {
    if (!mounted) {
      return;
    }

    final String message =
        _getFirebaseErrorMessage(error);

    await _setStartupProgress(
      0.72,
      message,
    );

    await Future.delayed(
      const Duration(
        milliseconds: 900,
      ),
    );

    if (!mounted) {
      return;
    }

    _showStartupError(message);

    await Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
    );

    if (!mounted) {
      return;
    }

    // Keep the authenticated session intact.
    // We don't sign the user out just because Firestore
    // is temporarily unavailable or permission failed.
    _openDashboard();
  }

  Future<void> _handleUnexpectedError(
    Object error,
  ) async {
    if (!mounted) {
      return;
    }

    const String message =
        'Unable to finish startup.';

    await _setStartupProgress(
      0.72,
      message,
    );

    await Future.delayed(
      const Duration(
        milliseconds: 900,
      ),
    );

    if (!mounted) {
      return;
    }

    _showStartupError(
      'Something went wrong while starting the app.',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
    );

    if (!mounted) {
      return;
    }

    final User? user =
        _auth.currentUser;

    if (user == null) {
      _openLogin();
    } else {
      _openDashboard();
    }
  }

  String _getFirebaseErrorMessage(
    FirebaseException error,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return 'Sync permission needs attention.';

      case 'unavailable':
        return 'Checking connection...';

      case 'failed-precondition':
        return 'Firebase configuration needs attention.';

      case 'unauthenticated':
        return 'Your session needs to be refreshed.';

      case 'deadline-exceeded':
        return 'Firebase is taking longer than expected.';

      default:
        return 'Unable to load business data.';
    }
  }

  void _showStartupError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
          behavior:
              SnackBarBehavior.floating,
          duration: const Duration(
            seconds: 3,
          ),
        ),
      );
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _openLogin() {
    if (_isNavigating ||
        !mounted) {
      return;
    }

    _isNavigating = true;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _openBusinessSetup() {
    if (_isNavigating ||
        !mounted) {
      return;
    }

    _isNavigating = true;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const BusinessSetupScreen(),
      ),
      (route) => false,
    );
  }

  void _openDashboard() {
    if (_isNavigating ||
        !mounted) {
      return;
    }

    _isNavigating = true;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Size size =
        MediaQuery.sizeOf(context);

    final ThemeData theme =
        Theme.of(context);

    final bool isSmall =
        size.width < 600;

    final bool isTablet =
        size.width >= 600 &&
        size.width < 1000;

    final double logoSize =
        isSmall
            ? 92
            : isTablet
                ? 106
                : 120;

    return Scaffold(
      backgroundColor:
          AppColors.darkBackground,
      body: Stack(
        children: [
          _buildBackground(
            size,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics:
                    const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      _buildAnimatedLogo(
                        logoSize,
                        isSmall,
                      ),
                      SizedBox(
                        height:
                            isSmall ? 26 : 32,
                      ),
                      _buildTitle(
                        theme,
                        isSmall,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      _buildSubtitle(
                        theme,
                        isSmall,
                      ),
                      SizedBox(
                        height:
                            isSmall ? 34 : 44,
                      ),
                      _buildProgressSection(
                        theme,
                        isSmall,
                      ),
                      SizedBox(
                        height:
                            isSmall ? 34 : 42,
                      ),
                      _buildFeatureRow(
                        theme,
                        isSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BACKGROUND
  // ===========================================================================

  Widget _buildBackground(
    Size size,
  ) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration:
              const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.darkBackground,
                Color(0xFF111C36),
                Color(0xFF17153A),
                AppColors.darkBackground,
              ],
              stops: [
                0.0,
                0.38,
                0.68,
                1.0,
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _rotationController,
          builder: (
            context,
            child,
          ) {
            return CustomPaint(
              size: size,
              painter:
                  _SplashBackgroundPainter(
                rotation:
                    _rotationController.value *
                        math.pi *
                        2,
              ),
            );
          },
        ),
        _buildGlowOrb(
          alignment:
              const Alignment(
            -1.2,
            -0.9,
          ),
          size: 260,
          color:
              AppColors.primary,
        ),
        _buildGlowOrb(
          alignment:
              const Alignment(
            1.2,
            0.85,
          ),
          size: 240,
          color:
              AppColors.secondary,
        ),
        IgnorePointer(
          child: Container(
            decoration:
                BoxDecoration(
              gradient:
                  RadialGradient(
                center:
                    Alignment.center,
                radius: 0.85,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: 0.18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowOrb({
    required Alignment alignment,
    required double size,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (
          context,
          child,
        ) {
          final double pulse =
              0.88 +
                  (_pulseController.value *
                      0.12);

          return Transform.scale(
            scale: pulse,
            child: Container(
              width: size,
              height: size,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    RadialGradient(
                  colors: [
                    color.withValues(
                      alpha: 0.18,
                    ),
                    color.withValues(
                      alpha: 0.05,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // LOGO
  // ===========================================================================

  Widget _buildAnimatedLogo(
    double logoSize,
    bool isSmall,
  ) {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _floatingController,
          ]),
          builder: (
            context,
            child,
          ) {
            final double floatOffset =
                math.sin(
                      _floatingController.value *
                          math.pi,
                    ) *
                    5;

            final double pulse =
                1.0 +
                    (_pulseController.value *
                        0.035);

            return Transform.translate(
              offset: Offset(
                0,
                -floatOffset,
              ),
              child: Transform.scale(
                scale: pulse,
                child: Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    Container(
                      width:
                          logoSize + 38,
                      height:
                          logoSize + 38,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            RadialGradient(
                          colors: [
                            AppColors.primary
                                .withValues(
                              alpha: 0.24,
                            ),
                            AppColors.secondary
                                .withValues(
                              alpha: 0.10,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          isSmall
                              ? 28
                              : 34,
                        ),
                        gradient:
                            const LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color(0xFFE8EEFF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary
                                    .withValues(
                              alpha: 0.30,
                            ),
                            blurRadius: 38,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 25,
                            offset:
                                const Offset(
                              0,
                              14,
                            ),
                          ),
                        ],
                      ),
                      child:
                          Stack(
                        alignment:
                            Alignment.center,
                        children: [
                          Container(
                            width:
                                logoSize *
                                    0.70,
                            height:
                                logoSize *
                                    0.70,
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                22,
                              ),
                              gradient:
                                  const LinearGradient(
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                                colors: [
                                  AppColors
                                      .primary,
                                  AppColors
                                      .secondary,
                                ],
                              ),
                            ),
                          ),
                          Icon(
                            Icons
                                .business_center_rounded,
                            size:
                                logoSize *
                                    0.42,
                            color:
                                Colors.white,
                          ),
                          Positioned(
                            right:
                                logoSize *
                                    0.12,
                            bottom:
                                logoSize *
                                    0.12,
                            child:
                                Container(
                              width:
                                  isSmall
                                      ? 22
                                      : 25,
                              height:
                                  isSmall
                                      ? 22
                                      : 25,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color:
                                    AppColors
                                        .success,
                                border:
                                    Border.all(
                                  color:
                                      Colors.white,
                                  width:
                                      3,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons.check_rounded,
                                size:
                                    13,
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // TITLE
  // ===========================================================================

  Widget _buildTitle(
    ThemeData theme,
    bool isSmall,
  ) {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Text(
          'Business Manager',
          textAlign:
              TextAlign.center,
          style: theme
              .textTheme
              .headlineMedium
              ?.copyWith(
            color: Colors.white,
            fontSize:
                isSmall ? 28 : 34,
            fontWeight:
                FontWeight.w800,
            letterSpacing:
                -0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(
    ThemeData theme,
    bool isSmall,
  ) {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Text(
          'Manage. Track. Grow.',
          textAlign:
              TextAlign.center,
          style: theme
              .textTheme
              .bodyLarge
              ?.copyWith(
            color: Colors.white
                .withValues(
              alpha: 0.72,
            ),
            fontSize:
                isSmall ? 14 : 16,
            fontWeight:
                FontWeight.w500,
            letterSpacing:
                0.4,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PROGRESS
  // ===========================================================================

  Widget _buildProgressSection(
    ThemeData theme,
    bool isSmall,
  ) {
    return FadeTransition(
      opacity: _contentFade,
      child: SlideTransition(
        position: _contentSlide,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusText,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.86,
                      ),
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Text(
                  '${(_progress * 100).round()}%',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: Colors.white
                        .withValues(
                      alpha: 0.65,
                    ),
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            AnimatedBuilder(
              animation: _progressWidth,
              builder: (
                context,
                child,
              ) {
                return Container(
                  height:
                      isSmall ? 5 : 6,
                  width:
                      double.infinity,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: FractionallySizedBox(
                    alignment:
                        Alignment.centerLeft,
                    widthFactor:
                        _progress *
                            _progressWidth.value,
                    child:
                        Container(
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        gradient:
                            const LinearGradient(
                          colors: [
                            AppColors
                                .primaryLight,
                            AppColors
                                .primary,
                            AppColors
                                .secondary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors
                                    .primary
                                    .withValues(
                              alpha: 0.45,
                            ),
                            blurRadius:
                                10,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FEATURE ROW
  // ===========================================================================

  Widget _buildFeatureRow(
    ThemeData theme,
    bool isSmall,
  ) {
    final List<_SplashFeature> features = [
      const _SplashFeature(
        icon:
            Icons.inventory_2_outlined,
        label: 'Inventory',
      ),
      const _SplashFeature(
        icon:
            Icons.receipt_long_outlined,
        label: 'Sales',
      ),
      const _SplashFeature(
        icon:
            Icons.analytics_outlined,
        label: 'Reports',
      ),
    ];

    return FadeTransition(
      opacity: _contentFade,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: features
            .map(
              (feature) =>
                  Expanded(
                child:
                    _buildFeatureItem(
                  theme,
                  feature,
                  isSmall,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    _SplashFeature feature,
    bool isSmall,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      child: Column(
        children: [
          Container(
            width:
                isSmall ? 42 : 46,
            height:
                isSmall ? 42 : 46,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.07,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              border:
                  Border.all(
                color: Colors.white
                    .withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: Icon(
              feature.icon,
              size:
                  isSmall ? 20 : 22,
              color:
                  Colors.white
                      .withValues(
                alpha: 0.78,
              ),
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          Text(
            feature.label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: Colors.white
                  .withValues(
                alpha: 0.55,
              ),
              fontSize:
                  isSmall ? 11 : 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SPLASH FEATURE MODEL
// =============================================================================

class _SplashFeature {
  final IconData icon;
  final String label;

  const _SplashFeature({
    required this.icon,
    required this.label,
  });
}

// =============================================================================
// BACKGROUND PAINTER
// =============================================================================

class _SplashBackgroundPainter
    extends CustomPainter {
  final double rotation;

  const _SplashBackgroundPainter({
    required this.rotation,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Offset center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    final double radius =
        math.min(
              size.width,
              size.height,
            ) *
            0.42;

    final Paint ringPaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white
              .withValues(
            alpha: 0.035,
          );

    for (int i = 0; i < 4; i++) {
      final double ringRadius =
          radius *
              (0.55 +
                  (i * 0.16));

      canvas.drawCircle(
        center,
        ringRadius,
        ringPaint,
      );
    }

    final Paint dotPaint =
        Paint()
          ..style =
              PaintingStyle.fill;

    for (int i = 0; i < 12; i++) {
      final double angle =
          rotation +
              (i *
                  math.pi *
                  2 /
                  12);

      final double distance =
          radius *
              (0.72 +
                  ((i % 3) *
                      0.10));

      final Offset position =
          Offset(
        center.dx +
            math.cos(angle) *
                distance,
        center.dy +
            math.sin(angle) *
                distance,
      );

      dotPaint.color =
          Colors.white.withValues(
        alpha:
            i % 2 == 0
                ? 0.055
                : 0.03,
      );

      canvas.drawCircle(
        position,
        i % 3 == 0 ? 2.2 : 1.4,
        dotPaint,
      );
    }

    final Paint linePaint =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white
              .withValues(
            alpha: 0.025,
          );

    for (int i = 0; i < 6; i++) {
      final double angle =
          rotation +
              (i *
                  math.pi /
                  3);

      final Offset start =
          Offset(
        center.dx +
            math.cos(angle) *
                radius *
                0.40,
        center.dy +
            math.sin(angle) *
                radius *
                0.40,
      );

      final Offset end =
          Offset(
        center.dx +
            math.cos(angle) *
                radius *
                1.15,
        center.dy +
            math.sin(angle) *
                radius *
                1.15,
      );

      canvas.drawLine(
        start,
        end,
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _SplashBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.rotation !=
        rotation;
  }
}
