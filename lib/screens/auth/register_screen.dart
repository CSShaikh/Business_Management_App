import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../business_setup/business_setup_screen.dart';
import '../../repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final AuthRepository _authRepository =
      AuthRepository();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _businessNameController =
      TextEditingController();

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    // Prevent double tap / multiple registration requests.
    if (_isLoading) {
      return;
    }

    // Validate form first.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String businessName =
        _businessNameController.text.trim();

    final String email =
        _emailController.text.trim();

    final String password =
        _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create Firebase Authentication account.
      final UserCredential credential =
          await _authRepository.register(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw Exception(
          'Account could not be created.',
        );
      }

      // Store business name as Firebase display name.
      await user.updateDisplayName(
        businessName,
      );

      // Refresh Firebase user data.
      await user.reload();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully.',
            ),
            behavior:
                SnackBarBehavior.floating,
            duration: Duration(
              milliseconds: 900,
            ),
          ),
        );

      // Give Firebase a moment to finish
      // updating the user session.
      await Future.delayed(
        const Duration(
          milliseconds: 400,
        ),
      );

      if (!mounted) {
        return;
      }

      // Registration is complete.
      // Business details will be saved only
      // from BusinessSetupScreen.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const BusinessSetupScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      _showRegisterError(
        _getRegisterErrorMessage(e),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showRegisterError(
        _getRegisterErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRegisterErrorMessage(
    Object error,
  ) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Is email se account already exist karta hai.';

        case 'invalid-email':
          return 'Please valid email address enter karo.';

        case 'weak-password':
          return 'Password thoda strong rakho.';

        case 'network-request-failed':
          return 'Internet connection check karo.';

        case 'operation-not-allowed':
          return 'Email/password registration Firebase mein enabled nahi hai.';

        case 'too-many-requests':
          return 'Bahut zyada attempts ho gaye. Thodi der baad try karo.';

        default:
          return error.message ??
              'Registration failed. Please try again.';
      }
    }

    final String message =
        error.toString().toLowerCase();

    if (message.contains(
      'email-already-in-use',
    )) {
      return 'Is email se account already exist karta hai.';
    }

    if (message.contains(
      'network-request-failed',
    )) {
      return 'Internet connection check karo.';
    }

    return 'Registration failed. Please try again.';
  }

  void _showRegisterError(
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
          behavior:
              SnackBarBehavior.floating,
        ),
      );
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
          'Create Account',
        ),
      ),
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
                      height: 12,
                    ),

                    Text(
                      'Create your account',
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      'Start managing your business easily.',
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
                      height: 30,
                    ),

                    TextFormField(
                      controller:
                          _businessNameController,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Name',
                        hintText:
                            'Enter business name',
                        prefixIcon: Icon(
                          Icons
                              .business_outlined,
                        ),
                      ),
                      validator:
                          (value) {
                        if ((value ?? '')
                            .trim()
                            .isEmpty) {
                          return 'Business name is required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(
                        labelText: 'Email',
                        hintText:
                            'Enter email address',
                        prefixIcon: Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                      validator:
                          (value) {
                        final String
                            email =
                            value?.trim() ??
                                '';

                        if (email.isEmpty) {
                          return 'Email is required';
                        }

                        if (!email.contains(
                              '@',
                            ) ||
                            !email.contains(
                              '.',
                            )) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _passwordController,
                      obscureText:
                          _obscurePassword,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          InputDecoration(
                        labelText:
                            'Password',
                        hintText:
                            'Minimum 6 characters',
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
                          (value) {
                        if ((value ?? '')
                            .isEmpty) {
                          return 'Password is required';
                        }

                        if ((value ?? '')
                                .length <
                            6) {
                          return 'Minimum 6 characters required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      enabled:
                          !_isLoading,
                      onFieldSubmitted:
                          (_) {
                        if (!_isLoading) {
                          _register();
                        }
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'Confirm Password',
                        hintText:
                            'Enter password again',
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_reset_outlined,
                        ),
                        suffixIcon:
                            IconButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                      setState(
                                        () {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        },
                                      );
                                    },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator:
                          (value) {
                        if ((value ?? '')
                            .isEmpty) {
                          return 'Please confirm password';
                        }

                        if (value !=
                            _passwordController
                                .text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _register,
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
                                'Create Account',
                              ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        const Text(
                          'Already have an account? ',
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
                          child:
                              const Text(
                            'Login',
                          ),
                        ),
                      ],
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