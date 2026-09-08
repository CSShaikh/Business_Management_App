import 'dart:async';

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
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final BusinessRepository _businessRepository =
      BusinessRepository();

  late AnimationController _animationController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String _statusText =
      'Starting your business workspace...';

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1000,
      ),
    );

    _scaleAnimation =
        CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation =
        CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    _startApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startApp() async {
    // Small delay so the splash screen is visible.
    await Future.delayed(
      const Duration(
        milliseconds: 1200,
      ),
    );

    if (!mounted) {
      return;
    }

    try {
      final User? user =
          _auth.currentUser;

      if (user == null) {
        _updateStatus(
          'Opening login...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );

        if (!mounted) {
          return;
        }

        _openLogin();
        return;
      }

      _updateStatus(
        'Checking your business profile...',
      );

      await user.reload();

      final User? refreshedUser =
          _auth.currentUser;

      if (refreshedUser == null) {
        _openLogin();
        return;
      }

      final business =
          await _businessRepository
              .getBusinessForOwner(
        refreshedUser.uid,
      );

      if (!mounted) {
        return;
      }

      if (business == null) {
        _updateStatus(
          'Business setup required...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );

        if (!mounted) {
          return;
        }

        _openBusinessSetup();
      } else {
        _updateStatus(
          'Loading your dashboard...',
        );

        await Future.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );

        if (!mounted) {
          return;
        }

        _openDashboard();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      if (e.code == 'user-disabled' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-user-token') {
        await _auth.signOut();
      }

      _updateStatus(
        'Opening login...',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 300,
        ),
      );

      if (!mounted) {
        return;
      }

      _openLogin();
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      // If Firestore is temporarily unavailable,
      // don't create a wrong business profile.
      _showErrorAndContinue(
        _getFirebaseErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorAndContinue(
        'Something went wrong. Please try again.',
      );
    }
  }

  void _updateStatus(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusText = text;
    });
  }

  String _getFirebaseErrorMessage(
    FirebaseException error,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return 'Business data permission denied.';

      case 'unavailable':
        return 'Internet or Firebase connection problem.';

      case 'failed-precondition':
        return 'Firebase configuration problem.';

      case 'unauthenticated':
        return 'Your session has expired.';

      default:
        return error.message ??
            'Could not load business data.';
    }
  }

  Future<void> _showErrorAndContinue(
    String message,
  ) async {
    _updateStatus(
      'Unable to load business profile...',
    );

    await Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          duration: const Duration(
            seconds: 2,
          ),
        ),
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

  void _openLogin() {
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final Size screenSize =
        MediaQuery.sizeOf(context);

    final bool isSmallScreen =
        screenSize.width < 600;

    final double logoSize =
        isSmallScreen ? 92 : 110;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity:
                        _fadeAnimation,
                    child: ScaleTransition(
                      scale:
                          _scaleAnimation,
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            isSmallScreen
                                ? 26
                                : 30,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withValues(
                                alpha: 0.18,
                              ),
                              blurRadius: 30,
                              offset:
                                  const Offset(
                                0,
                                12,
                              ),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons
                              .business_center_rounded,
                          size:
                              isSmallScreen
                                  ? 50
                                  : 60,
                          color:
                              AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  FadeTransition(
                    opacity:
                        _fadeAnimation,
                    child: Text(
                      'Business Manager',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing:
                            0.2,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  FadeTransition(
                    opacity:
                        _fadeAnimation,
                    child: Text(
                      'Manage. Track. Grow.',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: 0.85,
                        ),
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 42,
                  ),

                  SizedBox(
                    width:
                        isSmallScreen
                            ? 190
                            : 220,
                    child:
                        ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      child:
                          const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor:
                            Color(
                          0x40FFFFFF,
                        ),
                        valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  AnimatedSwitcher(
                    duration:
                        const Duration(
                      milliseconds: 250,
                    ),
                    child: Text(
                      _statusText,
                      key: ValueKey(
                        _statusText,
                      ),
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha: 0.80,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}