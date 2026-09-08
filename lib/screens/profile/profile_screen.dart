import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final AuthRepository _authRepository =
      AuthRepository();

  bool _isLoggingOut = false;

  User? get _user =>
      _authRepository.currentUser;

  String get _userName {
    final String name =
        _user?.displayName?.trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    return 'Business Owner';
  }

  String get _email {
    return _user?.email ?? '';
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
          ),
          content: const Text(
            'Are you sure you want to logout from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authRepository.logout();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      _showMessage(
        e.message ??
            'Logout failed. Please try again.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      _showMessage(
        'Logout failed. Please try again.',
      );
    }
  }

  void _showMessage(
    String message,
  ) {
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

    final ColorScheme colors =
        theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 700,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  const SizedBox(
                    height: 8,
                  ),

                  // Profile Header
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration:
                                BoxDecoration(
                              color: AppColors
                                  .primary
                                  .withValues(
                                alpha: 0.10,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .business_center_rounded,
                              size: 42,
                              color: AppColors
                                  .primary,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          Text(
                            _userName,
                            textAlign:
                                TextAlign.center,
                            style: theme
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          if (_email
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              _email,
                              textAlign:
                                  TextAlign
                                      .center,
                              style: theme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // Account Information
                  _SectionCard(
                    title:
                        'Account Information',
                    icon: Icons
                        .account_circle_outlined,
                    children: [
                      _InfoTile(
                        icon: Icons
                            .email_outlined,
                        title: 'Email',
                        value: _email.isEmpty
                            ? 'Not available'
                            : _email,
                      ),
                      _InfoTile(
                        icon: Icons
                            .verified_user_outlined,
                        title:
                            'Account Status',
                        value: 'Active',
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // Business Information
                  _SectionCard(
                    title:
                        'Business Management',
                    icon: Icons
                        .business_outlined,
                    children: [
                      _ActionTile(
                        icon: Icons
                            .business_outlined,
                        title:
                            'Business Profile',
                        subtitle:
                            'Manage your business information',
                        onTap: () {
                          _showMessage(
                            'Business Profile settings will be available here.',
                          );
                        },
                      ),
                      _ActionTile(
                        icon: Icons
                            .settings_outlined,
                        title:
                            'Settings',
                        subtitle:
                            'App and business preferences',
                        onTap: () {
                          _showMessage(
                            'Settings will be available here.',
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // Logout
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isLoggingOut
                                  ? null
                                  : _logout,
                          icon:
                              _isLoggingOut
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .logout_rounded,
                                      color:
                                          AppColors
                                              .danger,
                                    ),
                          label: Text(
                            _isLoggingOut
                                ? 'Logging out...'
                                : 'Logout',
                            style:
                                const TextStyle(
                              color:
                                  AppColors
                                      .danger,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  Text(
                    'Business Management App',
                    textAlign:
                        TextAlign.center,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Secure business management',
                    textAlign:
                        TextAlign.center,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: AppColors.primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Text(
                  title,
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: theme
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          color: AppColors.primary
              .withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: const Icon(
          Icons.settings_outlined,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight:
              FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
      onTap: onTap,
    );
  }
}