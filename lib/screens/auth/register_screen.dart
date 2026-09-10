import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/auth_repository.dart';
import '../business_setup/business_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthRepository _authRepository = AuthRepository();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _businessNameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
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
    if (_isLoading) {
      return;
    }

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

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

      // Keep the business name available in the
      // Firebase user profile until BusinessSetup
      // saves the complete business document.
      await _authRepository.updateDisplayName(
        businessName,
      );

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
            behavior: SnackBarBehavior.floating,
            duration: Duration(
              milliseconds: 900,
            ),
          ),
        );

      await Future.delayed(
        const Duration(
          milliseconds: 400,
        ),
      );

      if (!mounted) {
        return;
      }

      // Registration only creates the Firebase
      // Authentication account.
      //
      // Complete business information is created
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

        case 'user-disabled':
          return 'Ye account disabled hai.';

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
      return 'Enter a valid email';
    }

    return null;
  }

  String? _validatePassword(
    String? value,
  ) {
    final String password =
        value ?? '';

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 6) {
      return 'Minimum 6 characters required';
    }

    return null;
  }

  String? _validateConfirmPassword(
    String? value,
  ) {
    final String confirmPassword =
        value ?? '';

    if (confirmPassword.isEmpty) {
      return 'Please confirm password';
    }

    if (confirmPassword !=
        _passwordController.text) {
      return 'Passwords do not match';
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
          'Create Account',
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
                    const SizedBox(
                      height: 12,
                    ),

                    Icon(
                      Icons
                          .person_add_alt_1_rounded,
                      size: 54,
                      color:
                          theme.colorScheme.primary,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Text(
                      'Create your account',
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
                      height: 8,
                    ),

                    Text(
                      'Start managing your business easily.',
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
                      height: 30,
                    ),

                    TextFormField(
                      controller:
                          _businessNameController,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Name *',
                        hintText:
                            'Enter business name',
                        prefixIcon: Icon(
                          Icons
                              .business_outlined,
                        ),
                      ),
                      validator: (value) {
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
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      autocorrect: false,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration:
                          const InputDecoration(
                        labelText: 'Email *',
                        hintText:
                            'Enter email address',
                        prefixIcon: Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                      validator:
                          _validateEmail,
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
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      decoration:
                          InputDecoration(
                        labelText:
                            'Password *',
                        hintText:
                            'Minimum 6 characters',
                        prefixIcon:
                            const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon:
                            IconButton(
                          tooltip:
                              _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
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
                          _validatePassword,
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
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _register();
                        }
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'Confirm Password *',
                        hintText:
                            'Enter password again',
                        prefixIcon:
                            const Icon(
                          Icons
                              .lock_reset_outlined,
                        ),
                        suffixIcon:
                            IconButton(
                          tooltip:
                              _obscureConfirmPassword
                                  ? 'Show password'
                                  : 'Hide password',
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
                          _validateConfirmPassword,
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
                                  strokeWidth: 2.5,
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
                          MainAxisAlignment.center,
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
                          child: const Text(
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
