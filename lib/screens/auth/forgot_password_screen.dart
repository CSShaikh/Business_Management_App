import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final AuthRepository _authRepository = AuthRepository();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_isLoading) {
      return;
    }

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String email =
        _emailController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists for this email, a password reset link has been sent.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(
              seconds: 3,
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

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showError(
        _getFirebaseErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'Could not send reset email. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFirebaseErrorMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'network-request-failed':
        return 'Internet connection check karo.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'operation-not-allowed':
        return 'Password reset is not enabled in Firebase.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'user-not-found':
        // Keep account existence private.
        return 'If an account exists for this email, a password reset link has been sent.';

      default:
        return 'Could not send reset email. Please try again.';
    }
  }

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String? _validateEmail(
    String? value,
  ) {
    final String email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required';
    }

    final RegExp emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme
                            .colorScheme
                            .primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 36,
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    Text(
                      'Reset your password',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      'Enter your registered email address. '
                      'We will send you a password reset link.',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      enabled:
                          !_isLoading,
                      autocorrect: false,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _sendResetEmail();
                        }
                      },
                      decoration:
                          const InputDecoration(
                        labelText: 'Email',
                        hintText:
                            'Enter your email',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                        ),
                      ),
                      validator:
                          _validateEmail,
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _sendResetEmail,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'Send Reset Link',
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                  );
                                },
                      child: const Text(
                        'Back to Login',
                      ),
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
