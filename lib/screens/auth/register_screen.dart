import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../business_setup/business_setup_screen.dart';
import '../../repositories/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
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

  // ===========================================================================
  // REGISTER
  // ===========================================================================

  Future<void> _register() async {
    if (_isLoading) {
      return;
    }

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final String email =
          _emailController.text.trim();

      final String password =
          _passwordController.text;

      final String businessName =
          _businessNameController.text.trim();

      final UserCredential credential =
          await _authRepository.register(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw Exception(
          'User account could not be created.',
        );
      }

      // Keep the entered business name available in the Firebase
      // authentication profile. The actual business document is created
      // later by BusinessSetupScreen.
      if (businessName.isNotEmpty) {
        await user.updateDisplayName(
          businessName,
        );
      }

      if (!mounted) {
        return;
      }

      // Registration is complete. BusinessSetupScreen is now responsible
      // for collecting and saving the business profile.
      //
      // pushAndRemoveUntil is intentional here so the user cannot press
      // Back and return to the registration form after creating an account.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const BusinessSetupScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _getFirebaseRegisterErrorMessage(
          error,
        ),
        isError: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _getRegisterErrorMessage(error),
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
  // FIREBASE ERROR HANDLING
  // ===========================================================================

  String _getFirebaseRegisterErrorMessage(
    FirebaseAuthException error,
  ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Is email se account already exist karta hai.';

      case 'invalid-email':
        return 'Please valid email address enter karo.';

      case 'weak-password':
        return 'Password thoda strong rakho.';

      case 'operation-not-allowed':
        return 'Email/password authentication Firebase mein enabled nahi hai.';

      case 'network-request-failed':
        return 'Internet connection check karo.';

      case 'too-many-requests':
        return 'Bahut zyada attempts ho gaye hain. Thodi der baad try karo.';

      case 'user-disabled':
        return 'Ye account disabled hai.';

      default:
        return error.message ??
            'Registration failed. Please try again.';
    }
  }

  String _getRegisterErrorMessage(
    Object error,
  ) {
    final String message =
        error.toString().toLowerCase();

    if (message.contains('network')) {
      return 'Internet connection check karo.';
    }

    if (message.contains('permission')) {
      return 'You do not have permission to create this account.';
    }

    if (message.contains('user account could not be created')) {
      return 'Account create nahi ho paya. Please try again.';
    }

    return 'Registration failed. Please try again.';
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
          backgroundColor:
              isError ? Colors.red : Colors.green,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
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
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(
                      height: 12,
                    ),

                    // ---------------------------------------------------------
                    // TITLE
                    // ---------------------------------------------------------

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

                    // ---------------------------------------------------------
                    // BUSINESS NAME
                    // ---------------------------------------------------------

                    TextFormField(
                      controller:
                          _businessNameController,
                      textInputAction:
                          TextInputAction.next,
                      enabled: !_isLoading,
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

                    // ---------------------------------------------------------
                    // EMAIL
                    // ---------------------------------------------------------

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      enabled: !_isLoading,
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
                      validator: (value) {
                        final String email =
                            value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Email is required';
                        }

                        final RegExp emailRegex =
                            RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailRegex
                            .hasMatch(email)) {
                          return 'Enter a valid email';
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
                          TextInputAction.next,
                      enabled: !_isLoading,
                      decoration:
                          InputDecoration(
                        labelText: 'Password',
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
                                      setState(() {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      });
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
                      validator: (value) {
                        final String password =
                            value ?? '';

                        if (password.isEmpty) {
                          return 'Password is required';
                        }

                        if (password.length <
                            6) {
                          return 'Minimum 6 characters required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ---------------------------------------------------------
                    // CONFIRM PASSWORD
                    // ---------------------------------------------------------

                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      enabled: !_isLoading,
                      onFieldSubmitted:
                          (_) => _register(),
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
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
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
                      validator: (value) {
                        final String confirmPassword =
                            value ?? '';

                        if (confirmPassword
                            .isEmpty) {
                          return 'Please confirm password';
                        }

                        if (confirmPassword !=
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

                    // ---------------------------------------------------------
                    // REGISTER BUTTON
                    // ---------------------------------------------------------

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

                    // ---------------------------------------------------------
                    // LOGIN
                    // ---------------------------------------------------------

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