import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../splash/splash_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final AuthRepository _authRepository =
      AuthRepository();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // LOGIN
  // ===========================================================================

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      return;
    }

    final String email =
        _emailController.text.trim();

    final String password =
        _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.login(
        email: email,
        password: password,
      );

      final User? user =
          _authRepository.currentUser;

      if (user == null) {
        throw Exception(
          'User session not found.',
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Login successful.',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) {
        return;
      }

      // -----------------------------------------------------------------------
      // AUTHENTICATION ROUTING
      //
      // SplashScreen is the single startup/router authority.
      //
      // Login success
      //      ↓
      // SplashScreen
      //      ↓
      // Check authenticated user
      //      ↓
      // Check business profile
      //      ↓
      // Existing business → Dashboard
      // New user          → Business Setup
      //
      // Keeping this decision inside SplashScreen prevents an existing
      // business owner from being sent to Business Setup after every login.
      // -----------------------------------------------------------------------

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const SplashScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _getAuthErrorMessage(
          error,
        ),
        isError: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _getLoginErrorMessage(
          error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // AUTH ERROR HANDLING
  // ===========================================================================

  String _getAuthErrorMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-credential':
        return 'Email ya password incorrect hai.';

      case 'invalid-email':
        return 'Please valid email address enter karo.';

      case 'user-not-found':
        return 'Is email se account nahi mila.';

      case 'wrong-password':
        return 'Password incorrect hai.';

      case 'user-disabled':
        return 'Ye account disabled hai.';

      case 'too-many-requests':
        return 'Bahut zyada login attempts. Thodi der baad try karo.';

      case 'network-request-failed':
        return 'Internet connection check karo.';

      case 'operation-not-allowed':
        return 'Email/password authentication Firebase mein enabled nahi hai.';

      default:
        return error.message ??
            'Login failed. Please try again.';
    }
  }

  String _getLoginErrorMessage(
    Object error,
  ) {
    final String message =
        error.toString().toLowerCase();

    if (message.contains(
      'network',
    )) {
      return 'Internet connection check karo.';
    }

    if (message.contains(
      'session',
    )) {
      return 'User session create nahi ho paya. Please login again.';
    }

    return 'Something went wrong. Please try again.';
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 430,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    const SizedBox(
                      height: 20,
                    ),

                    // ---------------------------------------------------------
                    // APP ICON
                    // ---------------------------------------------------------

                    Container(
                      width: 78,
                      height: 78,
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .primary
                            .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          22,
                        ),
                      ),
                      child: const Icon(
                        Icons
                            .business_center_rounded,
                        size: 42,
                        color:
                            AppColors.primary,
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ---------------------------------------------------------
                    // TITLE
                    // ---------------------------------------------------------

                    Text(
                      'Welcome Back',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      'Login to manage your business',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 34,
                    ),

                    // ---------------------------------------------------------
                    // EMAIL
                    // ---------------------------------------------------------

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      textInputAction:
                          TextInputAction
                              .next,
                      enabled:
                          !_isLoading,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email',
                        hintText:
                            'Enter your email',
                        prefixIcon:
                            Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                      validator:
                          (String? value) {
                        final String email =
                            (value ?? '')
                                .trim();

                        if (email.isEmpty) {
                          return 'Email is required';
                        }

                        final bool isValid =
                            RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(
                          email,
                        );

                        if (!isValid) {
                          return 'Please enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ---------------------------------------------------------
                    // PASSWORD
                    // ---------------------------------------------------------

                    TextFormField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      textInputAction:
                          TextInputAction.done,
                      enabled:
                          !_isLoading,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      onFieldSubmitted:
                          (_) {
                        if (!_isLoading) {
                          _login();
                        }
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'Password',
                        hintText:
                            'Enter your password',
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_outline,
                        ),
                        suffixIcon:
                            IconButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      setState(
                                        () {
                                          _obscurePassword =
                                              !_obscurePassword;
                                        },
                                      );
                                    },
                          icon: Icon(
                            _obscurePassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator:
                          (String? value) {
                        if ((value ?? '')
                            .isEmpty) {
                          return 'Password is required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ---------------------------------------------------------
                    // REMEMBER ME + FORGOT PASSWORD
                    // ---------------------------------------------------------

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                            value:
                                _rememberMe,
                            onChanged:
                                _isLoading
                                    ? null
                                    : (
                                        bool?
                                            value,
                                      ) {
                                        setState(
                                          () {
                                            _rememberMe =
                                                value ??
                                                    false;
                                          },
                                        );
                                      },
                            contentPadding:
                                EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity
                                    .leading,
                            title:
                                const Text(
                              'Remember me',
                            ),
                            dense: true,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      Navigator
                                          .push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                          child:
                              const Text(
                            'Forgot Password?',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ---------------------------------------------------------
                    // LOGIN BUTTON
                    // ---------------------------------------------------------

                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'Login',
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ---------------------------------------------------------
                    // REGISTER
                    // ---------------------------------------------------------

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme
                              .textTheme
                              .bodyMedium,
                        ),
                        TextButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      Navigator
                                          .push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const RegisterScreen(),
                                        ),
                                      );
                                    },
                          child:
                              const Text(
                                'Create Account',
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ---------------------------------------------------------
                    // SECURITY TEXT
                    // ---------------------------------------------------------

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        Icon(
                          Icons
                              .lock_rounded,
                          size: 14,
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          'Secure business management',
                          textAlign:
                              TextAlign.center,
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}